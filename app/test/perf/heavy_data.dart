/// A heavy synced dataset for the benchmarks in this folder and the on-device timing test
/// (integration_test/perf_test.dart): roughly what five years of use leaves on a phone. Entities
/// have the shapes the sync engine stores (test/fixtures/sync/john.json's snapshots); the `global`
/// stream and the profile are taken from that fixture as they are (heavy_seed.dart, a copy that
/// works on a phone too), and the rest is generated from one seeded Random, so every run builds the
/// same data.
library;

import 'dart:convert';
import 'dart:math';

import 'package:app/core/categorise/category_guesser.dart';
import 'package:app/core/categorise/category_rules.dart';
import 'package:app/core/local/ledger.dart';
import 'package:app/core/sms/merchant_names.dart';
import 'package:app/core/sms/sms.dart';

import 'heavy_seed.dart';

/// The last day with data (test/flutter_test_config.dart's fixtureDay), and the first.
final heavyEnd = DateTime.utc(2026, 9, 25);
final heavyStart = heavyEnd.subtract(const Duration(days: 5 * 365));

/// The account labels personal entries carry, as the SMS parser writes them.
const heavyAccounts = [
  'HDFC ··4821',
  'HDFC Credit card ··9876',
  'ICICI ··123',
  'ICICI Credit card ··9012',
  'SBI ··4821',
  'Axis ··6677',
];

/// What [buildHeavyData] made, with handles the benchmarks need.
class HeavyData {
  HeavyData._({
    required this.entities,
    required this.me,
    required this.groupIds,
    required this.liveExpenseIds,
    required this.livePersonalIds,
    required this.counts,
    required this.recentManual,
    required this.recentUpi,
  });

  final List<LocalEntity> entities;
  final String me;

  /// Largest group (most expenses) first.
  final List<String> groupIds;
  String get largestGroupId => groupIds.first;
  final List<String> liveExpenseIds;
  final List<String> livePersonalIds;

  /// How many of each thing, for the report.
  final Map<String, int> counts;

  /// Live manual spends from the last six months (amount, date): an SMS about one attaches to it.
  final List<(int, DateTime)> recentManual;

  /// Live SMS spends on HDFC ··4821 from the last six months (reference, amount, date): an SMS
  /// about one is already known.
  final List<(String, int, DateTime)> recentUpi;
}

const _firstNames = [
  'Rahul', 'Priya', 'Aman', 'Kabir', 'Neha', 'Rohan', 'Ananya', 'Vikram', 'Sneha', 'Arjun', //
  'Isha', 'Karan', 'Meera', 'Siddharth', 'Pooja', 'Aditya', 'Divya', 'Nikhil', 'Riya', 'Varun',
];
const _lastNames = [
  'Sharma', 'Verma', 'Mehta', 'Iyer', 'Reddy', 'Nair', 'Gupta', 'Kapoor', 'Rao', 'Joshi', //
  'Menon', 'Bose', 'Pillai', 'Desai', 'Chopra', 'Malhotra',
];

/// Merchants the way banks spell them: brands first (the most used), then local shops and people.
const _brandMerchants = [
  'ZOMATO LIMITED', 'SWIGGY', 'AMAZON PAY IN G', 'ZOMATO', 'SWIGGY INSTAMART', 'UBER INDIA SYSTEMS', //
  'BLINKIT', 'ZEPTO MARKETPLACE', 'AMAZON PAY INDIA PRIVATE LIMITED', 'FLIPKART INTERNET PVT LTD',
  'BIGBASKET', 'DMART', 'AVENUE SUPERMARTS LTD', 'RAPIDO', 'OLA CABS', 'STARBUCKS', 'TATA STARBUCKS PVT',
  'NETFLIX', 'SPOTIFY INDIA', 'AIRTEL', 'BHARTI AIRTEL LTD', 'JIO', 'BESCOM', 'TATA PLAY', 'ACT FIBERNET',
  'IRCTC', 'REDBUS INDIA PR', 'MYNTRA DESIGNS', 'HPCL', 'BPCL PETROL PUMP', 'INDIANOIL', 'FASTAG',
  'APOLLO PHARMACY', 'PHARMEASY', '1MG TECHNOLOGIES', 'CULTFIT', 'DECATHLON SPORTS', 'IKEA INDIA',
  'LENSKART', 'NYKAA E RETAIL', 'CROMA', 'RELIANCE DIGITAL', 'RELIANCE RETAIL', 'MAKEMYTRIP', 'GOIBIBO',
  'INDIGO', 'OYO ROOMS', 'AIRBNB', 'NOBROKER', 'URBAN COMPANY', 'PHONEPE', 'PAYTM', 'CRED', 'ZERODHA',
  'GROWW', 'LIC OF INDIA', 'BLUSMART', 'NAMMA YATRI', 'METRO RAIL', 'BMTC', 'SHOPPERS STOP', 'WESTSIDE',
  'ZARA', 'UNIQLO', 'PANTALOONS', 'JIOMART', 'LICIOUS', 'FRESHTOHOME', 'EATSURE', 'THIRD WAVE COFFEE',
  'TOIT BREWPUB', 'BLUE TOKAI COFFEE', 'CHAAYOS', 'DOMINOS PIZZA', 'MCDONALDS', 'KFC', 'HALDIRAMS',
  'BOOKMYSHOW', 'PVR LTD', 'INOX LEISURE', 'HOTSTAR', 'MEESHO', 'AJIO', 'TATACLIQ', 'APPLE STORE',
];
const _shopFirst = ['SRI', 'NEW', 'OM', 'SHREE', 'ROYAL'];
const _shopMiddle = ['BALAJI', 'GANESH', 'LAKSHMI', 'SAI', 'KRISHNA', 'MURUGAN'];
const _shopLast = ['STORES', 'MEDICALS', 'BAKERY', 'ENTERPRISES', 'TRADERS', 'GENERAL STORE', 'SWEETS'];

