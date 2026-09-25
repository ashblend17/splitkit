import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

/// Group payment: [from] pays [to] inside [group]. [balanceMinor] is what [from] owes [to]
/// there right now (0 if nothing), which drives "Full balance" and the status line.
class GroupPaymentTarget {
  const GroupPaymentTarget({
    required this.group,
    required this.from,
    required this.to,
    required this.balanceMinor,
    this.members = const [],
  });
  final GroupOut group;
  final UserBrief from;
  final UserBrief to;
  final int balanceMinor;

  /// People the other side can be switched to, with your pairwise balance (+ = they owe you).
  final List<PersonBalance> members;
}

/// "Record a payment" for one group.
Future<void> showGroupPaymentSheet(BuildContext context, GroupPaymentTarget target) =>
    _show(context, _PaymentSheet(group: target));

/// "Settle up with Aman": one payment across every group you share, saved as one settlement
/// per group so each group's balance stays right.
Future<void> showFriendSettleUpSheet(BuildContext context, UserBrief friend) =>
    _show(context, _PaymentSheet(friend: friend));

Future<void> _show(BuildContext context, Widget sheet) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => sheet,
);

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({this.group, this.friend});
  final GroupPaymentTarget? group;
  final UserBrief? friend;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late GroupPaymentTarget? _target = widget.group;
  int? _amountMinor;
  bool _full = true;
  bool _initialised = false;
  String _method = 'upi';
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setFull(int full, String currency) {
    _full = true;
    _amountMinor = full;
    _amount.text = full == 0 ? '' : formatMinor(full, currency: currency).substring(currencySymbol(currency).length);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    if (widget.friend != null) {
      final plan = ref.watch(settleUpPlanProvider(widget.friend!.id));
      return _frame(
        title: 'Settle up with ${firstName(widget.friend!.name)}',
        child: AsyncBody(
          value: plan,
          onRetry: () => ref.invalidate(settleUpPlanProvider(widget.friend!.id)),
          skeletonRows: 2,
          builder: (p) {
            final youPay = p.netMinor < 0;
            final full = p.netMinor.abs();
            if (!_initialised) {
              _initialised = true;
              _setFull(full, p.currency);
            }
            final from = youPay ? _meBrief(me) : p.friend;
            final to = youPay ? p.friend : _meBrief(me);
            return _form(me: me, from: from, to: to, fullMinor: full, currency: p.currency, friendPlan: p);
          },
        ),
      );
    }

    final t = _target!;
    if (!_initialised) {
      _initialised = true;
      _setFull(t.balanceMinor, t.group.currency);
    }
    return _frame(
      title: 'Record a payment',
      child: _form(me: me, from: t.from, to: t.to, fullMinor: t.balanceMinor, currency: t.group.currency),
    );
  }

  UserBrief _meBrief(UserOut me) => UserBrief(id: me.id, name: me.name, avatarUrl: me.avatarUrl);

  Widget _frame({required String title, required Widget child}) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.94),
        decoration: const BoxDecoration(
          color: SkColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(SkRadius.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            child: ContentWidth(
              maxWidth: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: SkColors.lineStrong,
                        borderRadius: BorderRadius.circular(SkRadius.chip),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(header: true, child: Text(title, style: SkText.display(22, 700))),
                      ),
                      Transform.translate(
                        offset: const Offset(10, 0),
                        child: HeaderIconButton(
                          glyph: 'close',
                          label: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form({
    required UserOut me,
    required UserBrief from,
    required UserBrief to,
    required int fullMinor,
    required String currency,
    SettleUpPlanOut? friendPlan,
  }) {
    final amount = _amountMinor ?? 0;
    final remaining = fullMinor - amount;
    final overLimit = friendPlan != null && amount > fullMinor;
    final status = _status(me.id, from, to, fullMinor, remaining, currency);
    final canSubmit =
        !_busy && !overLimit && (amount > 0 || (friendPlan != null && fullMinor == 0 && friendPlan.groups.isNotEmpty));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _people(me.id, from, to),
        const SizedBox(height: 18),
        AmountInput(
          controller: _amount,
          currency: currency,
          symbolSize: 30,
          fontSize: 52,
          showCurrencyChip: false,
          onChanged: (m) => setState(() {
            _amountMinor = m;
            _full = m == fullMinor;
          }),
        ),
        if (fullMinor > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              _chip(
                'Full balance ${money(fullMinor, currency)}',
                _full,
                () => setState(() => _setFull(fullMinor, currency)),
              ),
              _chip(
                'Part payment',
                !_full,
                () => setState(() {
                  _full = false;
                  _amountMinor = null;
                  _amount.clear();
                }),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Text('Paid with (optional)', style: SkText.body(14, 600)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (i, m) in const [
              ('cash', 'Cash'),
              ('upi', 'UPI'),
              ('bank', 'Bank'),
              ('other', 'Other'),
            ].indexed) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: _methodButton(m.$1, m.$2))],
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _dateButton()),
            const SizedBox(width: 8),
            Expanded(child: _noteField()),
          ],
        ),
        const SizedBox(height: 18),
        _statusLine(status, overLimit ? 'That\'s more than the balance between you' : null),
        if (friendPlan != null && friendPlan.groups.length > 1) ...[
          const SizedBox(height: 8),
          Text(_breakdown(friendPlan, amount, currency), style: SkText.body(12, 500, color: SkColors.ink2)),
        ],
        const SizedBox(height: 18),
        SkButton(
          amount == 0 ? 'Mark all square' : 'Record ${money(amount, currency)} payment',
          onPressed: canSubmit ? () => _submit(from: from, to: to, fullMinor: fullMinor, friendPlan: friendPlan) : null,
          size: SkButtonSize.large,
          expand: true,
        ),
        const SizedBox(height: 12),
        Text(
          'Saved as its own record. Original expenses stay unchanged.',
          textAlign: TextAlign.center,
          style: SkText.body(12, 400, color: SkColors.ink2),
        ),
      ],
    );
  }

  /// "You pays → Rahul receives" card. In group mode the other person can be switched.
  Widget _people(String meId, UserBrief from, UserBrief to) {
    Widget side(UserBrief u, String role, {VoidCallback? onTap}) => Semantics(
      button: onTap != null,
      label: '${displayName(u, meId)} $role',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ExcludeSemantics(
          child: SizedBox(
            width: 96,
            child: Column(
              children: [
                Avatar(personOf(u), size: 52, fontSize: 17),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(displayName(u, meId), style: SkText.body(14, 700), overflow: TextOverflow.ellipsis),
                    ),
                    if (onTap != null) ...[const SizedBox(width: 2), const SkIcon('down', size: 14)],
                  ],
                ),
                const SizedBox(height: 6),
                Text(role, style: SkText.body(12, 400, color: SkColors.ink2)),
              ],
            ),
          ),
        ),
      ),
    );
    final t = _target;
    final canSwitch = t != null && t.members.isNotEmpty;
    VoidCallback? pick(bool pickingFrom) =>
        canSwitch && (pickingFrom ? from.id != meId : to.id != meId) ? () => _pickOther(pickingFrom) : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: SkColors.paper, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          side(from, 'pays', onTap: pick(true)),
          const Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(height: 2, child: ColoredBox(color: SkPalette.brandTint)),
                ),
                SkIcon('next', size: 22, color: SkColors.brand),
              ],
            ),
          ),
          side(to, 'receives', onTap: pick(false)),
        ],
      ),
    );
  }

  Future<void> _pickOther(bool pickingFrom) async {
    final t = _target!;
    final me = ref.read(meProvider);
    final current = pickingFrom ? t.from : t.to;
    final chosen = await showAppBottomSheet<PersonBalance>(
      context,
      title: pickingFrom ? 'Who paid?' : 'Who received it?',
      child: Column(
        children: [
          for (final p in t.members)
            SheetPersonOption(
              person: personOf(p.user),
              selected: p.user.id == current.id,
              onTap: () => Navigator.of(context).pop(p),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    final meBrief = _meBrief(me);
    // Balance between you and the chosen person: + means they owe you.
    final owed = chosen.netMinor;
    setState(() {
      _target = GroupPaymentTarget(
        group: t.group,
        members: t.members,
        from: pickingFrom ? chosen.user : meBrief,
        to: pickingFrom ? meBrief : chosen.user,
        balanceMinor: pickingFrom ? (owed > 0 ? owed : 0) : (owed < 0 ? -owed : 0),
      );
      _setFull(_target!.balanceMinor, t.group.currency);
    });
  }

  ({String text, MoneyTone tone}) _status(
    String meId,
    UserBrief from,
    UserBrief to,
    int full,
    int remaining,
    String c,
  ) {
    final fromName = displayName(from, meId);
    final toName = displayName(to, meId);
    final other = from.id == meId
        ? firstName(to.name)
        : to.id == meId
        ? firstName(from.name)
        : null;
    if (remaining == 0) {
      return (
        text: other != null
            ? 'After this, you and $other are all square.'
            : 'After this, $fromName and $toName are all square.',
        tone: MoneyTone.owed,
      );
    }
    if (full == 0 && other == null) return (text: '$fromName pays $toName.', tone: MoneyTone.neutral);
    final r = money(remaining.abs(), c);
    if (remaining > 0) {
      final text = from.id == meId
          ? "You'll still owe $toName $r."
          : to.id == meId
          ? '$fromName will still owe you $r.'
          : '$fromName will still owe $toName $r.';
      return (text: text, tone: MoneyTone.neutral);
    }
    final text = from.id == meId
        ? '$toName will owe you $r.'
        : to.id == meId
        ? "You'll owe $fromName $r."
        : '$toName will owe $fromName $r.';
    return (text: text, tone: MoneyTone.neutral);
  }

  Widget _statusLine(({String text, MoneyTone tone}) status, String? error) {
    final (bg, fg, glyph) = error != null
        ? (SkColors.oweSoft, SkColors.oweInk, 'alert')
        : status.tone == MoneyTone.owed
        ? (SkColors.owedSoft, SkColors.owedInk, 'check')
        : (SkColors.pendingSoft, SkColors.pending, 'alert');
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            SkIcon(glyph, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(error ?? status.text, style: SkText.body(14, 600, color: fg)),
            ),
          ],
        ),
      ),
    );
  }

  /// Which groups the payment is recorded in, mirroring the API's settle-up rules.
  String _breakdown(SettleUpPlanOut p, int amount, String c) {
    final full = amount == p.netMinor.abs();
    final lines = <String>[];
    if (full) {
      for (final g in p.groups) {
        lines.add('${g.name} ${money(g.netMinor.abs(), c)}');
      }
      return 'Recorded in ${p.groups.length} groups: ${lines.join(' · ')}';
    }
    var left = amount;
    final towardsYou = p.netMinor > 0;
    for (final g in p.groups) {
      if ((g.netMinor > 0) != towardsYou || left <= 0) continue;
      final pay = left < g.netMinor.abs() ? left : g.netMinor.abs();
      lines.add('${g.name} ${money(pay, c)}');
      left -= pay;
    }
    return lines.isEmpty ? '' : 'Pays down the oldest group first: ${lines.join(' · ')}';
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Semantics(
    button: true,
    selected: on,
    child: Material(
      color: on ? SkColors.brandSoft : SkColors.surface,
      shape: StadiumBorder(side: BorderSide(color: on ? SkColors.brand : SkColors.line, width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: SkText.body(13, on ? 700 : 600, color: on ? SkColors.brandInk : SkColors.ink)),
          ),
        ),
      ),
    ),
  );

  Widget _methodButton(String key, String label) {
    final on = _method == key;
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? SkColors.brandSoft : SkColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: on ? SkColors.brand : SkColors.line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _method = key),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(label, style: SkText.body(13, on ? 700 : 600, color: on ? SkColors.brandInk : SkColors.ink)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateButton() => Material(
    color: SkColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: SkColors.line, width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const SkIcon('calendar', size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(dayLabel(_date), style: SkText.body(14, 600), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _noteField() => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: SkColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: SkColors.line, width: 1.5),
    ),
    alignment: Alignment.centerLeft,
    child: TextField(
      controller: _note,
      style: SkText.body(14, 400),
      decoration: InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: 'Add a note',
        hintStyle: SkText.body(14, 400, color: SkColors.ink3),
      ),
    ),
  );

  Future<void> _submit({
    required UserBrief from,
    required UserBrief to,
    required int fullMinor,
    SettleUpPlanOut? friendPlan,
  }) async {
    setState(() => _busy = true);
    final api = ref.read(apiProvider);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final amount = _amountMinor ?? 0;
    try {
      final List<String> createdIds;
      if (friendPlan != null) {
        final out = await api.settlements.settleUp(
          widget.friend!.id,
          SettleUpIn(
            amountMinor: amount == fullMinor ? null : amount,
            date: apiDate(_date),
            method: SettleUpInMethodEnum.fromJson(_method)!,
            note: note,
            currency: friendPlan.currency,
          ),
        );
        createdIds = [for (final s in out!.settlements) s.id];
      } else {
        final out = await api.settlements.createSettlement(
          _target!.group.id,
          SettlementIn(
            fromUser: from.id,
            toUser: to.id,
            amountMinor: amount,
            date: apiDate(_date),
            method: SettlementInMethodEnum.fromJson(_method)!,
            note: note,
          ),
        );
        createdIds = [out!.id];
      }
      refreshLedger(ref.invalidate);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      // The sheet is gone by the time Undo is tapped, so use the container, not `ref`.
      final container = ProviderScope.containerOf(context, listen: false);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              createdIds.length > 1 ? 'Payment recorded in ${createdIds.length} groups' : 'Payment recorded',
            ),
            action: SnackBarAction(
              label: 'Undo',
              textColor: SkColors.brandSoft,
              onPressed: () async {
                for (final id in createdIds) {
                  await api.settlements.deleteSettlement(id);
                }
                refreshLedger(container.invalidate);
              },
            ),
          ),
        );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }
}
