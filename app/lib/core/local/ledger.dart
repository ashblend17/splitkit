/// The synced data on this device, and every answer the screens need computed from it.
///
/// Each view returns the same JSON the API would (same fields, same order, same rules), so the
/// generated models parse it and screens don't know where it came from. The Python function each
/// view mirrors is named in its doc comment; test/core/local_parity_test.dart checks them against
/// real API answers captured from the seed. Pure Dart: no Flutter, no I/O.
///
/// A Ledger never changes (the store builds a new one on every change), so what views share is
/// worked out once, lazily: the personal entries indexed (personal_index.dart), each group's
/// flows and totals, the feed's order and the category-suggestion lookups. The finance engine
/// (core/finance) and what it's asked with are handed on to the next Ledger while the parts of
/// the data they come from haven't changed ([Ledger.finance]).
library;

import 'package:intl/intl.dart';

import '../categorise/category_rules.dart';
import '../clock.dart';
import '../finance/finance.dart'
    show
        DayRange,
        DayRangeContains,
        FinAccount,
        FinContribution,
        FinGoal,
        FinHolding,
        FinPlan,
        FinRule,
        FinanceEngine,
        monthRange;
import 'balance_engine.dart';
import 'personal_index.dart';
import 'revisions.dart';

export 'revisions.dart';

/// One synced entity, as stored: the full state from a snapshot or a change.
class LocalEntity {
  const LocalEntity(this.stream, this.entity, this.entityId, this.version, this.data);

  final String stream;
  final String entity;
  final String entityId;
  final int? version;
  final Map<String, dynamic> data;

  String get key => keyOf(stream, entity, entityId);

  static String keyOf(String stream, String entity, String id) => '$stream|$entity|$id';

  Map<String, dynamic> toJson() => {
    'stream': stream,
    'entity': entity,
    'entity_id': entityId,
    'version': version,
    'data': data,
  };

  static LocalEntity fromJson(Map<String, dynamic> j) => LocalEntity(
    j['stream'] as String,
    j['entity'] as String,
    j['entity_id'] as String,
    j['version'] as int?,
    (j['data'] as Map).cast<String, dynamic>(),
  );
}

/// Asked for something this device doesn't have (or the viewer may not see). Screens show it
/// like the API's 404.
class LocalNotFound implements Exception {
  const LocalNotFound(this.what);
  final String what;

  @override
  String toString() => '$what not found';
}

/// Desktop activity-table filters (balances/feed.py FeedFilters).
class FeedFilters {
  const FeedFilters({this.category, this.start, this.end, this.openOnly = false, this.search});

  final String? category;
  final String? start;
  final String? end;

  /// Only expenses where you and the other side are not square yet.
  final bool openOnly;
  final String? search;

  bool get payments => category == null && !openOnly;
}

typedef Json = Map<String, dynamic>;

/// What a personal entry became in Split (Ledger.personalLink).
typedef PersonalLink = ({bool payment, String id, String? group, String? person, bool live});

/// The "Tricount" user (SYSTEM_USER_ID in api/app/modules/tricount_sync/reconcile.py).
const tricountUserId = '1a352678-7c38-5085-8131-bbcad6d0ae9d';

class Ledger {
  Ledger(Iterable<LocalEntity> entities, {DateTime? today, this.revisions = LedgerRevisions.none})
    : today = today ?? appClock.now() {
    Json? me;
    for (final e in entities) {
      final d = e.data;
      switch (e.entity) {
        case 'profile':
          me = d;
        case 'group':
          _groups[e.entityId] = d;
        case 'member':
          (_members[d['group_id'] as String] ??= []).add(d);
          final user = (d['user'] as Map).cast<String, dynamic>();
          _people[user['id'] as String] = user;
        case 'expense':
          _expenses[e.entityId] = d;
        case 'settlement':
          _settlements[e.entityId] = d;
        case 'personal_transaction':
          _personal.add(d);
        case 'personal_account':
          _accounts[e.entityId] = d;
        case 'personal_goal':
          _goals[e.entityId] = d;
        case 'personal_goal_contribution':
          _contributions[e.entityId] = d;
        case 'category':
          _categories[e.entityId] = d;
        case 'layout':
          _layouts[e.entityId] = d;
        case 'category_rule':
          _rules.add(d);
        case 'personal_holding':
          _holdings[e.entityId] = d;
        case 'personal_allocation_rule':
          _allocationRules[e.entityId] = d;
        case 'personal_allocation_plan':
          _plans[e.entityId] = d;
      }
    }
    profile = me;
    if (me != null) {
      _people[me['id'] as String] = {
        'id': me['id'],
        'name': me['name'],
        'avatar_url': me['avatar_url'],
        'is_placeholder': me['email'] == null,
      };
    }
  }

  /// "Today" for month labels (the API uses its own clock).
  final DateTime today;

  /// How many changes each part of the data had had in the store when this was built: a view
  /// that reads only some parts is worked out again only when one of those changes.
  final LedgerRevisions revisions;

  /// The viewer (users/schemas.py UserOut). Null until the user stream has synced. Set once: what
  /// the views work out for you is kept.
  late final Json? profile;

  final _groups = <String, Json>{};
  final _members = <String, List<Json>>{};
  final _people = <String, Json>{};
  final _expenses = <String, Json>{};
  final _settlements = <String, Json>{};
  final _personal = <Json>[];
  final _accounts = <String, Json>{};
  final _goals = <String, Json>{};
  final _contributions = <String, Json>{};
  final _categories = <String, Json>{};
  final _layouts = <String, Json>{};
  final _rules = <Json>[];
  final _holdings = <String, Json>{};

  /// Allocation rules (personal_allocation_rule); [_rules] are the learned category rules.
  final _allocationRules = <String, Json>{};
  final _plans = <String, Json>{};

  String get me => profile?['id'] as String? ?? (throw const LocalNotFound('Profile'));

  bool get isEmpty => profile == null;

  Json userOut() => profile ?? (throw const LocalNotFound('Profile'));

  // ---- people and groups ----

  Json _brief(String userId) {
    final p = _people[userId];
    if (p == null) {
      // Changes synced from Tricount are recorded as this user (tricount_sync/reconcile.py).
      if (userId == tricountUserId) return {'id': userId, 'name': 'Tricount', 'avatar_url': null, 'is_placeholder': true};
      return {'id': userId, 'name': 'Someone', 'avatar_url': null, 'is_placeholder': false};
    }
    return {'id': p['id'], 'name': p['name'], 'avatar_url': p['avatar_url'], 'is_placeholder': p['is_placeholder'] ?? false};
  }

  String _name(String userId) => _people[userId]?['name'] as String? ?? '';

  /// groups/repository.py active_members: current members by join time, then name. Shared:
  /// callers only read it.
  List<Json> _activeMembers(String groupId) => _activeMembersOf[groupId] ??= () {
    final rows = [
      for (final m in _members[groupId] ?? const <Json>[])
        if (m['left_at'] == null) (m, isoMicros(m['joined_at'])),
    ];
    rows.sort((a, b) {
      final t = a.$2.compareTo(b.$2);
      return t != 0 ? t : _name(a.$1['user_id']).compareTo(_name(b.$1['user_id']));
    });
    return [for (final (m, _) in rows) m];
  }();

  final _activeMembersOf = <String, List<Json>>{};

  Set<String> _activeIds(String groupId) => {for (final m in _activeMembers(groupId)) m['user_id'] as String};

  bool _isMember(String groupId, String userId) =>
      (_members[groupId] ?? const []).any((m) => m['user_id'] == userId && m['left_at'] == null);

