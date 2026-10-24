import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/money/money.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'import_flow.dart';
import 'widgets.dart';

/// Screen 19: pick a Tricount export and where it goes, then see what was found.
class ImportUploadPage extends ConsumerStatefulWidget {
  const ImportUploadPage({super.key});

  @override
  ConsumerState<ImportUploadPage> createState() => _ImportUploadPageState();
}

class _ImportUploadPageState extends ConsumerState<ImportUploadPage> {
  late final _name = TextEditingController(text: ref.read(importFlowProvider).target.name);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(importFlowProvider);
    ref.listen(importFlowProvider.select((d) => d.preview?.groupName), (_, name) {
      if (name != null && _name.text.trim().isEmpty) _name.text = name;
    });
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_upload(draft), const SizedBox(height: 16), _target(draft)],
    );
    final right = _found(draft);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ContentWidth(
              maxWidth: wide ? 1100 : 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ImportHeader(
                    crumb: 'Profile / Import',
                    title: 'Import from Tricount',
                    subtitle: 'A one-time move of your groups and expenses. Nothing is saved until you press Import.',
                    backLabel: 'Back to profile',
                    onBack: () => context.go('/profile'),
                  ),
                  const SizedBox(height: 16),
                  const ImportSteps(current: 1),
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: left),
                        const SizedBox(width: 20),
                        Expanded(flex: 5, child: right),
                      ],
                    )
                  else ...[
                    left,
                    const SizedBox(height: 16),
                    right,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upload(ImportDraft draft) {
    final flow = ref.read(importFlowProvider.notifier);
    final file = draft.file;
    return SkCard(
      radius: 18,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: SkPalette.brandWash,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SkPalette.brandTint, width: 2),
            ),
            child: Column(
              children: [
                IconTile(
                  'upload',
                  background: SkColors.brandSoft,
                  foreground: SkColors.brand,
                  size: 56,
                  radius: 16,
                  iconSize: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  'Upload your Tricount export',
                  textAlign: TextAlign.center,
                  style: SkText.display(20, 700),
                ),
                const SizedBox(height: 6),
                Text(
                  'CSV or XLSX · In Tricount: open the tricount → Settings → Export',
                  textAlign: TextAlign.center,
                  style: SkText.body(14, 400, color: SkColors.ink2),
                ),
                const SizedBox(height: 14),
                SkButton(
                  file == null ? 'Choose file' : 'Choose another file',
                  variant: SkButtonVariant.secondary,
                  onPressed: draft.loading ? null : flow.pick,
                ),
              ],
            ),
          ),
          if (file != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: SkColors.paper, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const SkIcon('file', size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file.name, overflow: TextOverflow.ellipsis, style: SkText.body(14, 700)),
                        Text(
                          [
                            file.sizeLabel,
                            if (draft.preview != null) plural(draft.preview!.rows.length, 'row'),
                          ].join(' · '),
                          style: SkText.body(12, 400, color: SkColors.ink2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (draft.loading)
                    Text('Reading…', style: SkText.body(13, 600, color: SkColors.ink2))
                  else if (draft.preview != null)
                    Row(
                      children: [
                        SkIcon('check', size: 16, color: SkColors.owed),
                        const SizedBox(width: 4),
                        Text('Read', style: SkText.body(13, 700, color: SkColors.owed)),
                      ],
                    ),
                  HeaderIconButton(glyph: 'close', label: 'Remove file', color: SkColors.ink2, onPressed: flow.removeFile),
                ],
              ),
            ),
          ],
          if (draft.error != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkIcon('alert', size: 18, color: SkColors.owe),
                const SizedBox(width: 8),
                Expanded(child: Text(draft.error!, style: SkText.body(14, 600, color: SkColors.oweInk))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _target(ImportDraft draft) {
    final flow = ref.read(importFlowProvider.notifier);
    final groups = ref.watch(groupsProvider).value ?? const <GroupOut>[];
    final target = draft.target;
    final currency = target.currency ?? draft.preview?.currency ?? 'INR';
    return SkCard(
      radius: 18,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Overline('Import into'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SelectableChip(
                label: 'A new group',
                selected: target.isNew,
                onTap: () => flow.setTarget(ImportTarget.newGroup(name: _name.text, currency: target.currency)),
              ),
              for (final g in groups.where((g) => g.archivedAt == null))
                SelectableChip(
                  label: g.name,
                  selected: target.groupId == g.id,
                  onTap: () => flow.setTarget(ImportTarget.group(g.id)),
                ),
            ],
          ),
          if (target.isNew) ...[
            const SizedBox(height: 14),
            SkTextField(label: 'Group name', controller: _name, hint: 'Goa Trip', onChanged: flow.renameGroup),
            const SizedBox(height: 12),
            Text('Currency', style: SkText.body(13, 600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final c in supportedCurrencies.keys)
                  SelectableChip(
                    label: '$c ${currencySymbol(c)}',
                    selected: currency == c,
                    onTap: () => flow.setTarget(ImportTarget.newGroup(name: _name.text, currency: c)),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'People are matched with this group’s members. Anyone new joins it.',
              style: SkText.body(13, 400, color: SkColors.ink2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _found(ImportDraft draft) {
    final p = draft.preview;
    if (p == null) {
      return SkCard(
        radius: 18,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text('What we found', style: SkText.display(20, 700))),
            const SizedBox(height: 8),
            Text(
              draft.loading ? 'Reading your file…' : 'Choose a file to see its people, expenses and totals here.',
              style: SkText.body(14, 400, color: SkColors.ink2),
            ),
          ],
        ),
      );
    }
    final t = p.totals;
    final matched = p.people.where((x) => draft.people[x.name] != null).length;
    final unmatched = p.people.where((x) => draft.people[x.name] == null).map((x) => '“${x.name}”').toList();
    final unmatchedRows = draft.importable
        .where((r) => [r.payer, ...r.shares.map((s) => s.name)].any((n) => n != null && draft.people[n] == null))
        .length;
    final odd = p.categories.where((c) => c.key == null).toList();
    final oddRows = odd.fold<int>(0, (n, c) => n + c.rows);
    final range = dateRangeLabel(t.firstDate, t.lastDate);
    final targetName = draft.target.isNew
        ? draft.groupName
        : (ref.watch(groupsProvider).value ?? const <GroupOut>[])
                  .where((g) => g.id == draft.target.groupId)
                  .firstOrNull
                  ?.name ??
              '';
    final issues = [
      if (unmatched.isNotEmpty)
        ImportNotice(
          label: '${plural(unmatchedRows, 'expense')} with an unmatched person',
          detail: unmatched.join(', '),
          tone: NoticeTone.warn,
        ),
      if (odd.isNotEmpty)
        ImportNotice(
          label: '${plural(oddRows, 'expense')} with unsupported categories',
          detail: odd.map((c) => c.name).join(', '),
          tone: NoticeTone.warn,
        ),
      if (t.skipped > 0)
        ImportNotice(
          label: '${plural(t.skipped, 'row')} can’t be imported',
          detail: 'Listed in the review',
          tone: NoticeTone.warn,
        ),
    ];
    return SkCard(
      radius: 18,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text('What we found', style: SkText.display(20, 700))),
          const SizedBox(height: 14),
          ImportNotice(
            label: draft.target.isNew ? '1 group found' : 'Adding to a group',
            detail: targetName,
            tone: NoticeTone.good,
          ),
          const SizedBox(height: 8),
          ImportNotice(
            label: '${plural(p.people.length, 'person', 'people')} found',
            detail: '$matched match existing users',
            tone: NoticeTone.good,
          ),
          const SizedBox(height: 8),
          ImportNotice(
            label: '${plural(t.expenses, 'expense')} found',
            detail: [money(t.expenseTotalMinor, p.currency), if (range.isNotEmpty) range].join(' · '),
            tone: NoticeTone.good,
          ),
          if (t.transfers > 0) ...[
            const SizedBox(height: 8),
            ImportNotice(
              label: '${plural(t.transfers, 'money transfer')} found',
              detail: '${money(t.transferTotalMinor, p.currency)} · imported as payments',
              tone: NoticeTone.good,
            ),
          ],
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Overline('Needs a look'),
            const SizedBox(height: 8),
            for (final (i, w) in issues.indexed) ...[if (i > 0) const SizedBox(height: 8), w],
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SkButton(
                  'Review',
                  expand: true,
                  onPressed: draft.loading ? null : () => context.go('/profile/import/review'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SkButton(
                  _busy ? 'Importing…' : 'Import anyway',
                  variant: SkButtonVariant.secondary,
                  expand: true,
                  onPressed: _busy || draft.loading || draft.importable.isEmpty ? null : _importNow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Everything imported is tagged with one batch, so it can be undone in one step.',
            style: SkText.body(12, 400, color: SkColors.ink2),
          ),
        ],
      ),
    );
  }

  Future<void> _importNow() async {
    setState(() => _busy = true);
    await commitImport(context, ref);
    if (mounted) setState(() => _busy = false);
  }
}

/// Commits the draft, refreshes everything derived from the ledger and opens the Done screen.
/// On failure shows the API's message and stays put.
Future<void> commitImport(BuildContext context, WidgetRef ref) async {
  try {
    final batch = await ref.read(importFlowProvider.notifier).commit();
    refreshLedger(ref.invalidate);
    if (context.mounted) context.go('/profile/import/done/${batch.id}');
  } catch (e) {
    if (context.mounted) showMessage(context, apiErrorMessage(e));
  }
}
