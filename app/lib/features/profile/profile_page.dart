import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

/// Screen 13: who you are, this month at a glance, settings.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final month = monthOf(DateTime.now());
    final summary = ref.watch(personalSummaryProvider(month));
    final balances = ref.watch(overallBalancesProvider);
    final categories = ref.watch(allCategoriesProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Avatar(SkPerson(id: me.id, name: me.name), size: 64, fontSize: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(header: true, child: Text(me.name, style: SkText.display(24, 700))),
                            const SizedBox(height: 2),
                            Text(me.email ?? '', style: SkText.body(13, 400, color: SkColors.ink2)),
                            const SizedBox(height: 2),
                            Text(
                              'Member since ${DateFormat('MMM y').format(me.createdAt.toLocal())} · ${me.currency}',
                              style: SkText.body(12, 400, color: SkColors.ink3),
                            ),
                          ],
                        ),
                      ),
                      SkButton(
                        'Edit',
                        variant: SkButtonVariant.secondary,
                        size: SkButtonSize.small,
                        onPressed: () => showEditProfileSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Tabs(
                    onHistory: () => context.go('/personal/history'),
                    onAnalytics: () => context.go('/profile/analytics'),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(DateFormat('MMMM').format(month), style: SkText.display(18, 700)),
                  ),
                  const SizedBox(height: 10),
                  _overview(summary, balances, me.currency),
                  const SizedBox(height: 16),
                  SkCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _link(
                          'wallet',
                          'Default currency',
                          '${me.currency} ${currencySymbol(me.currency)}',
                          () => showEditProfileSheet(context),
                        ),
                        _link(
                          'grid',
                          'Categories',
                          categories.hasValue ? '${categories.value!.length}' : '',
                          () => context.go('/profile/categories'),
                        ),
                        _link('upload', 'Import from Tricount', 'Soon', null),
                        _link(
                          'logout',
                          'Log out',
                          '',
                          () async {
                            final ok = await showConfirmDialog(
                              context,
                              title: 'Log out?',
                              body: 'You can log back in with your email and password.',
                              confirmLabel: 'Log out',
                              destructive: false,
                            );
                            if (ok) await ref.read(sessionProvider.notifier).logout();
                          },
                          color: SkColors.owe,
                          last: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overview(AsyncValue<PersonalSummaryOut> summary, AsyncValue<OverallBalancesOut> balances, String currency) {
    final totals = balances.value?.totals.where((t) => t.currency == currency).firstOrNull;
    Widget tile(
      Widget label,
      String value, {
      Color bg = SkColors.surface,
      Color valueColor = SkColors.ink,
      bool border = true,
    }) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: border ? Border.all(color: SkColors.line) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 4),
            Text(value, style: SkText.display(22, 800, color: valueColor)),
          ],
        ),
      ),
    );
    Widget swatch(String text, Color c, Color ink) => Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: SkText.body(12, 600, color: ink)),
        ),
      ],
    );
    final s = summary.value;
    return Column(
      children: [
        Row(
          children: [
            tile(
              swatch('Personal spending', SkColors.personal, SkColors.personalInk),
              s == null ? '…' : money(s.spentMinor, currency),
            ),
            const SizedBox(width: 8),
            tile(
              swatch('Group spending', SkColors.brand, SkColors.brandInk),
              s == null ? '…' : money(s.groupShareMinor, currency),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            tile(
              Text('You owe', style: SkText.body(12, 600, color: SkColors.oweInk)),
              money(totals?.youOweMinor ?? 0, currency),
              bg: SkColors.oweSoft,
              valueColor: SkColors.owe,
              border: false,
            ),
            const SizedBox(width: 8),
            tile(
              Text('Owed to you', style: SkText.body(12, 600, color: SkColors.owedInk)),
              money(totals?.youAreOwedMinor ?? 0, currency),
              bg: SkColors.owedSoft,
              valueColor: SkColors.owed,
              border: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _link(
    String glyph,
    String label,
    String value,
    VoidCallback? onTap, {
    Color color = SkColors.ink,
    bool last = false,
  }) {
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: SkPalette.divider)),
          ),
          child: Row(
            children: [
              SkIcon(glyph, size: 20, color: onTap == null ? SkColors.ink3 : color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: SkText.body(15, 600, color: onTap == null ? SkColors.ink3 : color)),
              ),
              if (value.isNotEmpty) Text(value, style: SkText.body(13, 500, color: SkColors.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overview / History / Analytics segmented control.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.onHistory, required this.onAnalytics});
  final VoidCallback onHistory;
  final VoidCallback onAnalytics;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool on, VoidCallback? onTap) => Expanded(
      child: Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: on ? SkColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: on ? const [BoxShadow(color: SkPalette.shadowInk, blurRadius: 3, offset: Offset(0, 1))] : null,
            ),
            alignment: Alignment.center,
            child: Text(label, style: SkText.body(14, on ? 700 : 600, color: on ? SkColors.brandInk : SkColors.ink2)),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          tab('Overview', true, null),
          const SizedBox(width: 4),
          tab('History', false, onHistory),
          const SizedBox(width: 4),
          tab('Analytics', false, onAnalytics),
        ],
      ),
    );
  }
}

Future<void> showEditProfileSheet(BuildContext context) =>
    showAppBottomSheet<void>(context, title: 'Edit profile', child: const _EditProfile());

class _EditProfile extends ConsumerStatefulWidget {
  const _EditProfile();

  @override
  ConsumerState<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<_EditProfile> {
  late final _name = TextEditingController(text: ref.read(meProvider).name);
  late String _currency = ref.read(meProvider).currency;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Your name can’t be empty');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).users.updateMe(UserUpdate(name: _name.text.trim(), currency: _currency));
      ref.invalidate(sessionProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkTextField(label: 'Name', controller: _name, errorText: _error),
          const SizedBox(height: 14),
          Text('Default currency', style: SkText.body(13, 600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final c in supportedCurrencies.keys)
                SelectableChip(
                  label: '$c ${currencySymbol(c)}',
                  selected: _currency == c,
                  onTap: () => setState(() => _currency = c),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Used for new groups and your personal finances. Existing groups keep their currency.',
            style: SkText.body(12, 400, color: SkColors.ink2),
          ),
          const SizedBox(height: 18),
          SkButton(_busy ? 'Saving…' : 'Save', size: SkButtonSize.large, expand: true, onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}