  /// groups/repository.py groups_for_user: newest first.
  List<Json> _groupsFor(String userId) {
    final out = [
      for (final g in _groups.values)
        if (_isMember(g['id'], userId)) (g, isoMicros(g['created_at'])),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (g, _) in out) g];
  }

  /// Your groups, newest first. Shared: callers only read it.
  late final List<Json> _myGroups = _groupsFor(me);

  Json _requireGroup(String groupId) {
    final g = _groups[groupId];
    if (g == null || !_isMember(groupId, me)) throw const LocalNotFound('Group');
    return g;
  }

  /// balances/repository.py flows_by_group: live expense splits and settlements, each group's
  /// expenses then its payments in the order they're stored. Shared: callers only read it.
  List<Flow> _flows(String groupId) => _byGroup.flows[groupId] ?? const [];

  /// Each group's flows and what its live expenses add up to, in one pass over everything.
  late final ({Map<String, List<Flow>> flows, Map<String, int> spent}) _byGroup = () {
    final flows = <String, List<Flow>>{};
    final spent = <String, int>{};
    for (final e in _expenses.values) {
      if (e['deleted_at'] != null) continue;
      final id = e['group_id'] as String;
      (flows[id] ??= []).addAll(_flowsOf[e] ??= expenseFlows(
        e['payer_id'],
        [for (final s in e['splits'] as List) (s['user_id'] as String, s['share_minor'] as int)],
      ));
      spent[id] = (spent[id] ?? 0) + (e['amount_minor'] as int);
    }
    for (final s in _settlements.values) {
      if (s['deleted_at'] != null) continue;
      (flows[s['group_id'] as String] ??= []).add(settlementFlow(s['from_user'], s['to_user'], s['amount_minor']));
    }
    return (flows: flows, spent: spent);
  }();

  /// Each expense's flows, worked out once per synced map (reused by the next Ledger, as
  /// PersonalRow is).
  static final _flowsOf = Expando<List<Flow>>('expense flows');

  /// positions(_flows(groupId)), worked out once per group. Shared: callers only read it.
  Map<String, int> _positions(String groupId) => _positionsOf[groupId] ??= positions(_flows(groupId));

  final _positionsOf = <String, Map<String, int>>{};

  /// groups/service.py _to_out.
  Json _groupOut(Json g) {
    final id = g['id'] as String;
    final spent = _byGroup.spent[id] ?? 0;
    return {
      'id': id,
      'name': g['name'],
      'icon': g['icon'],
      'currency': g['currency'],
      'created_at': g['created_at'],
      'archived_at': g['archived_at'],
      'members': [
        for (final m in _activeMembers(id))
          {
            'user': _brief(m['user_id']),
            'role': m['role'],
            'joined_at': m['joined_at'],
            'placeholder_name': m['placeholder_name'],
            'invite_email': m['invite_email'],
          },
      ],
      'total_spent_minor': spent,
      'my_net_minor': _positions(id)[me] ?? 0,
      'last_activity_at': g['last_activity_at'],
      'version': g['version'],
    };
  }

  /// GET /groups
  List<Json> groups({bool archived = false}) => [
    for (final g in _myGroups)
      if ((g['archived_at'] != null) == archived) _groupOut(g),
  ];

  /// GET /groups/{id}
  Json group(String groupId) => _groupOut(_requireGroup(groupId));

  // ---- balances (balances/service.py) ----

  static List<Object> _order(int net, String name) => [net < 0 ? 0 : net > 0 ? 1 : 2, -net.abs(), name];

  static int _compareOrder(List<Object> a, List<Object> b) {
    for (var i = 0; i < a.length; i++) {
      final c = (a[i] as Comparable).compareTo(b[i]);
      if (c != 0) return c;
    }
    return 0;
  }

  static (int, int) _splitTotals(Iterable<int> nets) {
    var owe = 0, owed = 0;
    for (final n in nets) {
      if (n < 0) owe -= n;
      if (n > 0) owed += n;
    }
    return (owe, owed);
  }

  List<Json> _sortedBalances(Iterable<Json> rows) =>
      rows.toList()..sort((a, b) => _compareOrder(
        _order(a['net_minor'], (a['user'] as Map)['name']),
        _order(b['net_minor'], (b['user'] as Map)['name']),
      ));

  /// GET /groups/{id}/balances
  Json groupBalances(String groupId) {
    final group = _requireGroup(groupId);
    final flows = _flows(groupId);
    final pair = pairwise(me, flows);
    final pos = _positions(groupId);
    final active = _activeIds(groupId);
    final peopleIds = {...active, for (final e in pair.entries) if (e.value != 0) e.key}..remove(me);
    final memberIds = {...active, for (final e in pos.entries) if (e.value != 0) e.key};
    final (owe, owed) = _splitTotals([for (final p in peopleIds) pair[p] ?? 0]);
    return {
      'group_id': groupId,
      'currency': group['currency'],
      'net_minor': pos[me] ?? 0,
      'you_owe_minor': owe,
      'you_are_owed_minor': owed,
      'people': _sortedBalances([for (final p in peopleIds) {'user': _brief(p), 'net_minor': pair[p] ?? 0}]),
      'members': _sortedBalances([for (final p in memberIds) {'user': _brief(p), 'net_minor': pos[p] ?? 0}]),
      'suggested': [
        for (final f in simplify({for (final e in pos.entries) if (e.value != 0) e.key: e.value}))
          {'from_user': _brief(f.debtor), 'to_user': _brief(f.creditor), 'amount_minor': f.amount},
      ],
    };
  }

  /// GET /balances: each group's fewest payments that involve you, added up per friend. Groups
  /// you have left are not on this device; leaving needs a zero balance, so they add nothing.
  Json overallBalances() {
    final friendNets = <(String, String), int>{};
    final groupNets = <Json>[];
    for (final g in _myGroups) {
      final id = g['id'] as String;
      final currency = g['currency'] as String;
      final flows = _flows(id);
      for (final e in planned(me, flows).entries) {
        friendNets[(e.key, currency)] = (friendNets[(e.key, currency)] ?? 0) + e.value;
      }
      for (final m in _activeMembers(id)) {
        if (m['user_id'] != me) friendNets.putIfAbsent((m['user_id'], currency), () => 0);
      }
      groupNets.add({'group_id': id, 'name': g['name'], 'currency': currency, 'net_minor': _positions(id)[me] ?? 0});
    }
    final byCurrency = <String, List<int>>{};
    for (final e in friendNets.entries) {
      (byCurrency[e.key.$2] ??= []).add(e.value);
    }
    final currencies = byCurrency.keys.toList()..sort();
    return {
      'totals': [
        for (final c in currencies)
          () {
            final nets = byCurrency[c]!;
            final (owe, owed) = _splitTotals(nets);
            return {'currency': c, 'net_minor': nets.fold(0, (a, b) => a + b), 'you_owe_minor': owe, 'you_are_owed_minor': owed};
          }(),
      ],
      'friends': [
        for (final e in friendNets.entries) {'user': _brief(e.key.$1), 'currency': e.key.$2, 'net_minor': e.value},
      ]..sort((a, b) => _compareOrder(
          _order(a['net_minor'] as int, (a['user'] as Map)['name']),
          _order(b['net_minor'] as int, (b['user'] as Map)['name']),
        )),
      'groups': groupNets,
    };
  }

  // ---- categories (categories/repository.py) ----

  List<Json> _visibleCategories(String? scope) {
    final rows = [
      for (final c in _categories.values)
        if ((c['owner_id'] == null || c['owner_id'] == me) && (scope == null || c['scope'] == scope || c['scope'] == 'all')) c,
    ];
    rows.sort((a, b) {
      final s = (a['sort'] as int).compareTo(b['sort'] as int);
      return s != 0 ? s : (a['label'] as String).compareTo(b['label'] as String);
    });
    return rows;
  }

  static Json _categoryOut(Json c) => {
    'id': c['id'],
    'key': c['key'],
    'label': c['label'],
    'icon': c['icon'],
    'scope': c['scope'],
    'owner_id': c['owner_id'],
  };

  /// GET /categories?scope=
  List<Json> categories({String? scope}) => [for (final c in _visibleCategories(scope)) _categoryOut(c)];

  // ---- feed (balances/feed.py) ----

  /// GET /feed
  List<Json> feed({String? groupId, bool deleted = false, FeedFilters filters = const FeedFilters(), int limit = 30, int offset = 0}) {
    final f = filters;
    final groupIds = groupId != null ? {_requireGroup(groupId)['id'] as String} : {for (final g in _myGroups) g['id'] as String};
    if (groupIds.isEmpty) return [];
    final search = f.search;
    final needle = search?.toLowerCase();
    bool like(Object? text) => text != null && (text as String).toLowerCase().contains(needle!);
    bool named(String userId) => search != null && like(_name(userId));

    // Walk everything newest first and keep what passes the filters, up to the end of the page
    // (all of it if offset or limit is negative, which the slicing below then rejects as before).
    final want = offset >= 0 && limit >= 0 ? offset + limit : null;
    final hits = <({_FeedRow row, int myShare, int position})>[];
    for (final r in _feedRows) {
      if (want != null && hits.length >= want) break;
      if (!groupIds.contains(r.groupId) ||
          r.deleted != deleted ||
          (f.start != null && r.date.compareTo(f.start!) < 0) ||
          (f.end != null && r.date.compareTo(f.end!) > 0)) {
        continue;
      }
      final x = r.raw;
      if (r.expense) {
        if (f.category != null && (x['category'] as Map?)?['key'] != f.category) continue;
        if (search != null && !like(x['description']) && !named(x['payer_id'])) continue;
        final splits = (x['splits'] as List).cast<Map>();
        final myShare = splits.where((s) => s['user_id'] == me).map((s) => s['share_minor'] as int).firstOrNull ?? 0;
        final position = _positions(r.groupId)[me] ?? 0;
        if (f.openOnly && !_open(x['payer_id'] as String, splits, myShare, position)) continue;
        hits.add((row: r, myShare: myShare, position: position));
      } else {
        if (!f.payments) continue;
        if (search != null && !named(x['from_user']) && !named(x['to_user'])) continue;
        hits.add((row: r, myShare: 0, position: 0));
      }
    }
    final end = offset + limit < hits.length ? offset + limit : hits.length;
    if (offset >= hits.length) return [];
    return [
      for (final h in hits.sublist(offset, end))
        h.row.expense ? _feedExpense(h.row.raw, h.myShare, h.position) : _feedSettlement(h.row.raw),
    ];
  }

  /// Every expense and payment on the device, deleted ones too, in the feed's order: newest
  /// first, then newest made, and the id breaks ties (imported rows share a timestamp).
  late final List<_FeedRow> _feedRows = [
    for (final e in _expenses.values) _FeedRow(e, expense: true),
    for (final s in _settlements.values) _FeedRow(s, expense: false),
  ]..sort(_FeedRow.newestFirst);

  Json _feedExpense(Json e, int myShare, int position) {
    final splits = (e['splits'] as List).cast<Map>();
    final payer = e['payer_id'] as String;
    final category = e['category'] as Map?;
    return {
      'kind': 'expense',
      'id': e['id'],
      'group_id': e['group_id'],
      'group_name': _groups[e['group_id']]?['name'],
      'title': e['description'],
      'date': e['date'],
      'created_at': e['created_at'],
      'amount_minor': e['amount_minor'],
      'currency': e['currency'],
      'category': category == null ? null : _categoryOut(category.cast()),
      'payer': _brief(payer),
      'to_user': null,
      'method': e['split_method'],
      'participant_count': splits.where((s) => s['share_minor'] != 0).length,
      'my_share_minor': myShare,
      'my_net_minor': (payer == me ? e['amount_minor'] as int : 0) - myShare,
      'settled': payer != me && myShare > 0 && position >= 0,
      'by_admin': e['acting_admin_id'] != null,
      'deleted_at': e['deleted_at'],
    };
  }

  Json _feedSettlement(Json s) {
    final amount = s['amount_minor'] as int;
    final effect = s['from_user'] == me ? amount : s['to_user'] == me ? -amount : 0;
    return {
      'kind': 'settlement',
      'id': s['id'],
      'group_id': s['group_id'],
      'group_name': _groups[s['group_id']]?['name'],
      'title': null,
      'date': s['date'],
      'created_at': s['created_at'],
      'amount_minor': amount,
      'currency': s['currency'],
      'category': null,
      'payer': _brief(s['from_user']),
      'to_user': _brief(s['to_user']),
      'method': s['method'],
      'participant_count': 2,
      'my_share_minor': 0,
      'my_net_minor': effect,
      'settled': false,
      'by_admin': s['acting_admin_id'] != null,
      'deleted_at': s['deleted_at'],
    };
  }

  /// As the group's fewest payments see it ([position] is yours in the group): you have a share
  /// and still pay someone in the group, or you paid for others and someone still pays you.
  bool _open(String payer, List<Map> splits, int myShare, int position) {
    if (payer == me) return position > 0 && splits.any((s) => s['user_id'] != me && s['share_minor'] != 0);
    return myShare > 0 && position < 0;
  }

  // ---- expenses (expenses/service.py to_out) ----

  /// GET /expenses/{id}
  Json expense(String expenseId) {
    final e = _expenses[expenseId];
    if (e == null || !_isMember(e['group_id'], me)) throw const LocalNotFound('Expense');
    final payer = e['payer_id'] as String;
    final splits = (e['splits'] as List).cast<Map>();
    final myShare = splits.where((s) => s['user_id'] == me).map((s) => s['share_minor'] as int).firstOrNull ?? 0;
    final pos = _positions(e['group_id']);
    final c = (e['category'] as Map?)?.cast<String, dynamic>();
    // get_visible: built-in or yours, and usable in groups.
    final visible = c != null && (c['owner_id'] == null || c['owner_id'] == me) && (c['scope'] == 'group' || c['scope'] == 'all');
    return {
      'id': e['id'],
      'group_id': e['group_id'],
      'description': e['description'],
      'amount_minor': e['amount_minor'],
      'currency': e['currency'],
      'payer': _brief(payer),
      'date': e['date'],
      'category': visible ? _categoryOut(c) : null,
      'notes': e['notes'],
      'split_method': e['split_method'],
      'splits': [
        for (final s in splits)
          {
            'user': _brief(s['user_id']),
            'share_minor': s['share_minor'],
            'input_value': s['input_value'],
            // Settled once they pay nobody in the group's fewest payments (expenses/service.py).
            'status': s['user_id'] == payer ? 'paid' : (pos[s['user_id']] ?? 0) < 0 ? 'owes' : 'settled',
          },
      ],
      'my_share_minor': myShare,
      'my_net_minor': (payer == me ? e['amount_minor'] as int : 0) - myShare,
      'created_by': _brief(e['created_by']),
      'acting_admin_id': e['acting_admin_id'],
      'import_batch_id': e['import_batch_id'],
      'created_at': e['created_at'],
      'updated_at': e['updated_at'],
      'deleted_at': e['deleted_at'],
      'version': e['version'],
    };
  }

  // ---- settle up (settlements/service.py _shared_balances, settle_up_plan) ----

  /// What each group's fewest payments have between you and a friend, in each current group you
  /// share in [currency], oldest first.
  List<(Json, int)> sharedBalances(String friendId, String currency) {
    if (friendId == me || !_people.containsKey(friendId)) throw const LocalNotFound('Person');
    final shared = [
      for (final g in _groupsFor(friendId))
        if (_isMember(g['id'], me) && g['currency'] == currency) g,
    ]..sort((a, b) => _time(a['created_at']).compareTo(_time(b['created_at'])));
    if (shared.isEmpty) throw const LocalNotFound('Person');
    return [for (final g in shared) (g, planned(me, _flows(g['id']))[friendId] ?? 0)];
  }

  /// GET /friends/{id}/settle-up
  Json settleUpPlan(String friendId, {String? currency}) {
    final cur = currency ?? userOut()['currency'] as String;
    final balances = sharedBalances(friendId, cur);
    return {
      'friend': _brief(friendId),
      'currency': cur,
      'net_minor': balances.fold(0, (a, b) => a + b.$2),
      'groups': [
        for (final (g, net) in balances)
          if (net != 0) {'group_id': g['id'], 'name': g['name'], 'net_minor': net},
      ],
    };
  }

  // ---- personal finance (personal/service.py, personal/repository.py) ----

  /// The personal entries, indexed the first time a view needs them.
  late final PersonalIndex _index = PersonalIndex(_personal);

  /// Live (or [deleted]) entries in the API's order that pass the filters. Filters the list
  /// sorted once per Ledger; shared when nothing is filtered, so callers only read it.
  List<PersonalRow> _personalRows({
    String? start,
    String? end,
    String? type,
    List<String>? categoryKeys,
    bool deleted = false,
    String? account,
    String? accountId,
    String? channel,
    String? source,
    bool? reviewed,
  }) {
    final rows = PersonalIndex.dated(deleted ? _index.deleted : _index.live, start, end);
    final anyCategory = categoryKeys == null || categoryKeys.isEmpty;
    if (type == null &&
        anyCategory &&
        account == null &&
        accountId == null &&
        channel == null &&
        source == null &&
        reviewed == null) {
      return rows;
    }
    return [
      for (final t in rows)
        if ((type == null || t.type == type) &&
            (anyCategory || categoryKeys.contains(_categories[t.categoryId]?['key'])) &&
            (account == null || t.account == account) &&
            (accountId == null || t.accountId == accountId) &&
            (channel == null || t.channel == channel) &&
            (source == null || t.source == source) &&
            (reviewed == null || t.reviewed == reviewed))
          t,
    ];
  }

  /// Your entries that are listed but not counted: those linked to a live expense or payment in
  /// a group you're in, and refunds of those (personal/repository.py covered_ids). The same set
  /// from one Ledger to the next while your entries, groups and profile haven't changed, or
  /// while it comes out the same ([_carry]), so the engine's answers that take it
  /// ([FinanceEngine.cashFlow]) are kept too. Shared: callers only read it.
  late final Set<String> notCounted = _carry(
    'notCounted',
    const {LedgerDomain.personal, LedgerDomain.groups, LedgerDomain.profile},
    () {
      final linked = {
        for (final t in _index.rows)
          if (_linkedLive(_expenses[t.expenseId]) || _linkedLive(_settlements[t.settlementId])) t.id,
      };
      return Set<String>.unmodifiable({
        ...linked,
        if (linked.isNotEmpty)
          for (final t in _index.rows)
            if (linked.contains(t.refundOfId)) t.id,
      });
    },
    same: (before, now) => before.length == now.length && before.containsAll(now),
  );

  bool _linkedLive(Json? row) => row != null && row['deleted_at'] == null && _isMember(row['group_id'] as String, me);

  bool _counted(PersonalRow t) => !notCounted.contains(t.id);

  Json _txnOut(PersonalRow row) {
    final t = row.raw;
    final c = _categories[t['category_id']];
    return {
      'id': t['id'],
      'type': t['type'],
      // Rows synced before migration 0013 have no direction: the one their type implies.
      'direction': row.flow.wire,
      'account_id': row.accountId,
      'transfer_group_id': row.transferGroupId,
      'refund_of_id': row.refundOfId,
      'holding_id': row.holdingId,
      'amount_minor': t['amount_minor'],
      'currency': t['currency'],
      'description': t['description'],
      'date': t['date'],
      'category': c == null ? null : _categoryOut(c),
      'notes': t['notes'],
      'channel': t['channel'],
      'merchant': t['merchant'],
      'account': t['account'],
      'source': row.source,
      'reference': t['reference'],
      'balance_minor': t['balance_minor'],
      'sms_at': t['sms_at'],
      'reviewed': row.reviewed,
      'expense_id': t['expense_id'],
      'settlement_id': t['settlement_id'],
      'counted': _counted(row),
      'acting_admin_id': t['acting_admin_id'],
      'created_at': t['created_at'],
      'deleted_at': t['deleted_at'],
      'version': t['version'],
    };
  }

  /// GET /personal/transactions
  Json personalList({
    String? start,
    String? end,
    String? type,
    List<String>? categoryKeys,
    bool deleted = false,
    String? account,
    String? accountId,
    String? channel,
    String? source,
    bool? reviewed,
    int limit = 100,
    int offset = 0,
  }) {
    final rows = _personalRows(
      start: start,
      end: end,
      type: type,
      categoryKeys: categoryKeys,
      deleted: deleted,
      account: account,
      accountId: accountId,
      channel: channel,
      source: source,
      reviewed: reviewed,
    );
    final page = rows.skip(offset).take(limit);
    // Entries in another currency (from before you changed yours) are listed but not counted,
    // nor are entries that became a group expense or payment.
    final (spent, income, refunds) = _spending(rows);
    return {
      'items': [for (final t in page) _txnOut(t)],
      'spent_minor': spent,
      'income_minor': income,
      'refunds_minor': refunds,
      'count': rows.length,
    };
  }

  /// (spent, income, refunds) of the counted [rows] in your currency (personal/service.py
  /// _spending): spent is expenses minus refunds, and may be negative. Transfers, adjustments
  /// and investments are neither.
  (int, int, int) _spending(Iterable<PersonalRow> rows) {
    final currency = userOut()['currency'];
    var expenses = 0, income = 0, refunds = 0;
    for (final t in rows) {
      if (t.currency != currency || !_counted(t)) continue;
      if (t.type == 'expense') {
        expenses += t.amount;
      } else if (t.type == 'income') {
        income += t.amount;
      } else if (t.type == 'refund') {
        refunds += t.amount;
      }
    }
    return (expenses - refunds, income, refunds);
  }

  /// GET /personal/transactions/{id}
  Json personalTransaction(String id) {
    final t = _index.byId[id];
    if (t == null) throw const LocalNotFound('Transaction');
    return _txnOut(t);
  }

  // ---- the finance engine (core/finance) ----

  /// The finance maths over your accounts and personal entries, in your currency: balances, cash
  /// flow, net worth, transfer suggestions. Handed on to the next Ledger while your entries,
  /// accounts and profile haven't changed ([_carry]), so a change to groups or categories doesn't
  /// sort the entries and work the balances out again.
  late final FinanceEngine finance = _carry(
    'finance',
    const {LedgerDomain.personal, LedgerDomain.profile},
    () => FinanceEngine(
      accounts: [
        for (final a in _accounts.values)
          if (FinAccount.read(a) case final account?) account,
      ],
      // Every entry of a type this build knows; the engine skips deleted ones where they don't count.
      entries: _index.rows,
      currency: userOut()['currency'] as String,
      goals: [
        for (final g in _goals.values)
          if (FinGoal.read(g) case final goal?) goal,
      ],
      contributions: [for (final c in _contributions.values) FinContribution.read(c)],
      holdings: [
        for (final h in _holdings.values)
          if (FinHolding.read(h) case final holding?) holding,
      ],
      rules: [
        for (final r in _allocationRules.values)
          if (FinRule.read(r) case final rule?) rule,
      ],
      plans: [
        for (final p in _plans.values)
          if (FinPlan.read(p) case final plan?) plan,
      ],
    ),
  );

  /// A category's label by id, or "Uncategorised" for none (or one this device doesn't have): how
  /// cash flow names its categories. The same function from one Ledger to the next while
  /// categories haven't changed, so the engine's answers that take it are kept too.
  late final String Function(String? categoryId) categoryLabel = _carry(
    'categoryLabel',
    const {LedgerDomain.categories},
    () => _labelsOf(_categories),
  );

  /// [categoryLabel] over [categories]. Static, so the function holds only the labels and not the
  /// Ledger it outlives.
  static String Function(String? categoryId) _labelsOf(Map<String, Json> categories) {
    final labels = {
      for (final MapEntry(:key, :value) in categories.entries)
        if (value['label'] case final String label) key: label,
    };
    return (id) => labels[id] ?? 'Uncategorised';
  }

  /// What friends owe you in Split in [currency], net (less than zero when you owe them): the
  /// `net_minor` of [overallBalances]' total in it, by the groups' fewest payments; 0 for none.
  int splitNet(String currency) => _splitNets[currency] ?? 0;

  late final Map<String, int> _splitNets = {
    for (final t in (overallBalances()['totals'] as List).cast<Json>()) t['currency'] as String: t['net_minor'] as int,
  };

  /// What a Ledger hands on to the next, per [slot]: the store it came from, the revisions of the
  /// parts of the data it was worked out from ([LedgerRevisions.of]), and the answer. One answer
  /// per slot: the store builds one Ledger after another, and only the newest is read.
  static final _carried = <String, (int, Object, Object)>{};

  /// What [build] gives, or what an earlier Ledger of the same store worked out for [slot] if
  /// none of [reads] has changed since, or if it's [same] as what [build] gives now. A Ledger
  /// built outside a store (LedgerRevisions.none, as in tests) always builds its own.
  T _carry<T extends Object>(
    String slot,
    Set<LedgerDomain> reads,
    T Function() build, {
    bool Function(T before, T now)? same,
  }) {
    if (revisions.store == 0) return build();
    final key = revisions.of(reads);
    final carried = _carried[slot];
    if (carried case (_, final at, final T kept) when at == key) return kept;
    var made = build();
    // The same answer as before is handed on as the one before, so what was worked out for it holds.
    if (carried case (final store, _, final T before)
        when store == revisions.store && (same?.call(before, made) ?? false)) {
      made = before;
    }
    _carried[slot] = (revisions.store, key, made);
    return made;
  }

  /// Lets go of what Ledgers of store [store] handed on (the store is closing: signed out, or
  /// out of view-as), so none of its data stays in memory.
  static void forgetCarried(int store) => _carried.removeWhere((_, carried) => carried.$1 == store);

  /// GET /personal/summary?month= (personal/service.py summary): the month's cash flow from the
  /// engine ([finance]), as the API gives it. Spent is expenses minus refunds, without your group
  /// share (that's on its own line), so it may be negative; by category the same, largest first.
  Json personalSummary(DateTime month) {
    final start = DateTime(month.year, month.month);
    final period = monthRange(start.year, start.month);
    final flow = finance.cashFlow(
      period,
      notCounted: notCounted,
      groupShareMinor: groupShareFor(period),
      countGroupShare: false,
      label: categoryLabel,
    );
    final monthName = DateFormat('MMMM', 'en_US').format(start);
    return {
      'month': DateFormat('yyyy-MM').format(start),
      'month_label': start.year == today.year ? monthName : '$monthName ${start.year}',
      'currency': finance.currency,
      'spent_minor': flow.spendingMinor,
      'income_minor': flow.incomeMinor,
      'refunds_minor': flow.refundsMinor,
      'left_over_minor': flow.incomeMinor - flow.spendingMinor,
      'group_share_minor': flow.groupShareMinor,
      'by_category': [
        for (final c in flow.byCategory)
          {
            'category': switch (_categories[c.categoryId]) {
              final category? => _categoryOut(category),
              null => null,
            },
            'label': c.label,
            'amount_minor': c.amountMinor,
          },
      ],
    };
  }

  /// Your share of the live group expenses dated in [period], in your currency
  /// (personal/repository.py group_share): what cash flow adds to spending when it's counted.
  int groupShareFor(DayRange period) {
    final currency = userOut()['currency'];
    var share = 0;
    for (final (day, cur, amount) in _myShares) {
      if (cur == currency && period.contains(day)) share += amount;
    }
    return share;
  }

  /// Your share of each live expense you have a share in: (day key, currency, share).
  late final List<(int, Object?, int)> _myShares = () {
    final me = this.me;
    final out = <(int, Object?, int)>[];
    for (final x in _expenses.values) {
      if (x['deleted_at'] != null) continue;
      int? share;
      for (final split in x['splits'] as List) {
        if (split['user_id'] == me) share = (share ?? 0) + (split['share_minor'] as int);
      }
      if (share != null) out.add((dayKey(x['date'] as String), x['currency'], share));
    }
    return out;
  }();

  /// GET /personal/accounts (personal/accounts.py list_accounts): your active and closed
  /// accounts, oldest first; with [deleted], only the deleted ones.
  List<Json> personalAccountList({bool deleted = false}) {
    final rows = [
      for (final a in _accounts.values)
        if ((a['deleted_at'] != null) == deleted) (a, isoMicros(a['created_at'])),
    ];
    rows.sort((a, b) {
      final t = a.$2.compareTo(b.$2);
      return t != 0 ? t : (a.$1['id'] as String).compareTo(b.$1['id'] as String);
    });
    return [for (final (a, _) in rows) _accountOut(a)];
  }

  /// GET /personal/accounts/{id}, deleted ones too.
  Json personalAccount(String id) => _accountOut(_accounts[id] ?? (throw const LocalNotFound('Account')));

  /// personal/schemas.py PersonalAccountOut. No balance: core/finance works it out.
  Json _accountOut(Json a) => {
    'id': a['id'],
    'name': a['name'],
    'type': a['type'],
    'currency': a['currency'],
    'opening_balance_minor': a['opening_balance_minor'],
    'sms_label': a['sms_label'],
    'status': a['status'],
    'acting_admin_id': a['acting_admin_id'],
    'created_at': a['created_at'],
    'updated_at': a['updated_at'],
    'deleted_at': a['deleted_at'],
    'version': a['version'],
  };

  // ---- goals (personal/goals.py, personal/contributions.py) ----

  /// GET /personal/goals (goals.py list_goals): your goals by priority, then oldest first; with
  /// [deleted], only the deleted ones. As synced: progress is the finance engine's
  /// ([FinanceEngine.goals]).
  List<Json> personalGoalList({bool deleted = false}) {
    final rows = [
      for (final g in _goals.values)
        if ((g['deleted_at'] != null) == deleted) (g, isoMicros(g['created_at'])),
    ];
    rows.sort((a, b) {
      final p = (a.$1['priority'] as int).compareTo(b.$1['priority'] as int);
      if (p != 0) return p;
      final t = a.$2.compareTo(b.$2);
      return t != 0 ? t : (a.$1['id'] as String).compareTo(b.$1['id'] as String);
    });
    return [for (final (g, _) in rows) _goalOut(g)];
  }

  /// GET /personal/goals/{id}, deleted ones too.
  Json personalGoal(String id) => _goalOut(_goals[id] ?? (throw const LocalNotFound('Goal')));

  /// personal/schemas.py PersonalGoalOut.
  Json _goalOut(Json g) => {
    'id': g['id'],
    'name': g['name'],
    'target_minor': g['target_minor'],
    'currency': g['currency'],
    'target_date': g['target_date'],
    'tracking_mode': g['tracking_mode'],
    'linked_account_id': g['linked_account_id'],
    'manual_progress_minor': g['manual_progress_minor'],
    'expected_return_bp': g['expected_return_bp'],
    'priority': g['priority'],
    'status': g['status'],
    'acting_admin_id': g['acting_admin_id'],
    'created_at': g['created_at'],
    'updated_at': g['updated_at'],
    'deleted_at': g['deleted_at'],
    'version': g['version'],
  };

  /// GET /personal/goal-contributions (contributions.py list_contributions): of goal [goalId] or
  /// of every goal, newest first (by date, then made, then id); with [deleted], only the deleted
  /// ones.
  List<Json> goalContributionList({String? goalId, bool deleted = false}) {
    final rows = [
      for (final c in _contributions.values)
        if ((c['deleted_at'] != null) == deleted && (goalId == null || c['goal_id'] == goalId)) c,
    ];
    rows.sort((a, b) => FinContribution.newestFirst(FinContribution.read(a), FinContribution.read(b)));
    return [for (final c in rows) _contributionOut(c)];
  }

  /// GET /personal/goal-contributions/{id}, deleted ones too.
  Json goalContribution(String id) =>
      _contributionOut(_contributions[id] ?? (throw const LocalNotFound('Contribution')));

  /// personal/schemas.py PersonalGoalContributionOut.
  Json _contributionOut(Json c) => {
    'id': c['id'],
    'goal_id': c['goal_id'],
    'transaction_id': c['transaction_id'],
    'amount_minor': c['amount_minor'],
    'currency': c['currency'],
    'date': c['date'],
    'note': c['note'],
    'acting_admin_id': c['acting_admin_id'],
    'created_at': c['created_at'],
    'deleted_at': c['deleted_at'],
    'version': c['version'],
  };

  // ---- allocation rules and plans (personal/allocation_rules.py, allocation_plans.py) ----

  /// GET /personal/allocation-rules (allocation_rules.py list_rules): by priority, then oldest
  /// first; with [deleted], only the deleted ones. As synced: what each plans is the finance
  /// engine's ([FinanceEngine.ruleViews]).
  List<Json> allocationRuleList({bool deleted = false}) {
    final rows = [
      for (final r in _allocationRules.values)
        if ((r['deleted_at'] != null) == deleted) (r, isoMicros(r['created_at'])),
    ];
    rows.sort((a, b) {
      final p = (a.$1['priority'] as int).compareTo(b.$1['priority'] as int);
      if (p != 0) return p;
      final t = a.$2.compareTo(b.$2);
      return t != 0 ? t : (a.$1['id'] as String).compareTo(b.$1['id'] as String);
    });
    return [for (final (r, _) in rows) _allocationRuleOut(r)];
  }

  /// GET /personal/allocation-rules/{id}, deleted ones too.
  Json allocationRule(String id) => _allocationRuleOut(_allocationRules[id] ?? (throw const LocalNotFound('Rule')));

  /// personal/schemas.py PersonalAllocationRuleOut.
  Json _allocationRuleOut(Json r) => {
    'id': r['id'],
    'name': r['name'],
    'trigger': r['trigger'],
    'source_category_id': r['source_category_id'],
    'source_account_id': r['source_account_id'],
    'kind': r['kind'],
    'percent_bp': r['percent_bp'],
    'amount_minor': r['amount_minor'],
    'currency': r['currency'],
    'goal_id': r['goal_id'],
    'account_id': r['account_id'],
    'active': r['active'],
    'priority': r['priority'],
    'acting_admin_id': r['acting_admin_id'],
    'created_at': r['created_at'],
    'updated_at': r['updated_at'],
    'deleted_at': r['deleted_at'],
    'version': r['version'],
  };

  /// GET /personal/allocation-plans (allocation_plans.py list_plans): oldest first, filtered by
  /// income, rule, goal or account when given; with [deleted], only the deleted ones. No status:
  /// that's the finance engine's ([FinanceEngine.planViews]).
  List<Json> allocationPlanList({
    String? sourceTransactionId,
    String? ruleId,
    String? goalId,
    String? accountId,
    bool deleted = false,
  }) {
    final rows = [
      for (final p in _plans.values)
        if ((p['deleted_at'] != null) == deleted &&
            (sourceTransactionId == null || p['source_transaction_id'] == sourceTransactionId) &&
            (ruleId == null || p['rule_id'] == ruleId) &&
            (goalId == null || p['goal_id'] == goalId) &&
            (accountId == null || p['account_id'] == accountId))
          (p, isoMicros(p['created_at'])),
    ];
    rows.sort((a, b) {
      final t = a.$2.compareTo(b.$2);
      return t != 0 ? t : (a.$1['id'] as String).compareTo(b.$1['id'] as String);
    });
    return [for (final (p, _) in rows) _planOut(p)];
  }

  /// GET /personal/allocation-plans/{id}, deleted ones too.
  Json allocationPlan(String id) => _planOut(_plans[id] ?? (throw const LocalNotFound('Plan')));

  /// personal/schemas.py PersonalAllocationPlanOut.
  Json _planOut(Json p) => {
    'id': p['id'],
    'source_transaction_id': p['source_transaction_id'],
    'rule_id': p['rule_id'],
    'snapshot_kind': p['snapshot_kind'],
    'snapshot_percent_bp': p['snapshot_percent_bp'],
    'snapshot_amount_minor': p['snapshot_amount_minor'],
    'planned_minor': p['planned_minor'],
    'currency': p['currency'],
    'goal_id': p['goal_id'],
    'account_id': p['account_id'],
    'acting_admin_id': p['acting_admin_id'],
    'created_at': p['created_at'],
    'updated_at': p['updated_at'],
    'deleted_at': p['deleted_at'],
    'version': p['version'],
  };

  /// GET /personal/accounts/reported: each account label your entries carry, most recently
  /// used first, with the latest balance its bank reported (personal/service.py
  /// reported_accounts).
  List<Json> personalReportedAccounts() {
    // Latest by when it happened, then when it was made, then id.
    int when(PersonalRow a, PersonalRow b) {
      final at = a.atMicros.compareTo(b.atMicros);
      if (at != 0) return at;
      final made = a.createdMicros.compareTo(b.createdMicros);
      return made != 0 ? made : a.id.compareTo(b.id);
    }

    final byAccount = <String, _AccountUse>{};
    for (final t in _index.live) {
      final name = t.account;
      if (name == null) continue;
      final a = byAccount[name] ??= _AccountUse(name, t);
      a.count++;
      if (when(t, a.last) > 0) a.last = t;
      if (t.balance != null && (a.reported == null || when(t, a.reported!) > 0)) a.reported = t;
    }
    final out = byAccount.values.toList()
      ..sort((a, b) {
        final byTime = when(b.last, a.last);
        return byTime != 0 ? byTime : a.name.compareTo(b.name);
      });
    return [
      for (final a in out)
        {
          'account': a.name,
          'currency': a.last.currency,
          'balance_minor': a.reported?.balance,
          'balance_at': a.reported == null ? null : a.reported!.raw['sms_at'] ?? a.reported!.raw['created_at'],
          'count': a.count,
        },
    ];
  }

  // ---- personal entries in Split (on the device only; no API answer to match) ----

  /// Splits you paid that could be the same spend as entry [txnId]: the same amount and
  /// currency, dated within [windowDays] of it, live in a group you're in, and not linked to
  /// another entry. Closest date first; each as GET /expenses/{id} answers.
  List<Json> linkCandidates(String txnId, {int windowDays = 3}) {
    final t = _index.byId[txnId] ?? (throw const LocalNotFound('Transaction'));
    final day = localDay(t.day);
    final found = <(Json, int, int)>[];
    for (final e in _paidByMe[(t.amount, t.currency)] ?? const <Json>[]) {
      if (!_isMember(e['group_id'] as String, me)) continue;
      if (_index.linkedTo(e['id'] as String).any((p) => p.id != txnId)) continue;
      final apart = localDay(dayKey(e['date'] as String)).difference(day).inDays.abs();
      if (apart <= windowDays) found.add((e, apart, isoMicros(e['created_at'])));
    }
    found.sort((a, b) {
      final byDay = a.$2.compareTo(b.$2);
      return byDay != 0 ? byDay : b.$3.compareTo(a.$3);
    });
    return [for (final (e, _, _) in found) expense(e['id'] as String)];
  }

  /// Your live expenses (that you paid) by amount and currency, in the order they're stored.
  late final Map<(Object?, Object?), List<Json>> _paidByMe = () {
    final me = this.me;
    final out = <(Object?, Object?), List<Json>>{};
    for (final e in _expenses.values) {
      if (e['deleted_at'] == null && e['payer_id'] == me) (out[(e['amount_minor'], e['currency'])] ??= []).add(e);
    }
    return out;
  }();

  /// What entry [txnId] became in Split, or null: a split or a payment, its group, the other
  /// person for a payment, and whether it still stands (live, in a group you're in; only then
  /// is the entry not counted).
  PersonalLink? personalLink(String txnId) {
    final t = rawPersonal(txnId);
    final expenseId = t?['expense_id'] as String?, paymentId = t?['settlement_id'] as String?;
    if (expenseId == null && paymentId == null) return null;
    final row = expenseId != null ? _expenses[expenseId] : _settlements[paymentId];
    String? other;
    if (paymentId != null && row != null) other = row['from_user'] == me ? row['to_user'] as String : row['from_user'] as String;
    return (
      payment: paymentId != null,
      id: (expenseId ?? paymentId)!,
      group: row == null ? null : _groups[row['group_id']]?['name'] as String?,
      person: other == null ? null : _brief(other)['name'] as String,
      live: _linkedLive(row),
    );
  }

  /// Who you paid, or were paid by, the last time an entry from [merchant] became a payment.
  String? friendPaidBefore(String merchant) {
    // The newest made; of two made at once, the first synced.
    PersonalRow? latest;
    for (final t in _index.paymentsFrom(merchant)) {
      if (_settlements[t.settlementId] != null && (latest == null || t.createdMicros > latest.createdMicros)) latest = t;
    }
    final s = latest == null ? null : _settlements[latest.settlementId]!;
    return s == null ? null : (s['from_user'] == me ? s['to_user'] : s['from_user']) as String;
  }

  /// The category you chose last for an entry ([scope] "personal") or a split ("group") from
  /// the same [merchant], or with the same description as [text] (core/categorise). Merchants are
  /// compared by [merchantKey], so "ZOMATO LIMITED" and "Zomato" are one. First the rules learned
  /// from your choices, newest first; then, from before rules were kept, your own manual entries
  /// (in Personal) or the splits you created (in groups), newest first: an SMS entry's category
  /// was the app's guess, not yours. A category not offered in [scope] gives the one there with
  /// its key, if any. [income] keeps income and spending apart.
  ///
  /// Each source is filed by merchant key once per Ledger, so this is two [merchantKey] calls and
  /// a few lookups, however much data there is.
  String? learnedCategory(String text, {String? merchant, required String scope, bool income = false}) {
    final keys = {merchantKey(merchant), merchantKey(text)}..remove('');
    if (keys.isEmpty) return null;
    final offered = _offered(scope);
    String? usable(Object? categoryId) => _usable(offered, categoryId);
    if ((income ? _incomeRules : _spendRules).first(keys, (r) => usable(r['category_id'])) case final id?) return id;
    return scope == 'personal'
        ? (income ? _index.chosenIncome : _index.chosenSpend).first(keys, (t) => usable(t.categoryId))
        : _mySplits.first(keys, (e) => usable(e['category_id']));
  }

  /// [categoryId] if it's offered (see [_offered]), else the offered one with its key, if any.
  String? _usable(({Set<Object?> ids, Map<Object?, String> byKey}) offered, Object? categoryId) {
    if (categoryId == null) return null;
    if (offered.ids.contains(categoryId)) return categoryId as String;
    final key = _categories[categoryId]?['key'];
    return key == null ? null : offered.byKey[key];
  }

  /// [learnedCategory]'s answers for [scope] as plain maps, for working them out away from this
  /// Ledger (core/sms/sms_scan.dart).
  LearnedCategories learnedCategories(String scope) {
    final offered = _offered(scope);
    Map<String, (int, String)> table<T>(MerchantIndex<T> index, Object? Function(T row) categoryOf) =>
        index.firstByKey((row) => _usable(offered, categoryOf(row)));
    final splits = scope == 'personal' ? null : table(_mySplits, (e) => e['category_id']);
    return LearnedCategories(
      spendRules: table(_spendRules, (r) => r['category_id']),
      incomeRules: table(_incomeRules, (r) => r['category_id']),
      spendChosen: splits ?? table(_index.chosenSpend, (t) => t.categoryId),
      incomeChosen: splits ?? table(_index.chosenIncome, (t) => t.categoryId),
      offeredByKey: {for (final MapEntry(:key, :value) in offered.byKey.entries) key as String: value},
    );
  }

  /// The categories offered in [scope] (as categories(scope:) lists them): their ids, and by key
  /// the one a key gives (built-in first: your own category could have the same key).
  ({Set<Object?> ids, Map<Object?, String> byKey}) _offered(String? scope) => _offeredIn[scope] ??= () {
    final ids = <Object?>{};
    final builtIn = <Object?, String>{}, any = <Object?, String>{};
    for (final c in _visibleCategories(scope)) {
      ids.add(c['id']);
      any.putIfAbsent(c['key'], () => c['id'] as String);
      if (c['owner_id'] == null) builtIn.putIfAbsent(c['key'], () => c['id'] as String);
    }
    return (ids: ids, byKey: {...any, ...builtIn});
  }();

  final _offeredIn = <String?, ({Set<Object?> ids, Map<Object?, String> byKey})>{};

  /// Learned rules for spending ([_spendRules]) or income ([_incomeRules]), newest first, filed by
  /// their pattern's merchant key.
  late final MerchantIndex<Json> _spendRules = _rulesFor(false), _incomeRules = _rulesFor(true);

  MerchantIndex<Json> _rulesFor(bool income) => MerchantIndex(
    newestMadeFirst([
      for (final r in _rules)
        if (r['income'] == income) (r, isoMicros(r['updated_at'])),
    ]),
    (r) => [r['pattern'] as String?],
  );

  /// The live splits you created, newest first, filed by merchant and description.
  late final MerchantIndex<Json> _mySplits = MerchantIndex(
    newestMadeFirst([
      for (final e in _expenses.values)
        if (e['deleted_at'] == null && e['created_by'] == me) (e, isoMicros(e['created_at'])),
    ]),
    (e) => [e['merchant'] as String?, e['description'] as String?],
  );

  /// "reference|type" for every entry with a bank reference, deleted ones too: a payment
  /// already here (or removed) whatever message it came from. A copy, yours to add to.
  Set<String> personalReferences() => {..._index.references};

  /// Your newest entry made by hand (live, with no account yet) of [type] and [amountMinor],
  /// dated within a day of [day]: one the bank's SMS is about.
  Json? manualMatch(String type, int amountMinor, DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    for (final t in _index.manualWithoutAccount(type, amountMinor)) {
      if (localDay(t.day).difference(target).inDays.abs() <= 1) return _txnOut(t);
    }
    return null;
  }

  /// Your live entry linked to expense [expenseId], as GET /personal/transactions/{id} answers.
  Json? personalLinkedTo(String expenseId) {
    final t = _index.linkedTo(expenseId).firstOrNull;
    return t == null ? null : _txnOut(t);
  }

  // ---- for reading bank SMS (core/sms/sms_scan.dart, features/sms/sms_importer.dart) ----

  /// The id of every personal entry here, deleted ones too, and of a type this build doesn't know
  /// (which the views skip): a message whose entry a newer build changed isn't added again.
  Set<String> personalIds() => {for (final t in _personal) t['id'] as String};

  /// Every personal entry of a type this build knows, deleted ones too, as typed rows in the order
  /// they were synced: where a read takes the spends a refund can be for and the other halves a
  /// transfer can pair with. Shared: callers only read it.
  List<PersonalRow> get personalRows => _index.rows;

  /// What [manualMatch] chooses from: by type and amount, the id and day (dayKey) of each live
  /// entry made by hand with no account yet, in the API's order.
  Map<(String, int), List<(String, int)>> manualCandidates() => {
    for (final MapEntry(:key, :value) in _index.manualByTypeAndAmount.entries)
      key: [for (final t in value) (t.id, t.day)],
  };

  /// Your live entry (the first in the API's order) with bank reference [reference] and [type].
  String? personalWithReference(String reference, String type) => _index.liveWithReference(reference, type)?.id;

  /// Your live entry (the first in the API's order) of [type] and [amount] from [merchant] (null
  /// when none was named), through [account] (null: any account).
  String? personalPaid({required String type, required int amount, String? account, String? merchant}) {
    for (final t in _index.liveOf(type, amount)) {
      if ((account == null || t.account == account) && t.merchant == merchant) return t.id;
    }
    return null;
  }

  // ---- raw entities, for building writes ----

  Json? rawGroup(String id) => _groups[id];
  Json? rawExpense(String id) => _expenses[id];
  Json? rawSettlement(String id) => _settlements[id];
  Json? rawPersonal(String id) => _index.byId[id]?.raw;
  Json? rawCategory(String id) => _categories[id];
  Json? rawAccount(String id) => _accounts[id];
  Json? rawGoal(String id) => _goals[id];
  Json? rawContribution(String id) => _contributions[id];

  /// Every goal as synced, deleted ones too. Shared: callers only read it.
  Iterable<Json> get rawGoals => _goals.values;

  /// Every contribution as synced, deleted ones too. Shared: callers only read it.
  Iterable<Json> get rawContributions => _contributions.values;

  /// The contributions (deleted ones too) made with entry [entryId], or to goal [goalId].
  List<Json> rawContributionsOf({String? entryId, String? goalId}) => [
    if (entryId != null) ...?_contributionsBy.entry[entryId],
    if (goalId != null) ...?_contributionsBy.goal[goalId],
  ];

  late final ({Map<String, List<Json>> entry, Map<String, List<Json>> goal}) _contributionsBy = () {
    final entry = <String, List<Json>>{}, goal = <String, List<Json>>{};
    for (final c in _contributions.values) {
      if (c['transaction_id'] case final String t) (entry[t] ??= []).add(c);
      (goal[c['goal_id'] as String] ??= []).add(c);
    }
    return (entry: entry, goal: goal);
  }();

  Json? rawHolding(String id) => _holdings[id];

  /// Allocation rule [id] as synced, deleted or not.
  Json? rawRule(String id) => _allocationRules[id];

  /// Allocation plan [id] as synced, deleted or not.
  Json? rawPlan(String id) => _plans[id];

  /// Every allocation rule as synced, deleted ones too. Shared: callers only read it.
  Iterable<Json> get rawRules => _allocationRules.values;

  /// The plans (deleted ones too) made from income [incomeId], as synced.
  List<Json> rawPlansOf(String incomeId) => _plansByIncome[incomeId] ?? const [];

  late final Map<String, List<Json>> _plansByIncome = () {
    final out = <String, List<Json>>{};
    for (final p in _plans.values) {
      (out[p['source_transaction_id'] as String] ??= []).add(p);
    }
    return out;
  }();

  List<Json> rawMembers(String groupId) => _members[groupId] ?? const [];
  Json brief(String userId) => _brief(userId);
}

