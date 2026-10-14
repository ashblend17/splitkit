import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api.dart';
import '../../core/data/providers.dart';
import '../../core/local/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/theme_mode.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../../core/integrations.dart';
import '../sms/sms_setup_page.dart';
import '../sms/sms_source.dart';
import 'device_card.dart';

/// Screen 13: who you are and your settings. Shared by both modes: this month's spending
/// lives in Personal, balances in Split.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
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
                  const SizedBox(height: 20),
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
                          'moon',
                          'Appearance',
                          _themeLabels[ref.watch(themeModeProvider)]!,
                          () => _pickTheme(context, ref),
                        ),
                        _link(
                          'grid',
                          'Categories',
                          categories.hasValue ? '${categories.value!.length}' : '',
                          () => context.go('/profile/categories'),
                        ),
                        if (ref.watch(smsSourceProvider).available && ref.watch(featuresProvider).smsImport)
                          _link(
                            'file',
                            'Bank SMS',
                            switch (ref.watch(smsSetupProvider).value?.settings) {
                              null => 'Off',
                              _ => 'On',
                            },
                            () => context.go('/profile/sms'),
                          ),
                        _link('upload', 'Import from Tricount', '', () => context.go('/profile/import')),
                        _link(
                          'logout',
                          'Log out',
                          '',
                          () async {
                            final unsynced = ref.read(outboxProvider).length;
                            final ok = await showConfirmDialog(
                              context,
                              title: 'Log out?',
                              body: unsynced == 0
                                  ? 'You can log back in with your email and password.'
                                  : '$unsynced change(s) on this device haven\'t reached the server and will be '
                                        'deleted. Copy them from "This device" first if you need them.',
                              confirmLabel: 'Log out',
                              destructive: unsynced > 0,
                            );
                            if (ok) await ref.read(sessionProvider.notifier).logout();
                          },
                          color: SkColors.owe,
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const DeviceCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _link(
    String glyph,
    String label,
    String value,
    VoidCallback? onTap, {
    Color? color,
    bool last = false,
  }) {
    color ??= SkColors.ink;
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: last ? null : Border(bottom: BorderSide(color: SkPalette.divider)),
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

const _themeLabels = {ThemeMode.system: 'As the device', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'};

/// Light, dark, or following the phone or browser.
Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
  final current = ref.read(themeModeProvider);
  final picked = await showAppBottomSheet<ThemeMode>(
    context,
    title: 'Appearance',
    child: Column(
      children: [
        for (final MapEntry(key: mode, value: label) in _themeLabels.entries)
          Builder(
            builder: (sheet) => Semantics(
              selected: mode == current,
              button: true,
              child: InkWell(
                onTap: () => Navigator.of(sheet).pop(mode),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: SkText.body(15, 600))),
                      if (mode == current) SkIcon('check', size: 20, color: SkColors.brand),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
  if (picked != null) ref.read(themeModeProvider.notifier).set(picked);
}

/// Overview / History / Analytics segmented control.
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
      await ref.read(apiProvider).users.updateMe(UserUpdate(name: _name.text.trim(), currency: UserUpdateCurrencyEnum.fromJson(_currency)));
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
          SkTextField(
            label: 'Name',
            controller: _name,
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
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