const _manualSpends = [
  'Chai', 'Auto to office', 'Vegetables', 'Milk', 'Haircut', 'Gym fee', 'Maid salary', 'Petrol', 'Lunch', //
  'Dinner out', 'Movie', 'Groceries', 'Medicines', 'Electricity bill', 'Water bill', 'Mobile recharge',
  'Cab', 'Metro card', 'Books', 'Gift for Priya', 'Laundry', 'Dry cleaning', 'Snacks', 'Coffee', 'Breakfast',
  'Bus ticket', 'Parking', 'Stationery', 'Shoes', 'Clothes', 'Doctor visit', 'Dentist', 'Internet bill',
  'Fruits', 'Bakery', 'Ice cream', 'Temple donation', 'Tips', 'Courier', 'Phone repair', 'Plumber',
  'Electrician', 'Cooking gas', 'Newspaper', 'Pet food', 'Vet', 'Train ticket', 'Flight to Delhi', 'Hotel',
  'Birthday cake', 'Wedding gift', 'Charity', 'Insurance premium', 'Society maintenance', 'Car wash',
  'Toll', 'Swiggy order', 'Zomato dinner', 'Uber home', 'Amazon order',
];
const _manualIncome = [
  'Freelance project', 'Gift from mom', 'Interest', 'Sold old phone', 'Bonus', 'Dividend', //
  'Rent from tenant',
];
const _groupNames = [
  'Flatmates', 'Goa Trip', 'Office lunch', 'Manali 2022', 'Family', 'College gang', 'Badminton', 'Coorg weekend', //
  'Wedding shopping', 'Book club', 'Road trip', 'Pondicherry', 'Diwali party', 'Trek club', 'Kerala 2023',
  'Startup team', 'Cricket Sundays', 'Rishikesh', 'Housewarming', 'Movie nights', 'Ladakh 2024', 'Gym buddies',
  'Hampi', 'Birthday fund', 'Old flat', 'Sikkim', 'Potluck', 'Jaipur 2025', 'Board games', 'Udaipur',
];
const _groupSpends = [
  'Dinner', 'Groceries', 'Cab to airport', 'Electricity bill', 'Rent', 'Netflix', 'Hotel', 'Train tickets', //
  'Breakfast', 'Drinks', 'Petrol', 'Snacks', 'Movie tickets', 'Wifi', 'Cook salary', 'Water cans', 'Lunch',
  'Museum entry', 'Scooter rent', 'Gas cylinder', 'Cleaning supplies', 'Pizza night', 'Cake', 'Flights',
];

String _two(int n) => n.toString().padLeft(2, '0');
String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _ts(DateTime d) => '${_date(d)}T${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}+00:00';

String _hex4(Random r) => r.nextInt(0x10000).toRadixString(16).padLeft(4, '0');

/// A random UUID-shaped id.
String _uuid(Random r) =>
    '${_hex4(r)}${_hex4(r)}-${_hex4(r)}-4${_hex4(r).substring(1)}-a${_hex4(r).substring(1)}-${_hex4(r)}${_hex4(r)}${_hex4(r)}';

String _digits(Random r, int n) {
  final b = StringBuffer()..write(1 + r.nextInt(9));
  for (var i = 1; i < n; i++) {
    b.write(r.nextInt(10));
  }
  return b.toString();
}

/// A day between [from] and [heavyEnd], at a random time.
DateTime _when(Random r, DateTime from) {
  final days = heavyEnd.difference(from).inDays;
  return from.add(Duration(days: r.nextInt(days + 1), seconds: 6 * 3600 + r.nextInt(16 * 3600)));
}