/// What Ledger.learnedCategory answers for one scope, as plain maps that can go to another
/// isolate. For each merchant key: where the first row filed under it that gives a category
/// offered in the scope comes, and that category. The learned rules come first, then your own
/// rows (manual entries in Personal, the splits you made in groups); spending and income apart.
class LearnedCategories {
  const LearnedCategories({
    required this.spendRules,
    required this.incomeRules,
    required this.spendChosen,
    required this.incomeChosen,
    required this.offeredByKey,
  });

  final Map<String, (int, String)> spendRules, incomeRules, spendChosen, incomeChosen;

  /// The category offered in the scope for each category key (built-in first).
  final Map<String, String> offeredByKey;

  /// What learnedCategory gives for these merchant keys (merchantKey of the merchant and of the
  /// text, without empty ones).
  String? lookup(Set<String> keys, {bool income = false}) =>
      _first(income ? incomeRules : spendRules, keys) ?? _first(income ? incomeChosen : spendChosen, keys);

  static String? _first(Map<String, (int, String)> table, Set<String> keys) {
    (int, String)? best;
    for (final key in keys) {
      final found = table[key];
      if (found != null && (best == null || found.$1 < best.$1)) best = found;
    }
    return best?.$2;
  }
}

/// One account label's entries while Ledger.personalReportedAccounts goes through them: the
/// latest, the latest with a balance its bank reported, and how many.
class _AccountUse {
  _AccountUse(this.name, this.last);

