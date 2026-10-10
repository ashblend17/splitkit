import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/data/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'tricount_conflicts.dart';
import 'tricount_providers.dart';

/// "Sync with Tricount" for one group: link a tricount (or make one), then see how the sync
/// is going. The sync itself runs on the server (api/app/modules/tricount_sync).
class TricountSyncPage extends ConsumerStatefulWidget {
  const TricountSyncPage({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<TricountSyncPage> createState() => _TricountSyncPageState();
}

class _TricountSyncPageState extends ConsumerState<TricountSyncPage> {
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// While the first pass runs, look again every couple of seconds.
  void _pollWhileSyncing(TricountStatusOut s) {
    _poll?.cancel();
    if (s.link?.state == TricountLinkOutStateEnum.syncing) {
      _poll = Timer(const Duration(seconds: 2), () => ref.invalidate(tricountStatusProvider(widget.groupId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(tricountStatusProvider(widget.groupId));
    final group = ref.watch(groupProvider(widget.groupId)).value;
    ref.listen(tricountStatusProvider(widget.groupId), (previous, next) {
      if (!next.hasValue) return;
      _pollWhileSyncing(next.requireValue);
      // The first pass is done: fetch what it brought in, so the group shows it now.
      final was = previous?.value?.link?.state;
      if (was == TricountLinkOutStateEnum.syncing && next.requireValue.link?.state != was) {
        refreshLedger(ref.invalidate);
      }
    });
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: HeaderIconButton(
                            glyph: 'back',
                            label: 'Back to group',
                            onPressed: () => context.go('/groups/${widget.groupId}'),
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text('Sync with Tricount', style: SkText.display(20, 700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  AsyncBody(
                    value: status,
                    onRetry: () => ref.invalidate(tricountStatusProvider(widget.groupId)),
                    builder: (s) => s.linked && s.link != null
                        ? _Linked(link: s.link!, groupId: widget.groupId)
                        : _NotLinked(group: group, groupId: widget.groupId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- linked ----

class _Linked extends ConsumerStatefulWidget {
  const _Linked({required this.link, required this.groupId});
  final TricountLinkOut link;
  final String groupId;

  @override
  ConsumerState<_Linked> createState() => _LinkedState();
}

class _LinkedState extends ConsumerState<_Linked> {
  bool _busy = false;

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).tricount.syncTricount(widget.groupId);
      refreshLedger(ref.invalidate);
    } catch (e) {
      if (mounted) showMessage(context, apiErrorMessage(e));
    }
    ref.invalidate(tricountStatusProvider(widget.groupId));
    ref.invalidate(tricountConflictsProvider);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _unlink() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Stop syncing with Tricount?',
      body: "Nothing is deleted in either app. Changes just stop going across. You can link it again later.",
      confirmLabel: 'Stop syncing',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(apiProvider).tricount.unlinkTricount(widget.groupId);
      ref.invalidate(tricountStatusProvider(widget.groupId));
      ref.invalidate(tricountConflictsProvider);
      if (mounted) showMessage(context, 'No longer syncing with Tricount');
    } catch (e) {
      if (mounted) showMessage(context, apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.link;
    final (tone, label, detail) = switch (l.state) {
      TricountLinkOutStateEnum.syncing => (
        StatusTone.pending,
        'Syncing',
        'Bringing the two apps together. This takes a moment the first time.',
      ),
      TricountLinkOutStateEnum.error => (
        StatusTone.youOwe,
        'Not syncing',
        _withRetry(l.lastError ?? 'The last sync failed.'),
      ),
      _ => (
        StatusTone.settled,
        'In sync',
        l.lastSyncedAt == null ? 'Changes go across within a minute.' : 'Last synced ${agoLabel(l.lastSyncedAt!)}. Changes go across within a minute.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile('swap', background: SkColors.brandSoft, foreground: SkColors.brandInk),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Tricount', style: SkText.body(16, 700))),
                  StatusChip(label, tone: tone),
                ],
              ),
              const SizedBox(height: 10),
              Text(detail, style: SkText.body(14, 400, color: SkColors.ink2, height: 1.45)),
              const SizedBox(height: 12),
              _ShareLink(link: l.shareLink),
              const SizedBox(height: 12),
              SkButton(
                _busy ? 'Syncing…' : 'Sync now',
                icon: 'refresh',
                variant: SkButtonVariant.secondary,
                expand: true,
                onPressed: _busy ? null : _syncNow,
              ),
            ],
          ),
        ),
        if (l.conflicts.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Overline('Changed in both apps'),
          const SizedBox(height: 8),
          for (final c in l.conflicts) ...[TricountConflictCard(conflict: c), const SizedBox(height: 10)],
        ],
        if (l.warnings.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Overline('Not carried over'),
          const SizedBox(height: 8),
          for (final w in l.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: SkIcon('alert', size: 16, color: SkColors.pending)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(w, style: SkText.body(14, 400, color: SkColors.ink2, height: 1.4))),
                ],
              ),
            ),
        ],
        const SizedBox(height: 20),
        Text(
          'Linked by ${l.linkedBy.name}. Anyone in the group can see this, and anyone with the Tricount link can change the tricount.',
          style: SkText.body(12, 400, color: SkColors.ink3, height: 1.4),
        ),
        const SizedBox(height: 12),
        SkButton('Stop syncing', variant: SkButtonVariant.ghost, expand: true, onPressed: _unlink),
      ],
    );
  }
}

/// The server's message, plus that it retries, unless the message says so already.
String _withRetry(String message) => message.contains('again') ? message : '$message It tries again by itself.';

class _ShareLink extends StatelessWidget {
  const _ShareLink({required this.link});
  final String link;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(link, style: SkText.body(13, 500, color: SkColors.ink2), maxLines: 1),
          ),
          SkButton(
            'Copy',
            variant: SkButtonVariant.ghost,
            size: SkButtonSize.small,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              showMessage(context, 'Tricount link copied');
            },
          ),
        ],
      ),
    );
  }
}