/// Mostly small amounts, a few large ones (minor units).
int _amount(Random r, {int maxRupees = 15000}) {
  final rupees = 20 + (pow(r.nextDouble(), 3) * maxRupees).round();
  return rupees * 100 + (r.nextInt(4) == 0 ? r.nextInt(100) : 0);
}

/// Skewed towards the front of a list of [n]: the first items are picked far more often.
int _skewed(Random r, int n) => min(n - 1, (pow(r.nextDouble(), 2.2) * n).floor());

Map<String, dynamic> _categoryOut(Map<String, dynamic> c) => {
  'id': c['id'],
  'key': c['key'],
  'label': c['label'],
  'icon': c['icon'],
  'scope': c['scope'],
  'owner_id': c['owner_id'],
};

/// What [buildHeavyData] takes from a sync fixture's `snapshots` ([heavySeedJson] is this, for
/// test/fixtures/sync/john.json): the `global` stream and the user's profile.
Map<String, dynamic> heavySeedOf(Map<String, dynamic> snapshots) {
  final userStream = snapshots.keys.firstWhere((k) => k.startsWith('user:'));
  return {
    'global': {'entities': (snapshots['global'] as Map)['entities']},
    userStream: {
      'entities': [
        for (final e in ((snapshots[userStream] as Map)['entities'] as List).cast<Map<String, dynamic>>())
          if (e['entity'] == 'profile') e,
      ],
    },
  };
}