  final String name;
  PersonalRow last;
  PersonalRow? reported;
  var count = 0;
}

/// An expense ([expense]) or a payment in the feed's order, with what it's sorted and filtered
/// by read once per synced map (reused by the next Ledger, as PersonalRow is).
class _FeedRow {
  factory _FeedRow(Json raw, {required bool expense}) => _read[raw] ??= _FeedRow._(raw, expense: expense);

  static final _read = Expando<_FeedRow>('_FeedRow');

  _FeedRow._(this.raw, {required this.expense})
    : id = raw['id'] as String,
      groupId = raw['group_id'] as String,
      date = raw['date'] as String,
      day = plainDayKey(raw['date'] as String),
      createdMicros = isoMicros(raw['created_at']),
      deleted = raw['deleted_at'] != null;

  final Json raw;
  final bool expense;
  final String id;
  final String groupId;
  final String date;

  /// plainDayKey(date), for sorting.
  final int day;
  final int createdMicros;
  final bool deleted;

  static int newestFirst(_FeedRow a, _FeedRow b) {
    final d = compareDates(b.date, b.day, a.date, a.day);
    if (d != 0) return d;
    final t = b.createdMicros.compareTo(a.createdMicros);
    return t != 0 ? t : b.id.compareTo(a.id);
  }
}

DateTime _time(Object? iso) => iso == null ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : DateTime.parse(iso as String);
