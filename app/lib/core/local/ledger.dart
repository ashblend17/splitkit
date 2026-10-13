/// The synced data on this device, and every answer the screens need computed from it.
///
/// Each view returns the same JSON the API would (same fields, same order, same rules), so the
/// generated models parse it and screens don't know where it came from. The Python function each
/// view mirrors is named in its doc comment; test/core/local_parity_test.dart checks them against
/// real API answers captured from the seed. Pure Dart: no Flutter, no I/O.
library;

import 'package:intl/intl.dart';

import '../clock.dart';
import 'balance_engine.dart';

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
  Ledger(Iterable<LocalEntity> entities, {DateTime? today}) : today = today ?? appClock.now() {
    for (final e in entities) {
      final d = e.data;
      switch (e.entity) {
        case 'profile':
          profile = d;
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
        case 'category':
          _categories[e.entityId] = d;
        case 'layout':
          _layouts[e.entityId] = d;
      }
    }
    final me = profile;
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

  /// The viewer (users/schemas.py UserOut). Null until the user stream has synced.
  Json? profile;

  final _groups = <String, Json>{};
  final _members = <String, List<Json>>{};
  final _people = <String, Json>{};
  final _expenses = <String, Json>{};
  final _settlements = <String, Json>{};
  final _personal = <Json>[];
  final _categories = <String, Json>{};
  final _layouts = <String, Json>{};

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

  /// groups/repository.py active_members: current members by join time, then name.
  List<Json> _activeMembers(String groupId) {
    final rows = [for (final m in _members[groupId] ?? const <Json>[]) if (m['left_at'] == null) m];
    rows.sort((a, b) {
      final t = _time(a['joined_at']).compareTo(_time(b['joined_at']));
      return t != 0 ? t : _name(a['user_id']).compareTo(_name(b['user_id']));
    });
    return rows;
  }

  Set<String> _activeIds(String groupId) => {for (final m in _activeMembers(groupId)) m['user_id'] as String};

  bool _isMember(String groupId, String userId) =>
      (_members[groupId] ?? const []).any((m) => m['user_id'] == userId && m['left_at'] == null);

  /// groups/repository.py groups_for_user: newest first.
  List<Json> _groupsFor(String userId) {
    final out = [for (final g in _groups.values) if (_isMember(g['id'], userId)) g];
    out.sort((a, b) => _time(b['created_at']).compareTo(_time(a['created_at'])));
    return out;
  }

  Json _requireGroup(String groupId) {
    final g = _groups[groupId];
    if (g == null || !_isMember(groupId, me)) throw const LocalNotFound('Group');
    return g;
  }

  /// balances/repository.py flows_by_group: live expense splits and settlements.
  List<Flow> _flows(String groupId) => [
    for (final e in _expenses.values)
      if (e['group_id'] == groupId && e['deleted_at'] == null)
        ...expenseFlows(e['payer_id'], [for (final s in e['splits'] as List) (s['user_id'] as String, s['share_minor'] as int)]),
    for (final s in _settlements.values)
      if (s['group_id'] == groupId && s['deleted_at'] == null)
        settlementFlow(s['from_user'], s['to_user'], s['amount_minor']),
  ];

  /// groups/service.py _to_out.
  Json _groupOut(Json g) {
    final id = g['id'] as String;
    var spent = 0;
    for (final e in _expenses.values) {
      if (e['group_id'] == id && e['deleted_at'] == null) spent += e['amount_minor'] as int;
    }
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
      'my_net_minor': positions(_flows(id))[me] ?? 0,
      'last_activity_at': g['last_activity_at'],
      'version': g['version'],
    };
  }

  /// GET /groups
  List<Json> groups({bool archived = false}) => [
    for (final g in _groupsFor(me))
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
    final pos = positions(flows);
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

  /// GET /balances. Groups you have left are not on this device; leaving needs a zero balance,
  /// so they add nothing.
  Json overallBalances() {
    final friendNets = <(String, String), int>{};
    final groupNets = <Json>[];
    for (final g in _groupsFor(me)) {
      final id = g['id'] as String;
      final currency = g['currency'] as String;
      final flows = _flows(id);
      for (final e in pairwise(me, flows).entries) {
        friendNets[(e.key, currency)] = (friendNets[(e.key, currency)] ?? 0) + e.value;
      }
      for (final m in _activeMembers(id)) {
        if (m['user_id'] != me) friendNets.putIfAbsent((m['user_id'], currency), () => 0);
      }
      groupNets.add({'group_id': id, 'name': g['name'], 'currency': currency, 'net_minor': positions(flows)[me] ?? 0});
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

  static bool _like(String? text, String needle) => text != null && text.toLowerCase().contains(needle.toLowerCase());

  /// GET /feed
  List<Json> feed({String? groupId, bool deleted = false, FeedFilters filters = const FeedFilters(), int limit = 30, int offset = 0}) {
    final f = filters;
    final groupIds = groupId != null ? {_requireGroup(groupId)['id'] as String} : {for (final g in _groupsFor(me)) g['id'] as String};
    if (groupIds.isEmpty) return [];
    final search = f.search;
    bool named(String userId) => search != null && _like(_name(userId), search);

    final expenses = [
      for (final e in _expenses.values)
        if (groupIds.contains(e['group_id']) &&
            (e['deleted_at'] != null) == deleted &&
            (f.category == null || (e['category'] as Map?)?['key'] == f.category) &&
            (f.start == null || (e['date'] as String).compareTo(f.start!) >= 0) &&
            (f.end == null || (e['date'] as String).compareTo(f.end!) <= 0) &&
            (search == null || _like(e['description'], search) || named(e['payer_id'])))
          e,
    ];
    final settlements = !f.payments
        ? const <Json>[]
        : [
            for (final s in _settlements.values)
              if (groupIds.contains(s['group_id']) &&
                  (s['deleted_at'] != null) == deleted &&
                  (f.start == null || (s['date'] as String).compareTo(f.start!) >= 0) &&
                  (f.end == null || (s['date'] as String).compareTo(f.end!) <= 0) &&
                  (search == null || named(s['from_user']) || named(s['to_user'])))
                s,
          ];

    final pairs = <String, Map<String, int>>{};
    Map<String, int> pairsFor(String gid) => pairs[gid] ??= pairwise(me, _flows(gid));

    final items = <Json>[];
    for (final e in expenses) {
      final splits = (e['splits'] as List).cast<Map>();
      final myShare = splits.where((s) => s['user_id'] == me).map((s) => s['share_minor'] as int).firstOrNull ?? 0;
      final p = pairsFor(e['group_id']);
      final payer = e['payer_id'] as String;
      if (f.openOnly && !_open(payer, splits, myShare, p)) continue;
      final category = e['category'] as Map?;
      items.add({
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
        'settled': payer != me && myShare > 0 && (p[payer] ?? 0) >= 0,
        'by_admin': e['acting_admin_id'] != null,
        'deleted_at': e['deleted_at'],
      });
    }
    for (final s in settlements) {
      final amount = s['amount_minor'] as int;
      final effect = s['from_user'] == me ? amount : s['to_user'] == me ? -amount : 0;
      items.add({
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
      });
    }
    // Newest first; id breaks ties (imported rows share a timestamp).
    items.sort((a, b) {
      final d = (b['date'] as String).compareTo(a['date'] as String);
      if (d != 0) return d;
      final t = _time(b['created_at']).compareTo(_time(a['created_at']));
      return t != 0 ? t : (b['id'] as String).compareTo(a['id'] as String);
    });
    final end = offset + limit < items.length ? offset + limit : items.length;
    return offset >= items.length ? [] : items.sublist(offset, end);
  }

  /// You owe the payer, or you paid and someone in the split still owes you.
  bool _open(String payer, List<Map> splits, int myShare, Map<String, int> pairs) {
    if (payer == me) {
      return splits.any((s) => s['user_id'] != me && s['share_minor'] != 0 && (pairs[s['user_id']] ?? 0) > 0);
    }
    return myShare > 0 && (pairs[payer] ?? 0) < 0;
  }

  // ---- expenses (expenses/service.py to_out) ----

  /// GET /expenses/{id}
  Json expense(String expenseId) {
    final e = _expenses[expenseId];
    if (e == null || !_isMember(e['group_id'], me)) throw const LocalNotFound('Expense');
    final payer = e['payer_id'] as String;
    final splits = (e['splits'] as List).cast<Map>();
    final myShare = splits.where((s) => s['user_id'] == me).map((s) => s['share_minor'] as int).firstOrNull ?? 0;
    final owedToPayer = pairwise(payer, _flows(e['group_id']));
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
            'status': s['user_id'] == payer ? 'paid' : (owedToPayer[s['user_id']] ?? 0) > 0 ? 'owes' : 'settled',
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

  /// Your balance with a friend in each current group you share in [currency], oldest first.
  List<(Json, int)> sharedBalances(String friendId, String currency) {
    if (friendId == me || !_people.containsKey(friendId)) throw const LocalNotFound('Person');
    final shared = [
      for (final g in _groupsFor(friendId))
        if (_isMember(g['id'], me) && g['currency'] == currency) g,
    ]..sort((a, b) => _time(a['created_at']).compareTo(_time(b['created_at'])));
    if (shared.isEmpty) throw const LocalNotFound('Person');
    return [for (final g in shared) (g, pairwise(me, _flows(g['id']))[friendId] ?? 0)];
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

  List<Json> _personalRows({
    String? start,
    String? end,
    String? type,
    List<String>? categoryKeys,
    bool deleted = false,
    String? account,
    String? channel,
    String? source,
    bool? reviewed,
  }) {
    final rows = [
      for (final t in _personal)
        if ((t['deleted_at'] != null) == deleted &&
            (start == null || (t['date'] as String).compareTo(start) >= 0) &&
            (end == null || (t['date'] as String).compareTo(end) <= 0) &&
            (type == null || t['type'] == type) &&
            (categoryKeys == null || categoryKeys.isEmpty || categoryKeys.contains(_categories[t['category_id']]?['key'])) &&
            (account == null || t['account'] == account) &&
            (channel == null || t['channel'] == channel) &&
            (source == null || _source(t) == source) &&
            (reviewed == null || _reviewed(t) == reviewed))
          t,
    ];
    rows.sort((a, b) {
      final d = (b['date'] as String).compareTo(a['date'] as String);
      if (d != 0) return d;
      final t = _time(b['created_at']).compareTo(_time(a['created_at']));
      return t != 0 ? t : (b['id'] as String).compareTo(a['id'] as String);
    });
    return rows;
  }

  // Rows synced before these columns existed (migration 0010) have no such keys.
  static String _source(Json t) => t['source'] as String? ?? 'manual';
  static bool _reviewed(Json t) => t['reviewed'] as bool? ?? true;

  /// Entries linked to a live expense or payment in a group you're in
  /// (personal/repository.py covered_ids): listed, but not counted.
  late final Set<String> _covered = {
    for (final t in _personal)
      if (_linkedLive(_expenses[t['expense_id']]) || _linkedLive(_settlements[t['settlement_id']])) t['id'] as String,
  };

  bool _linkedLive(Json? row) => row != null && row['deleted_at'] == null && _isMember(row['group_id'] as String, me);

  bool _counted(Json t) => !_covered.contains(t['id']);

  Json _txnOut(Json t) {
    final c = _categories[t['category_id']];
    return {
      'id': t['id'],
      'type': t['type'],
      'amount_minor': t['amount_minor'],
      'currency': t['currency'],
      'description': t['description'],
      'date': t['date'],
      'category': c == null ? null : _categoryOut(c),
      'notes': t['notes'],
      'channel': t['channel'],
      'merchant': t['merchant'],
      'account': t['account'],
      'source': _source(t),
      'reference': t['reference'],
      'balance_minor': t['balance_minor'],
      'sms_at': t['sms_at'],
      'reviewed': _reviewed(t),
      'expense_id': t['expense_id'],
      'settlement_id': t['settlement_id'],
      'counted': _counted(t),
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
      channel: channel,
      source: source,
      reviewed: reviewed,
    );
    final page = rows.skip(offset).take(limit);
    // Entries in another currency (from before you changed yours) are listed but not counted,
    // nor are entries that became a group expense or payment.
    final currency = userOut()['currency'];
    int sum(String kind) => rows
        .where((t) => t['type'] == kind && t['currency'] == currency && _counted(t))
        .fold(0, (a, t) => a + (t['amount_minor'] as int));
    return {'items': [for (final t in page) _txnOut(t)], 'spent_minor': sum('expense'), 'income_minor': sum('income'), 'count': rows.length};
  }

  /// GET /personal/transactions/{id}
  Json personalTransaction(String id) {
    final t = _personal.where((t) => t['id'] == id).firstOrNull;
    if (t == null) throw const LocalNotFound('Transaction');
    return _txnOut(t);
  }

  /// GET /personal/summary?month=
  Json personalSummary(DateTime month) {
    final start = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    final s = _day(start), e = _day(last);
    final currency = userOut()['currency'];
    final rows = _personalRows(start: s, end: e).where((t) => t['currency'] == currency && _counted(t));
    var spent = 0, income = 0;
    final byCat = <String?, int>{};
    for (final t in rows) {
      final amount = t['amount_minor'] as int;
      if (t['type'] == 'expense') {
        spent += amount;
        byCat[t['category_id'] as String?] = (byCat[t['category_id']] ?? 0) + amount;
      } else if (t['type'] == 'income') {
        income += amount;
      }
    }
    final totals = [
      for (final entry in byCat.entries)
        () {
          final c = _categories[entry.key];
          return {'category': c == null ? null : _categoryOut(c), 'label': c?['label'] ?? 'Uncategorised', 'amount_minor': entry.value};
        }(),
    ]..sort((a, b) {
        final byAmount = (b['amount_minor'] as int).compareTo(a['amount_minor'] as int);
        return byAmount != 0 ? byAmount : (a['label'] as String).compareTo(b['label'] as String);
      });
    var groupShare = 0;
    for (final x in _expenses.values) {
      final date = x['date'] as String;
      if (x['deleted_at'] != null || x['currency'] != currency || date.compareTo(s) < 0 || date.compareTo(e) > 0) continue;
      for (final split in x['splits'] as List) {
        if (split['user_id'] == me) groupShare += split['share_minor'] as int;
      }
    }
    final monthName = DateFormat('MMMM', 'en_US').format(start);
    return {
      'month': DateFormat('yyyy-MM').format(start),
      'month_label': start.year == today.year ? monthName : '$monthName ${start.year}',
      'currency': currency,
      'spent_minor': spent,
      'income_minor': income,
      'left_over_minor': income - spent,
      'group_share_minor': groupShare,
      'by_category': totals,
    };
  }

  /// GET /personal/accounts: each account or card your entries went through, most recently
  /// used first, with the latest balance its bank reported (personal/service.py accounts).
  List<Json> personalAccounts() {
    final byAccount = <String, List<Json>>{};
    for (final t in _personalRows()) {
      final account = t['account'] as String?;
      if (account != null) (byAccount[account] ??= []).add(t);
    }
    int when(Json a, Json b) {
      final at = _time(a['sms_at'] ?? a['created_at']).compareTo(_time(b['sms_at'] ?? b['created_at']));
      if (at != 0) return at;
      final made = _time(a['created_at']).compareTo(_time(b['created_at']));
      return made != 0 ? made : (a['id'] as String).compareTo(b['id'] as String);
    }

    Json latest(Iterable<Json> rows) => rows.reduce((a, b) => when(a, b) >= 0 ? a : b);
    final out = [
      for (final MapEntry(key: name, value: rows) in byAccount.entries)
        (
          last: latest(rows),
          reported: rows.where((t) => t['balance_minor'] != null).isEmpty
              ? null
              : latest(rows.where((t) => t['balance_minor'] != null)),
          name: name,
          count: rows.length,
        ),
    ]..sort((a, b) {
        final byTime = when(b.last, a.last);
        return byTime != 0 ? byTime : a.name.compareTo(b.name);
      });
    return [
      for (final a in out)
        {
          'account': a.name,
          'currency': a.last['currency'],
          'balance_minor': a.reported?['balance_minor'],
          'balance_at': a.reported == null ? null : a.reported!['sms_at'] ?? a.reported!['created_at'],
          'count': a.count,
        },
    ];
  }

  // ---- personal entries in Split (on the device only; no API answer to match) ----

  /// Splits you paid that could be the same spend as entry [txnId]: the same amount and
  /// currency, dated within [windowDays] of it, live in a group you're in, and not linked to
  /// another entry. Closest date first; each as GET /expenses/{id} answers.
  List<Json> linkCandidates(String txnId, {int windowDays = 3}) {
    final t = rawPersonal(txnId) ?? (throw const LocalNotFound('Transaction'));
    final day = DateTime.parse(t['date'] as String);
    int apart(Json e) => DateTime.parse(e['date'] as String).difference(day).inDays.abs();
    final taken = {
      for (final p in _personal)
        if (p['deleted_at'] == null && p['id'] != txnId && p['expense_id'] != null) p['expense_id'],
    };
    final found = [
      for (final e in _expenses.values)
        if (e['deleted_at'] == null &&
            e['payer_id'] == me &&
            e['amount_minor'] == t['amount_minor'] &&
            e['currency'] == t['currency'] &&
            _isMember(e['group_id'] as String, me) &&
            !taken.contains(e['id']) &&
            apart(e) <= windowDays)
          e,
    ]..sort((a, b) {
        final byDay = apart(a).compareTo(apart(b));
        return byDay != 0 ? byDay : _time(b['created_at']).compareTo(_time(a['created_at']));
      });
    return [for (final e in found) expense(e['id'] as String)];
  }

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
    final earlier = [
      for (final t in _personal)
        if (t['merchant'] == merchant && t['deleted_at'] == null && _settlements[t['settlement_id']] != null) t,
    ]..sort((a, b) => _time(b['created_at']).compareTo(_time(a['created_at'])));
    final s = earlier.isEmpty ? null : _settlements[earlier.first['settlement_id']]!;
    return s == null ? null : (s['from_user'] == me ? s['to_user'] : s['from_user']) as String;
  }

  /// The category you chose last for an entry ([scope] "personal") or a split you added
  /// ("group") from the same [merchant] or with the same description as [text], if it's still
  /// offered there (core/categorise). Entries the app added from SMS count once you've looked
  /// at them; [income] keeps income and spending apart.
  String? learnedCategory(String text, {String? merchant, required String scope, bool income = false}) {
    final offered = {for (final c in categories(scope: scope)) c['id']};
    final words = text.trim().toLowerCase();
    final from = merchant?.trim().toLowerCase();
    bool same(Json row) =>
        (from != null && (row['merchant'] as String?)?.toLowerCase() == from) ||
        (words.isNotEmpty && (row['description'] as String).toLowerCase() == words);
    final chosen = [
      if (scope == 'personal')
        for (final t in _personal)
          if (t['deleted_at'] == null && _reviewed(t) && (t['type'] == 'income') == income && same(t)) t
      else
        for (final e in _expenses.values)
          if (e['deleted_at'] == null && e['created_by'] == me && same(e)) e,
    ].where((row) => offered.contains(row['category_id'])).toList()
      ..sort((a, b) => _time(b['created_at']).compareTo(_time(a['created_at'])));
    return chosen.firstOrNull?['category_id'] as String?;
  }

  /// "reference|type" for every entry with a bank reference, deleted ones too: a payment
  /// already here (or removed) whatever message it came from.
  Set<String> personalReferences() => {
    for (final t in _personal)
      if (t['reference'] != null) '${t['reference']}|${t['type']}',
  };

  /// Your newest entry made by hand (live, with no account yet) of [type] and [amountMinor],
  /// dated within a day of [day]: one the bank's SMS is about.
  Json? manualMatch(String type, int amountMinor, DateTime day) {
    final close = [
      for (final t in _personalRows(type: type))
        if (_source(t) == 'manual' &&
            t['account'] == null &&
            t['amount_minor'] == amountMinor &&
            DateTime.parse(t['date'] as String).difference(DateTime(day.year, day.month, day.day)).inDays.abs() <= 1)
          t,
    ];
    return close.isEmpty ? null : _txnOut(close.first);
  }

  /// Your live entry linked to expense [expenseId], as GET /personal/transactions/{id} answers.
  Json? personalLinkedTo(String expenseId) {
    final t = _personal.where((t) => t['expense_id'] == expenseId && t['deleted_at'] == null).firstOrNull;
    return t == null ? null : _txnOut(t);
  }

  // ---- raw entities, for building writes ----

  Json? rawGroup(String id) => _groups[id];
  Json? rawExpense(String id) => _expenses[id];
  Json? rawSettlement(String id) => _settlements[id];
  Json? rawPersonal(String id) => _personal.where((t) => t['id'] == id).firstOrNull;
  Json? rawCategory(String id) => _categories[id];
  List<Json> rawMembers(String groupId) => _members[groupId] ?? const [];
  Json brief(String userId) => _brief(userId);
}

String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime _time(Object? iso) => iso == null ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : DateTime.parse(iso as String);
