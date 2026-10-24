import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/data/providers.dart';
import 'package:app/core/local/ledger.dart';
import 'package:app/core/local/providers.dart';
import 'package:app/core/local/store.dart';
import 'package:app/core/local/writes.dart';

import '../fake_backend.dart';

/// A ledger with no data and these revisions (personal, groups, categories, profile, layouts).
Ledger _at(List<int> counts) => Ledger(const [], revisions: LedgerRevisions(1, counts));

void main() {
  group('localOn', () {
    late StreamController<Ledger> ledgers;
    late ProviderContainer container;
    late int builds;
    final probe = FutureProvider((ref) => localOn(ref, groupViews, (l) => ++builds));

    setUp(() {
      builds = 0;
      ledgers = StreamController<Ledger>();
      container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWith((ref) => ledgers.stream),
          // No store: views read the ledger the stream gives.
          localStoreProvider.overrideWith((ref) => Completer<LocalStore>().future),
        ],
      );
      addTearDown(container.dispose);
      container.listen(probe, (_, _) {});
    });

    test('waits for the data, and works the view out once when it comes', () async {
      await pumpEventQueue();
      expect(builds, 0);
      expect(container.read(probe).isLoading, isTrue);
      ledgers.add(_at([0, 0, 0, 0, 0]));
      await pumpEventQueue();
      expect((builds, container.read(probe).value), (1, 1));
    });

    test('is worked out again only when a part it reads changes', () async {
      ledgers.add(_at([0, 0, 0, 0, 0]));
      await pumpEventQueue();
      ledgers.add(_at([0, 0, 0, 0, 0])); // reloaded, nothing new
      ledgers.add(_at([3, 0, 2, 0, 1])); // personal, categories and layouts changed
      await pumpEventQueue();
      expect(builds, 1);
      ledgers.add(_at([3, 1, 2, 0, 1])); // groups
      await pumpEventQueue();
      expect(builds, 2);
      ledgers.add(_at([3, 1, 2, 1, 1])); // profile
      await pumpEventQueue();
      expect((builds, container.read(probe).value), (3, 3));
    });

    test('fails when the data does, and recovers when it comes', () async {
      ledgers.addError(StateError('no database'));
      await pumpEventQueue();
      expect(container.read(probe).error, isA<StateError>());
      ledgers.add(_at([0, 0, 0, 0, 0]));
      await pumpEventQueue();
      expect((builds, container.read(probe).value), (1, 1));
    });
  });

  testWidgets("a personal write doesn't redo Home's views, nor a group write Personal's accounts", (tester) async {
    final be = await pumpApp(tester, location: '/home');
    be.offline = true; // the writes stay on this device: only they change the data
    final container = appContainer(tester);
    final heard = <String, int>{};
    void count(String name, ProviderListenable<Object?> provider) =>
        container.listen(provider, (_, _) => heard[name] = (heard[name] ?? 0) + 1);
    count('balances', overallBalancesProvider);
    count('groups', groupsProvider);
    count('feed', feedProvider((groupId: null, deleted: false, limit: feedPage)));
    count('group categories', groupCategoriesProvider);
    count('personal list', personalListProvider(const PersonalQuery()));
    count('accounts', personalAccountsProvider);
    await tester.pumpAndSettle();
    expect(container.read(personalAccountsProvider).hasValue, isTrue);

    heard.clear();
    await runWrite(
      tester,
      container
          .read(writesProvider)
          .createPersonal(
            PersonalTxnIn(
              type: PersonalTxnInTypeEnum.expense,
              amountMinor: 900,
              description: 'Chai',
              date: DateTime.utc(2026, 9, 25),
              source_: PersonalTxnInSource_Enum.manual,
            ),
          ),
    );
    expect(heard.keys.toSet(), {'personal list', 'accounts'});
    expect(container.read(personalListProvider(const PersonalQuery())).value!.items.first.description, 'Chai');

    heard.clear();
    await runWrite(tester, container.read(writesProvider).setGroupArchived(be.goa['id'] as String, true));
    // Personal entries can be linked to splits, so the list reads groups too.
    expect(heard.keys.toSet(), {'balances', 'groups', 'feed', 'personal list'});
    expect(container.read(groupsProvider).value!.map((g) => g.name), isNot(contains('Goa Trip')));
  });
}
