/// What part of the synced data a change touches, so a screen that reads only some of it isn't
/// worked out again for changes elsewhere (core/data/providers.dart `localOn`). The store counts
/// changes per domain (store.dart) and each Ledger carries the counts it was built from.
library;

/// The parts the data on this device falls into.
enum LedgerDomain { personal, groups, categories, profile, layouts }

/// Synced entities of Personal. Each new personal entity (accounts, goals, rules, plans,
/// holdings, reminder states…) goes in this list.
const personalEntities = {
  'personal_transaction',
  'personal_account',
  'personal_goal',
  'personal_goal_contribution',
  'personal_allocation_rule',
  'personal_allocation_plan',
  'personal_holding',
  'personal_reminder_state',
  'personal_reminder_schedule',
};

/// Synced entities of the groups you're in, and your memberships.
const groupEntities = {'group', 'member', 'membership', 'expense', 'settlement'};

/// Categories and the rules learned from your choices.
const categoryEntities = {'category', 'category_rule'};

/// The domains a change to [entity] touches. An entity not listed touches every domain, so a
/// new one is never missed, only worked out more often than it needs to be.
Set<LedgerDomain> domainsOf(String entity) {
  if (personalEntities.contains(entity)) return const {LedgerDomain.personal};
  if (groupEntities.contains(entity)) return const {LedgerDomain.groups};
  if (categoryEntities.contains(entity)) return const {LedgerDomain.categories};
  return switch (entity) {
    'profile' => const {LedgerDomain.profile},
    'layout' => const {LedgerDomain.layouts},
    _ => LedgerDomain.values.toSet(),
  };
}

/// How many changes each domain has had in one store, as of one Ledger.
class LedgerRevisions {
  LedgerRevisions(this.store, List<int> counts) : _counts = List.unmodifiable(counts);

  const LedgerRevisions._none() : store = 0, _counts = const [0, 0, 0, 0, 0];

  /// A Ledger built outside a store (tests).
  static const none = LedgerRevisions._none();

  /// Which store counted them: two stores (two people signed in, one after the other) never
  /// give equal revisions.
  final int store;
  final List<int> _counts;

  int operator [](LedgerDomain domain) => _counts[domain.index];

  int get personal => this[LedgerDomain.personal];
  int get groups => this[LedgerDomain.groups];
  int get categories => this[LedgerDomain.categories];
  int get profile => this[LedgerDomain.profile];
  int get layouts => this[LedgerDomain.layouts];

  /// A value that changes exactly when one of [domains] has changed, or the store has: what a
  /// view that reads only those watches.
  Object of(Set<LedgerDomain> domains) {
    int at(LedgerDomain d) => domains.contains(d) ? this[d] : -1;
    return (
      store,
      at(LedgerDomain.personal),
      at(LedgerDomain.groups),
      at(LedgerDomain.categories),
      at(LedgerDomain.profile),
      at(LedgerDomain.layouts),
    );
  }

  @override
  String toString() =>
      'LedgerRevisions(store $store, personal $personal, groups $groups, categories $categories, profile $profile, '
      'layouts $layouts)';
}