/// About 30 groups with 5k live expenses and 500 payments, 20k personal entries (mostly from bank
/// SMS) and 300 learned category rules, over the five years up to [heavyEnd].
HeavyData buildHeavyData({int groups = 30, int expenses = 5000, int settlements = 500, int personal = 20000}) {
  final r = Random(42);
  final snapshots = (jsonDecode(heavySeedJson) as Map).cast<String, dynamic>();
  LocalEntity fromFixture(String stream, Map<String, dynamic> e) => LocalEntity(
    stream,
    e['entity'] as String,
    e['entity_id'] as String,
    e['version'] as int?,
    (e['data'] as Map).cast(),
  );

  final entities = <LocalEntity>[
    for (final e in ((snapshots['global'] as Map)['entities'] as List).cast<Map<String, dynamic>>())
      fromFixture('global', e),
  ];
  final userStream = snapshots.keys.firstWhere((k) => k.startsWith('user:'));
  final profileEntity = ((snapshots[userStream] as Map)['entities'] as List).cast<Map<String, dynamic>>().firstWhere(
    (e) => e['entity'] == 'profile',
  );
  final profile = fromFixture(userStream, profileEntity);
  entities.add(profile);
  final me = profile.entityId;
  final myName = profile.data['name'] as String;

  // Categories: the fixture's built-ins plus three of your own.
  final categories = [
    for (final e in entities)
      if (e.entity == 'category') e.data,
  ];
  for (final (i, (key, label)) in [('pets', 'Pets'), ('kids', 'Kids'), ('gifts', 'Gifts')].indexed) {
    final id = _uuid(r);
    final c = {
      'id': id,
      'key': key,
      'label': label,
      'icon': 'other',
      'scope': 'personal',
      'owner_id': me,
      'sort': 200 + i,
    };
    categories.add(c);
    entities.add(LocalEntity(userStream, 'category', id, null, c));
  }
  final groupCategories = [
    for (final c in categories)
      if (c['owner_id'] == null && c['scope'] != 'personal') c,
  ];
  final personalCategories = [
    for (final c in categories)
      if (c['scope'] != 'group') c,
  ];
  final spendCategories = [
    for (final c in personalCategories)
      if (c['key'] != 'income') c,
  ];
  final byKey = {
    for (final c in personalCategories)
      if (c['owner_id'] == null) c['key'] as String: c,
  };
  final incomeCategory = byKey['income']!;

  // People: 120 friends.
  final people = <Map<String, dynamic>>[];
  for (final first in _firstNames) {
    for (final last in _lastNames) {
      if (people.length < 120 && r.nextInt(8) < 3) {
        people.add({'id': _uuid(r), 'name': '$first $last', 'avatar_url': null, 'is_placeholder': false});
      }
    }
  }
  while (people.length < 120) {
    people.add({'id': _uuid(r), 'name': 'Friend ${people.length}', 'avatar_url': null, 'is_placeholder': false});
  }
  final meBrief = {'id': me, 'name': myName, 'avatar_url': null, 'is_placeholder': false};

  // Groups, the largest (by weight) the oldest.
  final weights = [for (var i = 0; i < groups; i++) 1 / pow(i + 1, 0.8)];
  final weightSum = weights.fold<double>(0, (a, b) => a + b);
  final groupIds = <String>[];
  final liveExpenseIds = <String>[];
  final myPaidExpenses = <Map<String, dynamic>>[];
  final mySettlements = <Map<String, dynamic>>[];
  var expenseCount = 0, deletedExpenses = 0, settlementCount = 0, deletedSettlements = 0, memberCount = 0;
  for (var g = 0; g < groups; g++) {
    final id = _uuid(r);
    groupIds.add(id);
    final stream = 'group:$id';
    final created = g == 0 ? heavyStart : heavyStart.add(Duration(days: r.nextInt(4 * 365), hours: 10));
    final memberBriefs = [meBrief];
    final size = 3 + r.nextInt(6);
    while (memberBriefs.length < size) {
      final p = people[r.nextInt(people.length)];
      if (!memberBriefs.contains(p)) memberBriefs.add(p);
    }
    final liveCount = g == groups - 1 ? expenses - expenseCount : (expenses * weights[g] / weightSum).round();
    entities.add(
      LocalEntity(stream, 'group', id, 1, {
        'id': id,
        'name': _groupNames[g % _groupNames.length],
        'icon': ['travel', 'rent', 'food', 'other'][g % 4],
        'currency': 'INR',
        'created_by': me,
        'created_at': _ts(created),
        'archived_at': g > groups - 4 ? _ts(heavyEnd.subtract(const Duration(days: 30))) : null,
        'import_batch_id': null,
        'version': 1,
        'last_activity_at': _ts(heavyEnd),
      }),
    );
    for (final (i, p) in memberBriefs.indexed) {
      memberCount++;
      entities.add(
        LocalEntity(stream, 'member', p['id'] as String, null, {
          'group_id': id,
          'user_id': p['id'],
          'role': i == 0 ? 'owner' : 'member',
          'joined_at': _ts(created.add(Duration(minutes: i))),
          // Now and then someone has left (with a zero balance, in real life).
          'left_at': i == size - 1 && g % 7 == 3 ? _ts(heavyEnd.subtract(const Duration(days: 90))) : null,
          'placeholder_name': null,
          'invite_email': null,
          'import_batch_id': null,
          'user': p,
        }),
      );
    }
    final memberIds = [for (final p in memberBriefs) p['id'] as String];

    // Expenses: the live share of the 5k, plus about 5% deleted.
    final total = liveCount + (liveCount / 20).round();
    for (var n = 0; n < total; n++) {
      final deleted = n >= liveCount;
      final when = _when(r, created);
      final eid = _uuid(r);
      final payer = r.nextInt(10) < 3 ? me : memberIds[r.nextInt(memberIds.length)];
      final amount = _amount(r, maxRupees: 12000);
      final participants = r.nextInt(10) < 7
          ? memberIds
          : ({payer, ...memberIds.where((_) => r.nextBool())}.toList()..sort());
      if (participants.length < 2) participants.add(memberIds.firstWhere((m) => m != payer));
      final share = amount ~/ participants.length;
      var rest = amount - share * participants.length;
      final category = groupCategories[r.nextInt(groupCategories.length)];
      final data = {
        'id': eid,
        'group_id': id,
        'description': _groupSpends[r.nextInt(_groupSpends.length)],
        'amount_minor': amount,
        'currency': 'INR',
        'payer_id': payer,
        'date': _date(when),
        'category_id': category['id'],
        'notes': null,
        'split_method': 'equal',
        'import_batch_id': null,
        'created_by': r.nextInt(10) < 4 ? me : payer,
        'acting_admin_id': null,
        'created_at': _ts(when),
        'updated_at': _ts(when),
        'deleted_at': deleted ? _ts(when.add(const Duration(days: 1))) : null,
        'version': 1,
        'splits': [
          for (final u in participants)
            {'user_id': u, 'share_minor': share + (rest-- > 0 ? 1 : 0), 'input_value': null},
        ],
        'category': _categoryOut(category),
      };
      entities.add(LocalEntity(stream, 'expense', eid, 1, data));
      if (deleted) {
        deletedExpenses++;
      } else {
        expenseCount++;
        liveExpenseIds.add(eid);
        if (payer == me) myPaidExpenses.add(data);
      }
    }

    // Payments between members.
    final payments = g == groups - 1 ? settlements - settlementCount : (settlements * weights[g] / weightSum).round();
    for (var n = 0; n < payments + (payments / 20).round(); n++) {
      final deleted = n >= payments;
      final when = _when(r, created);
      final sid = _uuid(r);
      final from = memberIds[r.nextInt(memberIds.length)];
      var to = memberIds[r.nextInt(memberIds.length)];
      if (to == from) to = memberIds[(memberIds.indexOf(from) + 1) % memberIds.length];
      final data = {
        'id': sid,
        'group_id': id,
        'from_user': from,
        'to_user': to,
        'amount_minor': _amount(r, maxRupees: 8000),
        'currency': 'INR',
        'date': _date(when),
        'method': r.nextBool() ? 'upi' : 'cash',
        'note': null,
        'import_batch_id': null,
        'created_by': from,
        'acting_admin_id': null,
        'created_at': _ts(when),
        'deleted_at': deleted ? _ts(when.add(const Duration(days: 1))) : null,
        'version': 1,
      };
      entities.add(LocalEntity(stream, 'settlement', sid, 1, data));
      if (deleted) {
        deletedSettlements++;
      } else {
        settlementCount++;
        if (from == me || to == me) mySettlements.add(data);
      }
    }
  }
  // Largest group first.
  final expensesPerGroup = <String, int>{};
  for (final e in entities) {
    if (e.entity == 'expense') expensesPerGroup.update(e.data['group_id'] as String, (n) => n + 1, ifAbsent: () => 1);
  }
  groupIds.sort((a, b) => (expensesPerGroup[b] ?? 0).compareTo(expensesPerGroup[a] ?? 0));

  // Merchants: brands, then local shops, then people (paid by UPI).
  final merchants = [..._brandMerchants];
  while (merchants.length < 140) {
    final shop =
        '${_shopFirst[r.nextInt(_shopFirst.length)]} ${_shopMiddle[r.nextInt(_shopMiddle.length)]} ${_shopLast[r.nextInt(_shopLast.length)]}';
    if (!merchants.contains(shop)) merchants.add(shop);
  }
  for (final p in people) {
    if (merchants.length >= 200) break;
    merchants.add((p['name'] as String).toUpperCase());
  }
  final merchantDescription = {for (final m in merchants) m: merchantName(m) ?? 'UPI payment'};
  final payers = [for (final p in people) (p['name'] as String).toUpperCase()];
  final payerDescription = {for (final p in payers) p: merchantName(p) ?? 'Money received'};
  String? categoryOf(String text) {
    var key = keywordCategory(text, fuzzy: false);
    if (key == 'travel') key = 'transport';
    if (key == null) {
      // No keyword: a category picked by hand, or none.
      return r.nextInt(3) == 0 ? null : spendCategories[r.nextInt(spendCategories.length)]['id'] as String;
    }
    return byKey[key]?['id'] as String?;
  }

  final merchantCategory = {for (final m in merchants) m: categoryOf(m)};
  final manualCategory = {
    for (final d in [..._manualSpends, ..._manualIncome]) d: categoryOf(d),
  };

  // Personal entries.
  final livePersonalIds = <String>[];
  final recentManual = <(int, DateTime)>[];
  final recentUpi = <(String, int, DateTime)>[];
  final recentFrom = heavyEnd.subtract(const Duration(days: 182));
  var smsCount = 0, manualCount = 0, incomeCount = 0, linked = 0, deletedPersonal = 0;
  for (var n = 0; n < personal; n++) {
    var when = _when(r, heavyStart);
    final id = _uuid(r);
    String type = 'expense', source = 'sms';
    String? merchant, account, reference, channel, categoryId, expenseId, settlementId;
    int? balance;
    var amount = _amount(r);
    String description;
    if (n < 300 && n < myPaidExpenses.length) {
      // What you paid for a group expense, linked to it.
      final e = myPaidExpenses[n * myPaidExpenses.length ~/ 300];
      expenseId = e['id'] as String;
      amount = e['amount_minor'] as int;
      when = DateTime.parse('${e['date']}T12:00:00Z');
      source = n.isEven ? 'sms' : 'manual';
      description = e['description'] as String;
      linked++;
    } else if (n >= 300 && n < 400 && n - 300 < mySettlements.length) {
      // A payment to or from a friend, linked to it.
      final s = mySettlements[(n - 300) * mySettlements.length ~/ 100];
      settlementId = s['id'] as String;
      amount = s['amount_minor'] as int;
      when = DateTime.parse('${s['date']}T12:00:00Z');
      type = s['from_user'] == me ? 'expense' : 'income';
      source = 'manual';
      description = type == 'expense' ? 'Paid back' : 'Got paid back';
      linked++;
    } else {
      final roll = r.nextInt(100);
      if (roll < 78) {
        // A spend read from a bank SMS.
        merchant = merchants[_skewed(r, merchants.length)];
        description = merchantDescription[merchant]!;
        categoryId = merchantCategory[merchant];
      } else if (roll < 82) {
        type = 'income';
        if (r.nextInt(3) == 0) {
          merchant = 'ACME CORP';
          description = 'Acme Corp';
          amount = (80000 + r.nextInt(40000)) * 100;
        } else {
          merchant = payers[r.nextInt(payers.length)];
          description = payerDescription[merchant]!;
        }
        categoryId = incomeCategory['id'] as String;
      } else if (roll < 97) {
        source = 'manual';
        description = _manualSpends[r.nextInt(_manualSpends.length)];
        categoryId = manualCategory[description];
      } else {
        source = 'manual';
        type = 'income';
        description = _manualIncome[r.nextInt(_manualIncome.length)];
        categoryId = incomeCategory['id'] as String;
      }
    }
    if (source == 'sms') {
      account = heavyAccounts[_skewed(r, heavyAccounts.length)];
      final card = account.contains('card');
      channel = card
          ? 'card'
          : (type == 'income' && merchant == 'ACME CORP' ? 'bank' : (r.nextInt(20) == 0 ? 'atm' : 'upi'));
      if (channel == 'atm') {
        merchant = null;
        description = 'Cash withdrawal';
      }
      if (!card) {
        reference = _digits(r, 12);
        if (r.nextInt(10) < 9) balance = (5000 + r.nextInt(200000)) * 100;
      }
      smsCount++;
    } else {
      channel = const [null, 'cash', 'upi', 'card'][r.nextInt(4)];
      manualCount++;
    }
    if (type == 'income') incomeCount++;
    final deleted = r.nextInt(100) < 3;
    final created = _ts(when);
    entities.add(
      LocalEntity(userStream, 'personal_transaction', id, 1, {
        'id': id,
        'user_id': me,
        'type': type,
        'amount_minor': amount,
        'currency': 'INR',
        'category_id': categoryId,
        'date': _date(when),
        'description': description,
        'notes': null,
        'channel': channel,
        'merchant': merchant,
        'account': account,
        'source': source,
        'reference': reference,
        'balance_minor': balance,
        'sms_at': source == 'sms' ? created : null,
        'reviewed': source == 'manual' || when.isBefore(heavyEnd.subtract(const Duration(days: 2))),
        'expense_id': expenseId,
        'settlement_id': settlementId,
        'acting_admin_id': null,
        'created_at': created,
        'deleted_at': deleted ? _ts(when.add(const Duration(hours: 5))) : null,
        'version': 1,
      }),
    );
    if (deleted) {
      deletedPersonal++;
      continue;
    }
    livePersonalIds.add(id);
    if (!when.isBefore(recentFrom) && type == 'expense' && expenseId == null && settlementId == null) {
      if (source == 'manual') recentManual.add((amount, when));
      if (account == heavyAccounts.first && channel == 'upi') recentUpi.add((reference!, amount, when));
    }
  }

  // Learned category rules: merchants and manual descriptions you picked a category for.
  final patterns = <(bool, String)>{};
  var rules = 0;
  final ruleSources = [
    for (final m in merchants) (m, false),
    for (final d in _manualSpends) (d, false),
    for (final d in _manualIncome) (d, true),
    for (final p in people.take(60)) ((p['name'] as String).toUpperCase(), true),
  ];
  for (final (text, income) in ruleSources) {
    if (rules >= 300) break;
    final pattern = rulePattern(text);
    if (!patterns.add((income, pattern))) continue;
    final id = ruleId(me, income: income, pattern: pattern);
    final category = income ? incomeCategory : spendCategories[r.nextInt(spendCategories.length)];
    entities.add(
      LocalEntity(userStream, 'category_rule', id, null, {
        'id': id,
        'user_id': me,
        'pattern': pattern,
        'income': income,
        'category_id': category['id'],
        'updated_at': _ts(_when(r, heavyStart)),
      }),
    );
    rules++;
  }

  return HeavyData._(
    entities: entities,
    me: me,
    groupIds: groupIds,
    liveExpenseIds: liveExpenseIds,
    livePersonalIds: livePersonalIds,
    recentManual: recentManual,
    recentUpi: recentUpi,
    counts: {
      'entities': entities.length,
      'groups': groups,
      'members': memberCount,
      'friends': people.length,
      'expenses (live)': expenseCount,
      'expenses (deleted)': deletedExpenses,
      'largest group expenses': expensesPerGroup[groupIds.first] ?? 0,
      'settlements (live)': settlementCount,
      'settlements (deleted)': deletedSettlements,
      'personal (all)': personal,
      'personal (deleted)': deletedPersonal,
      'personal from SMS': smsCount,
      'personal manual': manualCount,
      'personal income': incomeCount,
      'personal linked to Split': linked,
      'merchants': merchants.length,
      'category rules': rules,
      'categories': categories.length,
    },
  );
}

