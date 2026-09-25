import 'package:flutter/material.dart';

import '../../core/copy/copy.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

/// "How to split?": method tabs, one row per person, live totals. Edits the caller's
/// [SplitController] in place; Done is enabled only while the split is valid.
class SplitConfigPage extends StatelessWidget {
  const SplitConfigPage({super.key, required this.controller, required this.description, this.payerId, this.payerName});

  final SplitController controller;
  final String description;
  final String? payerId;
  final String? payerName;

  @override
  Widget build(BuildContext context) {
    final total = money(controller.totalMinor, controller.currency);
    return Scaffold(
      backgroundColor: SkColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                color: SkColors.surface,
                border: Border(bottom: BorderSide(color: SkColors.line)),
              ),
              child: Row(
                children: [
                  HeaderIconButton(glyph: 'back', label: 'Back', onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(header: true, child: Text('How to split?', style: SkText.display(18, 700))),
                        Text(
                          [
                            if (description.isNotEmpty) description,
                            if (payerName != null) '$payerName paid',
                          ].join(' · '),
                          style: SkText.body(12, 400, color: SkColors.ink2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(total, style: SkText.display(20, 800)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  ContentWidth(
                    child: SplitSelector(controller: controller, payerId: payerId, payerName: payerName),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              decoration: const BoxDecoration(
                color: SkColors.surface,
                border: Border(top: BorderSide(color: SkColors.line)),
              ),
              child: ContentWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SplitSummary(controller: controller),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => SkButton(
                        'Done',
                        size: SkButtonSize.large,
                        expand: true,
                        onPressed: controller.validation.ok ? () => Navigator.of(context).pop() : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
