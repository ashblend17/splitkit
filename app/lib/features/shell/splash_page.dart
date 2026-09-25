import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';

/// Shown while the saved session is checked, or if the API can't be reached at launch.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: session.hasError
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ErrorState(
                    title: "Couldn't reach Splitkit",
                    body: 'Check your connection and try again.',
                    onRetry: () => ref.invalidate(sessionProvider),
                  ),
                )
              : Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: SkColors.ink, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: SkIcon('settle', size: 28, color: Colors.white)),
                ),
        ),
      ),
    );
  }
}