// ---- not linked yet ----

class _NotLinked extends ConsumerStatefulWidget {
  const _NotLinked({required this.group, required this.groupId});
  final GroupOut? group;
  final String groupId;

  @override
  ConsumerState<_NotLinked> createState() => _NotLinkedState();
}

const _newPerson = '';

class _NotLinkedState extends ConsumerState<_NotLinked> {
  final _link = TextEditingController();
  TricountLinkPreviewOut? _preview;
  final _people = <String, String>{};
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_link.text.trim().isEmpty) {
      setState(() => _error = 'Paste the link from Tricount (Share → Copy link)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await ref
          .read(apiProvider)
          .tricount
          .previewTricountLink(widget.groupId, TricountLinkPreviewIn(link: _link.text.trim()));
      setState(() {
        _preview = p;
        _people
          ..clear()
          ..addAll({for (final x in p!.people) x.memberUuid: x.suggested?.id ?? _newPerson});
      });
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start({required bool create}) async {
    final chosen = _people.values.where((v) => v != _newPerson).toList();
    if (chosen.toSet().length != chosen.length) {
      setState(() => _error = 'Two Tricount people are matched to the same person. Pick someone else for one of them.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).tricount.linkTricount(
            widget.groupId,
            create
                ? TricountLinkIn(create: true)
                : TricountLinkIn(
                    link: _link.text.trim(),
                    people: [
                      for (final e in _people.entries)
                        TricountPersonIn(memberUuid: e.key, userId: e.value == _newPerson ? null : e.value),
                    ],
                  ),
          );
      refreshLedger(ref.invalidate);
      ref.invalidate(tricountStatusProvider(widget.groupId));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Keep this group and a tricount the same: expenses and payments added, changed or deleted in either app show up in the other.',
          style: SkText.body(14, 400, color: SkColors.ink2, height: 1.45),
        ),
        const SizedBox(height: 16),
        if (p == null) ...[
          SkTextField(
            label: 'Tricount link',
            hint: 'https://tricount.com/t…',
            controller: _link,
            keyboardType: TextInputType.url,
            errorText: _error,
            onSubmitted: (_) => _check(),
          ),
          const SizedBox(height: 12),
          SkButton(_busy ? 'Checking…' : 'Continue', expand: true, size: SkButtonSize.large, onPressed: _busy ? null : _check),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: SkText.body(13, 500, color: SkColors.ink3)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          SkButton(
            'Make a new tricount from this group',
            variant: SkButtonVariant.secondary,
            expand: true,
            onPressed: _busy ? null : () => _start(create: true),
          ),
          const SizedBox(height: 8),
          Text(
            "Then share its link with people who use Tricount.",
            style: SkText.body(12, 400, color: SkColors.ink3),
            textAlign: TextAlign.center,
          ),
        ] else
          ..._previewBody(p),
        const SizedBox(height: 24),
        Text(
          'Tricount has no official way for other apps to connect, so this uses the same private connection as the Tricount app. '
          'If Tricount changes it, syncing stops until Splitkit is updated; nothing already here is lost.',
          style: SkText.body(12, 400, color: SkColors.ink3, height: 1.4),
        ),
      ],
    );
  }

  List<Widget> _previewBody(TricountLinkPreviewOut p) {
    final members = widget.group?.members ?? const <MemberOut>[];
    final counts = [
      '${p.expenses} ${p.expenses == 1 ? 'expense' : 'expenses'}',
      '${p.payments} ${p.payments == 1 ? 'payment' : 'payments'}',
    ].join(' · ');
    return [
      SkCard(
        child: Row(
          children: [
            const IconTile('swap', background: SkColors.brandSoft, foreground: SkColors.brandInk),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, style: SkText.body(16, 700)),
                  Text('$counts · ${p.currency}', style: SkText.body(13, 400, color: SkColors.ink2)),
                ],
              ),
            ),
          ],
        ),
      ),
      if (widget.group != null && widget.group!.name != p.title && p.problem == null) ...[
        const SizedBox(height: 10),
        Text(
          '“${widget.group!.name}” will be renamed “${p.title}” to match the tricount.',
          style: SkText.body(13, 400, color: SkColors.ink2),
        ),
      ],
      if (p.unsupported > 0) ...[
        const SizedBox(height: 10),
        Text(
          "${p.unsupported} ${p.unsupported == 1 ? 'entry' : 'entries'} (income) can't be shown in Splitkit and stay in Tricount only.",
          style: SkText.body(13, 400, color: SkColors.pending),
        ),
      ],
      if (p.problem != null) ...[
        const SizedBox(height: 12),
        Text(p.problem!, style: SkText.body(14, 600, color: SkColors.oweInk)),
      ] else ...[
        const SizedBox(height: 20),
        const Overline('Who is who'),
        const SizedBox(height: 8),
        for (final person in p.people)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(child: Text(person.name, style: SkText.body(15, 600), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 200,
                  child: _PersonSelect(
                    label: 'Who ${person.name} is',
                    value: _people[person.memberUuid] ?? _newPerson,
                    items: [
                      for (final m in members) (m.user.id, m.user.name),
                      (_newPerson, 'Add as a new person'),
                    ],
                    onChanged: (v) => setState(() => _people[person.memberUuid] = v),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          "People in this group who aren't in the tricount are added to it.",
          style: SkText.body(12, 400, color: SkColors.ink3),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: SkText.body(14, 600, color: SkColors.oweInk)),
      ],
      const SizedBox(height: 16),
      SkButton(
        _busy ? 'Linking…' : 'Start syncing',
        expand: true,
        size: SkButtonSize.large,
        onPressed: _busy || p.problem != null ? null : () => _start(create: false),
      ),
      const SizedBox(height: 8),
      SkButton(
        'Use another link',
        variant: SkButtonVariant.ghost,
        expand: true,
        onPressed: _busy ? null : () => setState(() => _preview = null),
      ),
    ];
  }
}

class _PersonSelect extends StatelessWidget {
  const _PersonSelect({required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: SkColors.surface,
          borderRadius: BorderRadius.circular(SkRadius.input),
          border: Border.all(color: SkColors.lineStrong, width: 1.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const SkIcon('down', size: 16, color: SkColors.ink2),
            style: SkText.body(14, 500, color: SkColors.ink),
            items: [
              for (final (v, text) in items)
                DropdownMenuItem<String>(value: v, child: Text(text, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}