// ---- bank SMS ----

/// 1,23,456.78
String _inr(int minor) {
  final rupees = (minor ~/ 100).toString();
  final paise = _two(minor % 100);
  if (rupees.length <= 3) return '$rupees.$paise';
  var rest = rupees.substring(0, rupees.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},${rupees.substring(rupees.length - 3)}.$paise';
}

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

typedef _Msg = ({int amount, String merchant, String person, String vpa, DateTime day, String ref, int balance});

String _ddmmyy(DateTime d, String sep) => '${_two(d.day)}$sep${_two(d.month)}$sep${_two(d.year % 100)}';
String _ddMonyy(DateTime d, String sep) => '${_two(d.day)}$sep${_mon[d.month - 1]}$sep${_two(d.year % 100)}';

/// Spends, in the formats of test/fixtures/sms/corpus.json (HDFC, ICICI, SBI, Axis, Kotak).
final _spendTemplates = <(String, String Function(_Msg))>[
  (
    'VM-HDFCBK-S',
    (m) =>
        'Sent Rs.${_inr(m.amount)}\nFrom HDFC Bank A/C *4821\nTo ${m.merchant}\nOn ${_ddmmyy(m.day, '/')}\nRef ${m.ref}\n'
        'Not You?\nCall 18002586161/SMS BLOCK UPI to 7308080808',
  ),
  (
    'VM-HDFCBK',
    (m) =>
        'Rs.${_inr(m.amount)} debited from a/c **4821 on ${_ddmmyy(m.day, '-')} to VPA ${m.vpa}(UPI Ref No ${m.ref}). '
        'Not you? Call on 18002586161 to report',
  ),
  (
    'VM-HDFCBK-T',
    (m) =>
        'Spent Rs.${_inr(m.amount)} On HDFC Bank Card 5678 At ${m.merchant} On ${_date(m.day)}:19:31:05.Not You? '
        'To Block+Reissue Call 18002323232/SMS BLOCK CC 5678 to 7308080808',
  ),
  (
    'AX-HDFCBK-S',
    (m) =>
        'Rs.${_inr(m.amount)} spent on HDFC Bank Credit Card XX9876 at ${m.merchant} on ${_ddmmyy(m.day, '-')}. '
        'Avl Lmt: Rs.${_inr(m.balance)}. Not you? Call 18002586161',
  ),
  (
    'VM-HDFCBK-S',
    (m) =>
        'Rs.${_inr(m.amount)} debited from HDFC Bank A/c XX4821 on ${_ddmmyy(m.day, '-')} towards ${m.merchant} via '
        'NetBanking. Avl bal Rs.${_inr(m.balance)}',
  ),
  (
    'VM-ICICIB-S',
    (m) =>
        'ICICI Bank Acct XX123 debited for Rs ${_inr(m.amount)} on ${_ddMonyy(m.day, '-')}; ${m.merchant} credited. '
        'UPI:${m.ref}. Call 18002662 for dispute. SMS BLOCK 123 to 9215676766.',
  ),
  (
    'VM-ICICIT-S',
    (m) =>
        'INR ${_inr(m.amount)} spent using ICICI Bank Card XX9012 on ${_ddMonyy(m.day, '-')} on ${m.merchant}. '
        'Avl Limit: INR ${_inr(m.balance)}. If not you, call 1800 2662/SMS BLOCK 9012 to 9215676766',
  ),
  (
    'VM-ICICIT-S',
    (m) =>
        'INR ${_inr(m.amount)} spent on ICICI Bank Debit Card XX4455 on ${_ddMonyy(m.day, '-')} at ${m.merchant}. '
        'Avl Bal: INR ${_inr(m.balance)}.',
  ),
  (
    'VM-ICICIB-S',
    (m) =>
        'Your ICICI Bank Acct XX123 has been debited with INR ${_inr(m.amount)} on ${_ddMonyy(m.day, '-')} for AutoPay '
        'of ${m.merchant}. Avl Bal INR ${_inr(m.balance)}.',
  ),
  (
    'JD-SBIUPI-S',
    (m) =>
        'Dear UPI user A/C X4821 debited by ${m.amount ~/ 100}.${_two(m.amount % 100)} on date ${_ddMonyy(m.day, '')} '
        'trf to ${m.merchant} Refno ${m.ref}. If not u? call 1800111109. -SBI',
  ),
  (
    'VM-SBIINB-S',
    (m) =>
        'Dear Customer, Rs.${_inr(m.amount)} spent on your SBI Debit Card ending 5566 at ${m.merchant} on '
        '${_ddMonyy(m.day, '')}. Avl Bal Rs.${_inr(m.balance)} -SBI',
  ),
  (
    'AD-AXISBK-S',
    (m) =>
        'INR ${_inr(m.amount)} debited from A/c no. XX6677 on ${_two(m.day.day)}-${_two(m.day.month)}-${m.day.year} at '
        '18:22:10 IST. UPI/P2M/${m.ref}/${m.merchant}. Not you? SMS BLOCKUPI to 919951860002 - Axis Bank',
  ),
  (
    'VM-KOTAKB-S',
    (m) =>
        'Sent Rs.${_inr(m.amount)} from Kotak Bank AC X3344 to ${m.vpa} on ${_ddmmyy(m.day, '-')}.UPI Ref ${m.ref}. '
        'Not you, https://kotak.com/KBANKT/Fraud',
  ),
];

