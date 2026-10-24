import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/design_system.dart';
import '../common/common.dart';

/// A link to somewhere the app doesn't have (an old or mistyped address).
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ContentWidth(
              maxWidth: 420,
              child: EmptyState(
                glyph: 'search',
                title: "This page doesn't exist",
                body: 'The link may be old or mistyped.',
                actionLabel: 'Go home',
                onAction: () => context.go('/home'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
