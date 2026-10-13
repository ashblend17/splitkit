import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/integrations.dart';
import '../../core/local/providers.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import 'sms_importer.dart';
import 'sms_setup_page.dart';
import 'sms_source.dart';

/// Overview's offer to read bank SMS: on Android, until it's set up or you say not now.
class SmsPromptCard extends ConsumerWidget {
  const SmsPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(smsSourceProvider).available || !ref.watch(featuresProvider).smsImport) {
      return const SizedBox.shrink();
    }
    final setup = ref.watch(smsSetupProvider).value;
    if (setup == null || setup.settings != null || setup.dismissed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SkCard(
        color: SkColors.personalSoft,
        borderColor: SkColors.personalSoft,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add spending from your bank SMS', style: SkText.body(15, 700, color: SkColors.personalInk)),
            const SizedBox(height: 4),
            Text(
              'Read on this phone. Only the payments are saved, never the messages.',
              style: SkText.body(13, 400, color: SkColors.ink2),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SkButton(
                  'Set up',
                  size: SkButtonSize.small,
                  variant: SkButtonVariant.strong,
                  onPressed: () => context.go('/profile/sms'),
                ),
                const SizedBox(width: 8),
                SkButton(
                  'Not now',
                  size: SkButtonSize.small,
                  variant: SkButtonVariant.ghost,
                  onPressed: () async {
                    final store = await ref.read(localStoreProvider.future);
                    await store.setDeviceValue(SmsKeys.promptDismissed, true);
                    ref.invalidate(smsSetupProvider);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
