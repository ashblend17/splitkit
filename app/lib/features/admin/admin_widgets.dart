import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api.dart';
import '../../core/clock.dart';
import '../../core/copy/copy.dart';
import '../../core/layout/layout.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';

// Pieces shared by the admin dashboard, user list and audit log (AdminDashboard, AdminUsers).

/// Scrolling page body with the desktop mockups' 28/32 padding (16 on phones).
class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final compact = SkLayout.of(context) == SkLayout.compact;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: compact ? const EdgeInsets.fromLTRB(16, 12, 16, 32) : const EdgeInsets.fromLTRB(32, 28, 32, 32),
          children: children,
        ),
      ),
    );
  }
}

/// "Admin / Users" over the page title.
class AdminTitle extends StatelessWidget {
  const AdminTitle(this.title, {super.key, this.crumb, this.onCrumb, this.subtitle});
  final String title;
  final String? crumb;
  final VoidCallback? onCrumb;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (crumb != null)
        Semantics(
          label: 'Breadcrumb: $crumb / $title',
          child: ExcludeSemantics(
            child: Row(
              children: [
                InkWell(
                  onTap: onCrumb,
                  child: Text(crumb!, style: SkText.body(13, 600, color: SkColors.brandInk)),
                ),
                Text(' / $title', style: SkText.body(13, 400, color: SkColors.ink2)),
              ],
            ),
          ),
        ),
      if (crumb != null) const SizedBox(height: 4),
      Semantics(header: true, child: Text(title, style: SkText.display(30, 800))),
      if (subtitle != null) ...[const SizedBox(height: 4), subtitle!],
    ],
  );
}

/// 44px white search box with the search glyph.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.controller,
    this.width = 360,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final double width;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width),
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: SkColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SkColors.line),
      ),
      child: Row(
        children: [
          const SkIcon('search', size: 18, color: SkColors.ink2),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: SkText.body(14, 400),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: SkText.body(14, 400, color: SkColors.ink3),
              ).copyWith(semanticCounterText: ''),
            ),
          ),
        ],
      ),
    ),
  );
}

/// White card with a heading row, used for the dashboard and audit sections.
class AdminSection extends StatelessWidget {
  const AdminSection({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SkCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SkColors.line))),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(header: true, child: Text(title, style: SkText.display(18, 700))),
              ?trailing,
            ],
          ),
        ),
        child,
      ],
    ),
  );
}

/// The "Done as" chip. Words carry the meaning; the amber repeats "Admin".
class DoneAsChip extends StatelessWidget {
  const DoneAsChip(this.entry, {super.key});
  final AuditEntryOut entry;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, border) = switch (entry.doneAs) {
      AuditEntryOutDoneAsEnum.admin => ('Admin', SkColors.adminBand, SkColors.adminInk, SkColors.adminInk),
      AuditEntryOutDoneAsEnum.system => (
        entry.entity == 'import_batch' ? 'Import' : 'System',
        SkColors.brandSoft,
        SkColors.brandInk,
        SkColors.brandSoft,
      ),
      _ => ('User', SkColors.sunken, SkColors.ink2, SkColors.sunken),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SkRadius.chip),
        border: Border.all(color: border),
      ),
      child: Text(label, style: SkText.body(12, 700, color: fg)),
    );
  }
}

/// "Today 9:42 PM", "Yesterday", "Mon 21 Sep" (the mockup's When column).
String auditWhen(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final day = dayLabel(local, now: now);
  if (day == 'Today') return 'Today ${timeLabel(at)}';
  if (day == 'Yesterday') return day;
  return DateFormat('EEE d MMM').format(local);
}

/// "Ansh C → Priya" when an admin acted as someone; "Tricount importer" for the system.
String auditWho(AuditEntryOut e) {
  if (e.actor == null) return e.entity == 'import_batch' ? 'Tricount importer' : 'System';
  final as = e.actingAs;
  return as == null ? e.actor!.name : '${e.actor!.name} → ${firstName(as.name)}';
}