/// Money received.
final _incomeTemplates = <(String, String Function(_Msg))>[
  (
    'JD-HDFCBK-S',
    (m) =>
        'Rs.${_inr(m.amount)} credited to HDFC Bank A/c XX4821 on ${_ddmmyy(m.day, '-')} by a/c linked to VPA ${m.vpa} '
        '(UPI Ref No ${m.ref}).',
  ),
  (
    'VM-ICICIB-S',
    (m) =>
        'Dear Customer, Acct XX123 is credited with Rs ${_inr(m.amount)} on ${_ddMonyy(m.day, '-')} from ${m.person}. '
        'UPI:${m.ref}-ICICI Bank.',
  ),
  (
    'VM-HDFCBK-S',
    (m) =>
        'Update! INR ${_inr(m.amount)} deposited in HDFC Bank A/c XX4821 on ${_ddMonyy(m.day, '-').toUpperCase()} for '
        'NEFT Cr-CITI0000001-ACME CORP-JOHN D-CITIN${m.ref}.Avl bal INR ${_inr(m.balance)}. Cheque deposits in A/C '
        'are subject to clearing',
  ),
];

/// Merchants as SMS name them (no words that end a name early or read as a skip, like "refund").
const _smsMerchants = [
  'SWIGGY', 'ZOMATO LIMITED', 'AMAZON PAY IN G', 'BLINKIT', 'ZEPTO MARKETPLACE', 'UBER INDIA SYSTEMS', 'RAPIDO', //
  'BIGBASKET', 'DMART', 'STARBUCKS', 'NETFLIX', 'SPOTIFY INDIA', 'AIRTEL', 'BESCOM', 'TATA PLAY', 'IRCTC',
  'MYNTRA DESIGNS', 'HPCL', 'APOLLO PHARMACY', 'DECATHLON SPORTS', 'IKEA INDIA', 'MAKEMYTRIP', 'INDIGO',
  'URBAN COMPANY', 'CULTFIT', 'LENSKART', 'CROMA', 'SRI BALAJI STORES', 'OM SAI MEDICALS', 'NEW KRISHNA BAKERY',
  'RAHUL SHARMA', 'PRIYA MEHTA', 'TOIT BREWPUB', 'THIRD WAVE COFFEE',
];
const _smsPeople = ['RAHUL SHARMA', 'PRIYA MEHTA', 'KABIR IYER', 'NEHA KAPOOR', 'ARJUN NAIR'];
const _vpas = [
  'zomato.payu@axisbank', 'swiggy.stores@icici', 'jiomobility@hdfcbank', 'starbucks.in@hdfcbank', //
  'rahul.sharma@okaxis', 'priya.m@oksbi', 'bigbasket@ybl', 'uber.rides@paytm', '9876543210@ybl',
  'blinkit.payu@hdfcbank', 'rapido@axl', 'kabir.iyer@okicici',
];

