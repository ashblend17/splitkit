import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/local/providers.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';

/// A one-line notice above every signed-in screen while the last sync couldn't reach the
/// server. Screens keep working from what's on this device.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(syncStatusProvider).value?.offline ?? false;
    return Column(
      children: [
        if (offline)
          Semantics(
            liveRegion: true,
            child: Material(
              color: SkColors.sunken,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SkIcon('alert', size: 16, color: SkColors.ink2),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You're offline. Showing what's on this device.",
                          style: SkText.body(13, 600, color: SkColors.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: offline, child: child)),
      ],
    );
  }
}
