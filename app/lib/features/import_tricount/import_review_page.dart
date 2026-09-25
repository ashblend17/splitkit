import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'import_flow.dart';
import 'import_upload_page.dart' show commitImport;
import 'widgets.dart';

const _placeholder = '_placeholder';

/// Screen 20: match people and categories, see the rows that need a look, then import.
class ImportReviewPage extends ConsumerStatefulWidget {
  const ImportReviewPage({super.key});

  @override
  ConsumerState<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends ConsumerState<ImportReviewPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(importFlowProvider);
    final p = draft.preview;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    if (p == null) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            glyph: 'upload',
            title: 'Choose a file first',
            body: 'Pick your Tricount export, then come back here to check it.',
            actionLabel: 'Choose file',
            onAction: () => context.go('/profile/import'),
          ),
        ),
      );
    }
    final ready = draft.importable;
    final groupName = draft.target.isNew
        ? draft.groupName
        : (ref.watch(groupsProvider).value ?? const <GroupOut>[])
                  .where((g) => g.id == draft.target.groupId)
                  .firstOrNull
                  ?.name ??
              'the group';
    final people = _people(draft, p);
    final categories = _categories(draft, p);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  ContentWidth(
                    maxWidth: wide ? 1100 : 640,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ImportHeader(
                          crumb: 'Import from Tricount / Review',
                          title: 'Check before importing',
                          subtitle: [
                            draft.file?.name ?? p.fileName,
                            groupName,
                            plural(p.totals.expenses, 'expense'),
                            money(p.totals.expenseTotalMinor, p.currency),
                          ].join(' · '),
                          backLabel: 'Back to upload',
                          onBack: () => context.go('/profile/import'),
                        ),
                        const SizedBox(height: 16),
                        const ImportSteps(current: 3),
                        const SizedBox(height: 16),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: people),
                              const SizedBox(width: 16),
                              Expanded(child: categories),
                            ],
                          )
                        else ...[
                          people,
                          const SizedBox(height: 16),
                          categories,
                        ],
                        const SizedBox(height: 16),
                        _flagged(draft, p, wide),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _footer(draft, p, ready.length, groupName),
          ],
        ),
      ),
    );
  }

  Widget _people(ImportDraft draft, ImportPreviewOut p) {
    final flow = ref.read(importFlowProvider.notifier);
    final meId = ref.watch(meProvider).id;
    final matched = p.people.where((x) => draft.people[x.name] != null).length;
    final options = [
      for (final c in p.candidates) (c.id, c.id == meId ? '${c.name} (you)' : c.name),
      (_placeholder, 'Create placeholder member'),
    ];
    return ImportSection(
      title: 'People',
      trailing: '$matched of ${p.people.length} matched',
      children: [
        for (final x in p.people)
          _row(
            label: x.name,
            trailing: _personState(x, draft.people[x.name]),
            warn: draft.people[x.name] == null,
            select: ImportSelect(
              label: 'Match ${x.name}',
              value: draft.people[x.name] ?? _placeholder,
              items: options,
              warn: draft.people[x.name] == null,
              onChanged: (v) => flow.mapPerson(x.name, v == _placeholder ? null : v),
            ),
          ),
      ],
    );
  }

  Widget _personState(PersonOut x, String? chosen) {
    if (chosen == null) {
      return StatusChip(
        x.match == PersonOutMatchEnum.unmatched ? 'Unmatched · new placeholder' : 'New placeholder',
        tone: StatusTone.pending,
      );
    }
    if (chosen != x.user?.id) return const StatusChip('Chosen', tone: StatusTone.owedToYou);
    return switch (x.match) {
      PersonOutMatchEnum.you => const StatusChip('You', tone: StatusTone.owedToYou),
      PersonOutMatchEnum.matched => const StatusChip('Matched', tone: StatusTone.owedToYou),
      _ => const StatusChip('Suggested', tone: StatusTone.group),
    };
  }

  Widget _categories(ImportDraft draft, ImportPreviewOut p) {
    final flow = ref.read(importFlowProvider.notifier);
    final options = [for (final o in p.categoryOptions) (o.key, o.label)];
    bool needsChoice(CategoryMatchOut c) => c.key == null && draft.categories[c.name] == 'other';
    final open = p.categories.where(needsChoice).length;
    return ImportSection(
      title: 'Categories',
      trailing: p.categories.isEmpty
          ? 'None in this file'
          : open == 0
          ? 'All matched'
          : '$open need a choice',
      children: [
        for (final c in p.categories)
          _row(
            label: c.name,
            trailing: Text(plural(c.rows, 'expense'), style: SkText.body(13, 500, color: SkColors.ink2)),
            warn: needsChoice(c),
            select: ImportSelect(
              label: 'Category for ${c.name}',
              value: draft.categories[c.name] ?? 'other',
              items: options,
              warn: needsChoice(c),
              onChanged: (v) => flow.mapCategory(c.name, v),
            ),
          ),
      ],
    );
  }

  Widget _row({required String label, required Widget trailing, required bool warn, required Widget select}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: warn ? SkPalette.importWarnWash : SkColors.surface,
        border: const Border(bottom: BorderSide(color: SkPalette.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: SkText.body(14, 600))),
              const SizedBox(width: 8),
              Flexible(child: trailing),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SkIcon('next', size: 16, color: SkColors.ink3),
              const SizedBox(width: 8),
              Expanded(child: select),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flagged(ImportDraft draft, ImportPreviewOut p, bool wide) {
    final flagged = [
      for (final r in p.rows)
        if (draft.flags(r).isNotEmpty) (r, draft.flags(r)),
    ];
    final ready = p.rows.length - flagged.length;
    return ImportSection(
      title: 'Expenses with issues',
      trailing: flagged.isEmpty ? 'All ${p.rows.length} are ready' : '${flagged.length} of ${p.rows.length} · the other $ready are ready',
      children: [
        if (flagged.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Nothing to check. Every row imports as it is.', style: SkText.body(14, 400, color: SkColors.ink2)),
          ),
        for (final (r, flags) in flagged)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SkPalette.divider))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        r.date == null ? '—' : '${r.date!.day} ${shortMonth(r.date!)}',
                        style: SkText.body(14, 400, color: SkColors.ink2),
                      ),
                    ),
                    Expanded(child: Text(r.title, overflow: TextOverflow.ellipsis, style: SkText.body(14, 600))),
                    if (wide)
                      SizedBox(
                        width: 150,
                        child: Text(r.payer ?? '', style: SkText.body(14, 400, color: SkColors.ink2)),
                      ),
                    Text(money(r.amountMinor, r.currency), style: SkText.display(14, 700)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 56),
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: SkIcon('alert', size: 16, color: SkColors.pending),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [if (!wide && r.payer != null) 'Paid by ${r.payer}', ...flags].join(' · '),
                        style: SkText.body(13, 600, color: SkPalette.pendingInk),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _footer(ImportDraft draft, ImportPreviewOut p, int ready, String groupName) {
    final placeholders = p.people.where((x) => draft.people[x.name] == null).map((x) => x.name).toList();
    final expenses = p.totals.expenses;
    final summary = StringBuffer(
      draft.target.isNew
          ? 'Creates $groupName with ${plural(p.people.length, 'member')}, ${plural(expenses, 'expense')} and their splits'
          : 'Adds ${plural(expenses, 'expense')} and their splits to $groupName',
    );
    if (p.totals.transfers > 0) summary.write(', plus ${plural(p.totals.transfers, 'payment')}');
    summary.write('.');
    if (placeholders.isNotEmpty) {
      summary.write(' ${plural(placeholders.length, 'placeholder member')} for ${placeholders.join(', ')}.');
    }
    if (p.totals.skipped > 0) summary.write(' ${plural(p.totals.skipped, 'row')} skipped.');
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final back = SkButton('Back', variant: SkButtonVariant.secondary, onPressed: () => context.go('/profile/import'));
    Widget primary({bool expand = false}) => SkButton(
      _busy ? 'Importing…' : 'Import ${plural(expenses, 'expense')}',
      expand: expand,
      onPressed: _busy || ready == 0 ? null : _import,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: SkColors.surface,
        border: Border(top: BorderSide(color: SkColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: wide
            ? Row(
                children: [
                  Expanded(child: Text(summary.toString(), style: SkText.body(14, 400, color: SkColors.ink2))),
                  const SizedBox(width: 12),
                  back,
                  const SizedBox(width: 10),
                  primary(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(summary.toString(), style: SkText.body(13, 400, color: SkColors.ink2)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      back,
                      const SizedBox(width: 10),
                      Expanded(child: primary(expand: true)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    await commitImport(context, ref);
    if (mounted) setState(() => _busy = false);
  }
}