/// [count] bank SMS from the last six months up to [heavyEnd], almost all of them payments
/// parseSms reads. One in ten is about an SMS entry already in [data] (same reference) and one
/// in twenty about a spend you entered by hand (same amount and day), so an import meets both.
List<RawSms> heavySms(HeavyData data, {int count = 2000}) {
  final r = Random(42);
  final from = heavyEnd.subtract(const Duration(days: 182));
  final out = <RawSms>[];
  for (var n = 0; n < count; n++) {
    var day = _when(r, from);
    var amount = _amount(r, maxRupees: 8000);
    var ref = _digits(r, 12);
    var templates = r.nextInt(100) < 8 ? _incomeTemplates : _spendTemplates;
    var template = templates[r.nextInt(templates.length)];
    if (n % 10 == 3 && data.recentUpi.isNotEmpty) {
      // Already here: the same payment, the same reference.
      final (knownRef, knownAmount, knownDay) = data.recentUpi[r.nextInt(data.recentUpi.length)];
      (ref, amount, day) = (knownRef, knownAmount, knownDay);
      template = _spendTemplates.first;
    } else if (n % 20 == 7 && data.recentManual.isNotEmpty) {
      // Entered by hand first.
      final (manualAmount, manualDay) = data.recentManual[r.nextInt(data.recentManual.length)];
      (amount, day) = (manualAmount, manualDay);
      template = _spendTemplates.first;
    }
    final msg = (
      amount: amount,
      merchant: _smsMerchants[_skewed(r, _smsMerchants.length)],
      person: _smsPeople[r.nextInt(_smsPeople.length)],
      vpa: _vpas[r.nextInt(_vpas.length)],
      day: day,
      ref: ref,
      balance: (5000 + r.nextInt(200000)) * 100,
    );
    out.add(
      RawSms(
        address: template.$1,
        body: template.$2(msg),
        // On the phone's clock, a little after the payment.
        receivedAt: DateTime(day.year, day.month, day.day, 9 + r.nextInt(13), r.nextInt(60)),
      ),
    );
  }
  return out;
}
