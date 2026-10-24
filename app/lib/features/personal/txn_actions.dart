import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/integrations.dart';
import '../../core/local/ledger.dart' show PersonalLink;
import '../../core/local/writes.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../settlements/settlement_sheet.dart';
import 'personal_txn_sheet.dart';

/// A personal entry in Split: what it became there (a split or a payment, with Open and
/// Unlink), or the ways to make it something there. Which ways are offered is up to
/// core/integrations.dart; with none on, this shows nothing.
class TxnInSplit extends ConsumerWidget {
  const TxnInSplit({super.key, required this.txn});
  final PersonalTxnOut txn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(personalLinkProvider(txn.id)).value;
    if (link != null) return _Linked(txn: txn, link: link);
    final actions = txnActions(context, ref, txn);
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('In Split', style: SkText.body(14, 600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}

/// What [txn] can become among your own money, as the features allow: "Track this cash" for a
/// cash withdrawal on one of your accounts (it becomes a transfer into Cash), "This was a
/// transfer" when a suggested pair has it, "Record a refund" for a spend, and "This was a
/// refund" for money in from a merchant you spent at (refundSuggestionProvider). [likely] (the
/// short list on "Just in", which shows suggested pairs itself) keeps to Track this cash. [leave]
/// is called when the entry is about to change into something else, so a sheet showing it can
/// close.
List<Widget> entryActions(
  BuildContext context,
  WidgetRef ref,
  PersonalTxnOut txn, {
  bool likely = false,
  VoidCallback? leave,
}) {
  final features = ref.watch(featuresProvider);
  final spend = txn.type == PersonalTxnOutTypeEnum.expense;
  final linked = txn.expenseId != null || txn.settlementId != null;
  final cash =
      features.accounts &&
      features.atmToCash &&
      spend &&
      txn.channel?.value == 'atm' &&
      txn.accountId != null &&
      !linked;
  final pair = likely || linked
      ? null
      : (ref.watch(transferSuggestionsProvider).value ?? const <TransferSuggestion>[])
            .where((p) => p.outflow.id == txn.id || p.inflow.id == txn.id)
            .firstOrNull;
  final refundOf = likely || pair != null || txn.type != PersonalTxnOutTypeEnum.income
      ? null
      : ref.watch(refundSuggestionProvider(txn.id)).value;
  return [
    if (cash)
      SkButton(
        'Track this cash',
        icon: 'wallet',
        size: SkButtonSize.small,
        variant: SkButtonVariant.secondary,
        onPressed: () => _run(context, ref, () => ref.read(writesProvider).trackCash(txn.id), then: leave),
      ),
    if (pair != null)
      SkButton(
        'This was a transfer',
        icon: 'swap',
        size: SkButtonSize.small,
        variant: SkButtonVariant.secondary,
        onPressed: () => _run(
          context,
          ref,
          () => ref.read(writesProvider).pairAsTransfer(pair.outflow.id, pair.inflow.id),
          then: leave,
        ),
      ),
    if (refundOf != null)
      Semantics(
        hint: 'Of ${refundOf.description}, ${dayLabel(DateTime.parse(refundOf.date))}',
        child: SkButton(
          'This was a refund',
          icon: 'refresh',
          size: SkButtonSize.small,
          variant: SkButtonVariant.secondary,
          onPressed: () => _run(
            context,
            ref,
            () => ref.read(writesProvider).markAsRefund(txn.id, refundOf.id),
            then: () {
              leave?.call();
              if (context.mounted) {
                showMessage(context, 'Now a refund of ${refundOf.description}');
              }
            },
          ),
        ),
      ),
    if (spend && features.refunds && !likely)
      SkButton(
        'Record a refund',
        icon: 'refresh',
        size: SkButtonSize.small,
        variant: SkButtonVariant.secondary,
        onPressed: () {
          // The sheet this may be in closes first; the refund's opens over the screen.
          final screen = Navigator.of(context, rootNavigator: true).context;
          leave?.call();
          showPersonalTxnSheet(screen, type: 'refund', refundOf: txn);
        },
      ),
  ];
}

/// [entryActions] in a row, or nothing when there are none.
class EntryActions extends ConsumerWidget {
  const EntryActions({super.key, required this.txn, this.leave});
  final PersonalTxnOut txn;
  final VoidCallback? leave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = entryActions(context, ref, txn, leave: leave);
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }
}

/// The buttons that turn [txn] into something in Split, as the integrations allow: "Split it"
/// and "Already split" for a spend, "Paid a friend" / "From a friend" for a payment. Only a spend
/// or an income can be one. [likely] keeps the friend button to when the bank's text names one
/// (the short list on "Just in").
List<Widget> txnActions(BuildContext context, WidgetRef ref, PersonalTxnOut txn, {bool likely = false}) {
  final on = ref.watch(integrationsProvider);
  final spend = txn.type == PersonalTxnOutTypeEnum.expense;
  if (!spend && txn.type != PersonalTxnOutTypeEnum.income) return const [];
  final candidates = spend && on.linkToExistingSplit
      ? ref.watch(linkCandidatesProvider(txn.id)).value ?? const <ExpenseOut>[]
      : const <ExpenseOut>[];
  final friends = on.paymentFromTransaction ? _friendsFor(ref, txn, likely: likely) : const <FriendBalance>[];
  return [
    if (spend && on.splitFromTransaction)
      SkButton(
        'Split it',
        icon: 'groups',
        size: SkButtonSize.small,
        onPressed: () => context.push('/expenses/new?from_txn=${txn.id}'),
      ),
    if (candidates.isNotEmpty)
      SkButton(
        'Already split',
        size: SkButtonSize.small,
        variant: SkButtonVariant.secondary,
        onPressed: () => _pickSplit(context, ref, txn, candidates),
      ),
    if (friends.isNotEmpty)
      SkButton(
        spend ? 'Paid a friend' : 'From a friend',
        size: SkButtonSize.small,
        variant: SkButtonVariant.secondary,
        onPressed: () => _pickFriend(context, ref, txn, friends),
      ),
  ];
}

/// Friends a payment like this could be to (or from): ones you owe for a spend, ones who owe
/// you for income, in the entry's currency. Likely ones first: who it went to last time, then
/// anyone whose name the bank's text has.
List<FriendBalance> _friendsFor(WidgetRef ref, PersonalTxnOut txn, {bool likely = false}) {
  final spend = txn.type == PersonalTxnOutTypeEnum.expense;
  final all = [
    for (final f in ref.watch(overallBalancesProvider).value?.friends ?? const <FriendBalance>[])
      if (f.currency == txn.currency && (spend ? f.netMinor < 0 : f.netMinor > 0)) f,
  ];
  final before = txn.merchant == null ? null : ref.watch(friendPaidBeforeProvider(txn.merchant!)).value;
  final words = _words('${txn.merchant ?? ''} ${txn.description}');
  int rank(FriendBalance f) => f.user.id == before
      ? 0
      : _words(f.user.name).any(words.contains)
      ? 1
      : 2;
  all.sort((a, b) => rank(a).compareTo(rank(b)));
  return likely && (all.isEmpty || rank(all.first) == 2) ? const [] : all;
}

Set<String> _words(String text) => {
  for (final w in text.toLowerCase().split(RegExp('[^a-z]+')))
    if (w.length >= 3) w,
};

Future<void> _pickSplit(BuildContext context, WidgetRef ref, PersonalTxnOut txn, List<ExpenseOut> candidates) async {
  final groups = {for (final g in ref.read(groupsProvider).value ?? const <GroupOut>[]) g.id: g.name};
  final picked = await showAppBottomSheet<String>(
    context,
    title: 'Which split was it?',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Linked, it's counted once: your share, in Split.",
          style: SkText.body(13, 400, color: SkColors.ink2),
        ),
        const SizedBox(height: 8),
        for (final e in candidates)
          Builder(
            builder: (sheet) => InkWell(
              onTap: () => Navigator.of(sheet).pop(e.id),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.description, style: SkText.body(15, 600)),
                          Text(
                            '${groups[e.groupId] ?? 'A group'} · ${dayLabel(e.date)}',
                            style: SkText.body(13, 400, color: SkColors.ink2),
                          ),
                        ],
                      ),
                    ),
                    Text(money(e.amountMinor, e.currency), style: SkText.body(15, 700)),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  await _run(context, ref, () => ref.read(writesProvider).linkPersonal(txn.id, expenseId: picked));
}

