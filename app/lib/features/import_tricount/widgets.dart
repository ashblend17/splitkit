import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

/// Page header: back button, breadcrumb, title and an optional line under it.
class ImportHeader extends StatelessWidget {
  const ImportHeader({
    super.key,
    required this.crumb,
    required this.title,
    required this.onBack,
    required this.backLabel,
    this.subtitle,
  });

  final String crumb;
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(-8, 0),
          child: HeaderIconButton(glyph: 'back', label: backLabel, onPressed: onBack),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crumb, style: SkText.body(13, 600, color: SkColors.ink2)),
                const SizedBox(height: 2),
                Semantics(header: true, child: Text(title, style: SkText.display(26, 800))),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: SkText.body(15, 400, color: SkColors.ink2)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Upload · Match people · Review · Import, with the current one highlighted and earlier
/// ones ticked. Numbers and ticks carry the meaning, not just the colour.
class ImportSteps extends StatelessWidget {
  const ImportSteps({super.key, required this.current});

  /// 1-based.
  final int current;

  static const labels = ['Upload', 'Match people', 'Review', 'Import'];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Semantics(
      label: 'Step $current of 4: ${labels[current - 1]}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _step(i + 1, compact)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _step(int n, bool compact) {
    final done = n < current, on = n == current;
    final dotBg = on ? SkColors.brand : done ? SkColors.owed : SkColors.sunken;
    final dotFg = on || done ? SkColors.onFill : SkColors.ink2;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14, vertical: 10),
      decoration: BoxDecoration(
        color: on ? SkColors.brandSoft : SkColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? SkColors.brand : SkColors.line, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: dotBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: done
                ? SkIcon('check', size: 14, color: dotFg)
                : Text('$n', style: SkText.body(12, 800, color: dotFg)),
          ),
          if (!compact || on) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                labels[n - 1],
                overflow: TextOverflow.ellipsis,
                style: SkText.body(14, 700, color: on || done ? SkColors.ink : SkColors.ink2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum NoticeTone { good, warn }

/// "6 people found · 5 match existing users" (green, with a tick) or a "Needs a look" line
/// (amber, with an alert sign).
class ImportNotice extends StatelessWidget {
  const ImportNotice({super.key, required this.label, required this.detail, required this.tone});

  final String label;
  final String detail;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final good = tone == NoticeTone.good;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: good ? SkColors.owedSoft : SkColors.pendingSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SkIcon(good ? 'check' : 'alert', size: 20, color: good ? SkColors.owed : SkColors.pending),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: SkText.body(15, good ? 700 : 600))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              detail,
              textAlign: TextAlign.end,
              style: SkText.body(13, 500, color: good ? SkColors.owedInk : SkPalette.pendingInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// A white card with a title bar ("People · 5 of 6 matched") and rows under it.
class ImportSection extends StatelessWidget {
  const ImportSection({super.key, required this.title, required this.trailing, required this.children});

  final String title;
  final String trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SkCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: SkColors.line))),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(header: true, child: Text(title, style: SkText.display(17, 700))),
                ),
                Text(trailing, style: SkText.body(13, 500, color: SkColors.ink2)),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// A dropdown styled like the mockups' selects: amber border when it needs a choice.
class ImportSelect extends StatelessWidget {
  const ImportSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.warn = false,
  });

  final String label;
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;
  final bool warn;

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
          border: Border.all(color: warn ? SkPalette.importWarn : SkColors.lineStrong, width: 1.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: SkIcon('down', size: 16, color: SkColors.ink2),
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

/// A big number with a caption under it, on the Done screen.
class ImportStat extends StatelessWidget {
  const ImportStat({super.key, required this.value, required this.label, this.warn = false});

  final String value;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn ? SkColors.pendingSoft : SkColors.paper,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: SkText.display(28, 800, color: warn ? SkColors.pending : SkColors.ink)),
          const SizedBox(height: 2),
          Text(label, style: SkText.body(13, 500, color: warn ? SkPalette.pendingInk : SkColors.ink2)),
        ],
      ),
    );
  }
}
