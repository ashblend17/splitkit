import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/router/router.dart';
import 'core/theme/theme.dart';

void main() {
  // Real paths (/groups/…) instead of /#/groups/…; nginx serves index.html for any path.
  usePathUrlStrategy();
  // No automatic retries: failed requests show an error card with "Try again".
  runApp(ProviderScope(retry: (_, _) => null, child: const SplitkitApp()));
}

class SplitkitApp extends ConsumerWidget {
  const SplitkitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Splitkit',
      debugShowCheckedModeBanner: false,
      theme: buildSplitkitTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