Future<void> _pickFriend(BuildContext context, WidgetRef ref, PersonalTxnOut txn, List<FriendBalance> friends) async {
  final spend = txn.type == PersonalTxnOutTypeEnum.expense;
  final picked = await showAppBottomSheet<FriendBalance>(
    context,
    title: spend ? 'Who did you pay?' : 'Who paid you?',
    child: Column(
      children: [
        for (final f in friends)
          Builder(
            builder: (sheet) => SheetPersonOption(
              person: SkPerson(id: f.user.id, name: f.user.name, initials: initialsFor(f.user.name)),
              label: '${f.user.name} · ${spend ? 'you owe' : 'owes you'} ${money(f.netMinor.abs(), f.currency)}',
              selected: false,
              onTap: () => Navigator.of(sheet).pop(f),
            ),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  final writes = ref.read(writesProvider);
  await showFriendSettleUpSheet(
    context,
    picked.user,
    currency: picked.currency,
    from: PaymentFrom(
      amountMinor: txn.amountMinor,
      date: txn.date,
      method: switch (txn.channel?.value) {
        'upi' || 'bank' || 'cash' => txn.channel!.value,
        _ => 'other',
      },
      // A settle-up across groups makes one payment per group; the entry links the first.
      onSaved: (ids) => writes.linkPersonal(txn.id, settlementId: ids.first),
    ),
  );
}

/// Runs [write], then [then] (when it went through).
Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() write, {VoidCallback? then}) async {
  try {
    await write();
    refreshPersonal(ref.invalidate);
    then?.call();
  } catch (e) {
    if (context.mounted) showMessage(context, apiErrorMessage(e));
  }
}

/// "Split in Goa Trip": what the entry became, whether it still counts here, and a way out.
class _Linked extends ConsumerWidget {
  const _Linked({required this.txn, required this.link});
  final PersonalTxnOut txn;
  final PersonalLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spend = txn.type == PersonalTxnOutTypeEnum.expense;
    final where = link.group == null ? '' : ' in ${link.group}';
    final title = link.payment
        ? '${spend ? 'Paid' : 'From'} ${link.person == null ? 'a friend' : firstName(link.person!)}$where'
        : 'Split$where';
    final body = switch ((link.live, link.payment)) {
      (true, true) => "Not counted here: a payment isn't spending.",
      (true, false) => 'Not counted here: your share counts, as group spending.',
      (false, true) => 'That payment was deleted, so this counts here again.',
      (false, false) => 'That split was deleted (or you left the group), so this counts here again.',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: SkColors.brandSoft, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: SkText.body(15, 700, color: SkColors.brandInk)),
          const SizedBox(height: 2),
          Text(body, style: SkText.body(13, 400, color: SkColors.ink2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!link.payment && link.live)
                SkButton(
                  'Open split',
                  size: SkButtonSize.small,
                  variant: SkButtonVariant.secondary,
                  onPressed: () => context.push('/expenses/${link.id}'),
                ),
              SkButton(
                'Unlink',
                size: SkButtonSize.small,
                variant: SkButtonVariant.ghost,
                onPressed: () => _run(context, ref, () => ref.read(writesProvider).linkPersonal(txn.id)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