/// Last active in the users table: "9:42 PM" today, "Mon" this week, else "21 Sep".
String lastActiveLabel(DateTime? at, {DateTime? now}) {
  if (at == null) return 'Never';
  final local = at.toLocal();
  final today = now ?? appClock.now();
  final days = DateTime(today.year, today.month, today.day).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days <= 0) return timeLabel(at);
  if (days < 7) return DateFormat('EEE').format(local);
  return DateFormat('d MMM').format(local);
}

/// Net balance in words: "owed ₹1,470", "owes ₹850", "settled up". Several currencies
/// are joined with " · ".
String netLabel(List<MoneyTotal> balances) {
  if (balances.isEmpty) return 'settled up';
  return balances
      .map((b) => b.amountMinor > 0 ? 'owed ${money(b.amountMinor, b.currency)}' : 'owes ${money(-b.amountMinor, b.currency)}')
      .join(' · ');
}

Color netColor(List<MoneyTotal> balances) =>
    balances.length == 1 ? textColorFor(balances.single.amountMinor) : SkColors.ink2;

enum _Col { when, who, what, where, doneAs }

/// The recent-activity / audit table: When, Who, What happened, Where, Done as. Under 640px
/// each entry becomes a two-line row.
class AuditTable extends StatelessWidget {
  const AuditTable({super.key, required this.entries, this.now});

  final List<AuditEntryOut> entries;
  final DateTime? now;

  static const _gap = 12.0;

  double _width(_Col c) => switch (c) {
    _Col.when => 110,
    _Col.who => 170,
    _Col.where => 130,
    _Col.doneAs => 80,
    _Col.what => 0,
  };

  Widget _cells(List<_Col> cols, Widget Function(_Col) cell) => Row(
    children: [
      for (final (i, c) in cols.indexed) ...[
        if (i > 0) const SizedBox(width: _gap),
        c == _Col.what ? Expanded(child: cell(c)) : SizedBox(width: _width(c), child: cell(c)),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EmptyState(glyph: 'shield', title: 'Nothing here yet', body: 'Changes show up here as people make them.'),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 640) return Column(children: [for (final e in entries) _compactRow(e)]);
        final cols = [
          _Col.when,
          _Col.who,
          _Col.what,
          if (box.maxWidth >= 760) _Col.where,
          _Col.doneAs,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: SkPalette.tableHead,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: _cells(
                cols,
                (c) => Text(
                  switch (c) {
                    _Col.when => 'WHEN',
                    _Col.who => 'WHO',
                    _Col.what => 'WHAT HAPPENED',
                    _Col.where => 'WHERE',
                    _Col.doneAs => 'DONE AS',
                  },
                  style: SkText.body(12, 700, color: SkColors.ink2, letterSpacing: 12 * 0.05),
                ),
              ),
            ),
            for (final e in entries)
              Semantics(
                container: true,
                label: _label(e),
                child: ExcludeSemantics(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: SkPalette.divider))),
                    alignment: Alignment.centerLeft,
                    child: _cells(
                      cols,
                      (c) => switch (c) {
                        _Col.when => Text(auditWhen(e.at, now: now), style: SkText.body(14, 400, color: SkColors.ink2)),
                        _Col.who => Text(
                          auditWho(e),
                          style: SkText.body(14, 600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        _Col.what => Text(e.summary, style: SkText.body(14, 400), maxLines: 1, overflow: TextOverflow.ellipsis),
                        _Col.where => Text(
                          e.group?.name ?? '—',
                          style: SkText.body(14, 400, color: SkColors.ink2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        _Col.doneAs => Align(alignment: Alignment.centerLeft, child: DoneAsChip(e)),
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _label(AuditEntryOut e) =>
      '${auditWhen(e.at, now: now)}. ${auditWho(e)}. ${e.summary}${e.group == null ? '' : '. In ${e.group!.name}'}'
      '${e.doneAs == AuditEntryOutDoneAsEnum.admin ? '. Done by an admin' : ''}';

  Widget _compactRow(AuditEntryOut e) => Semantics(
    container: true,
    label: _label(e),
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: SkPalette.divider))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.summary, style: SkText.body(14, 600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    [auditWho(e), ?e.group?.name, auditWhen(e.at, now: now)].join(' · '),
                    style: SkText.body(12, 400, color: SkColors.ink2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DoneAsChip(e),
          ],
        ),
      ),
    ),
  );
}
