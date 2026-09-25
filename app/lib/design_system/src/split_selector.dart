import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/money.dart';
import '../../core/splits/split_engine.dart';
import '../../core/theme/theme.dart';
import 'avatar.dart';
import 'sk_icon.dart';

/// State of a split being configured. Keeps every method's inputs, so switching tabs and
/// back doesn't lose what was typed, and re-runs the pure engine on every change.
class SplitController extends ChangeNotifier {
  SplitController({
    required this.people,
    required int totalMinor,
    this.currency = 'INR',
    SplitRegistry? registry,
    String method = 'equal',
    Set<String>? included,
    Map<String, Map<String, String>>? values,
  }) : registry = registry ?? splitRegistry,
       _total = totalMinor,
       _method = method,
       _included = included ?? {for (final p in people) p.id},
       _values = {
         for (final e in (values ?? const {}).entries) e.key: {...e.value},
       };

  final List<SkPerson> people;
  final String currency;
  final SplitRegistry registry;
  int _total;
  String _method;
  final Set<String> _included;

  /// method key -> person id -> text as typed (rupees for exact, % or shares otherwise).
  final Map<String, Map<String, String>> _values;

  int get totalMinor => _total;
  String get method => _method;
  SplitMethod get splitMethod => registry.get(_method);
  bool isIncluded(String id) => _included.contains(id);
  String valueFor(String id) => _values[_method]?[id] ?? '';

  set totalMinor(int value) {
    if (value == _total) return;
    _total = value;
    notifyListeners();
  }

  void selectMethod(String key) {
    if (key == _method) return;
    registry.get(key);
    _method = key;
    notifyListeners();
  }

  void toggle(String id) {
    _included.contains(id) ? _included.remove(id) : _included.add(id);
    notifyListeners();
  }

  void setValue(String id, String text) {
    (_values[_method] ??= {})[id] = text;
    notifyListeners();
  }

  /// Engine inputs for the current method. Unparseable text counts as 0, as in the mockup.
  List<SplitInput> get inputs {
    if (_method == 'equal') {
      return [
        for (final p in people)
          if (_included.contains(p.id)) SplitInput(p.id),
      ];
    }
    return [for (final p in people) SplitInput(p.id, _parse(valueFor(p.id)))];
  }

  Decimal _parse(String text) {
    if (_method == 'exact') return Decimal.fromInt(parseMinor(text, currency: currency) ?? 0);
    return Decimal.tryParse(text.trim()) ?? Decimal.zero;
  }

  SplitValidation get validation => splitMethod.validate(_total, inputs, currency: currency);

  /// Shares when valid, otherwise null.
  List<Share>? get shares {
    final v = validation;
    return v.ok ? splitMethod.allocate(_total, inputs, currency: currency) : null;
  }

  /// Per-person amount to preview in rows, even while the split is still invalid.
  Map<String, int> get previewMinor {
    final ok = shares;
    if (ok != null) return {for (final s in ok) s.userId: s.shareMinor};
    final result = <String, int>{};
    final values = {for (final i in inputs) i.userId: i.value};
    final weightSum = values.values.fold(Decimal.zero, (a, v) => a + (v ?? Decimal.zero));
    for (final p in people) {
      final v = values[p.id] ?? Decimal.zero;
      result[p.id] = switch (_method) {
        'exact' => v.toBigInt().toInt(),
        'percent' => (Decimal.fromInt(_total) * v / Decimal.fromInt(100)).round().toInt(),
        'shares' when weightSum > Decimal.zero => (Decimal.fromInt(_total) * v / weightSum).round().toInt(),
        _ => 0,
      };
    }
    return result;
  }

  /// Footer figures: "Allocated" and "Remaining" in the method's own unit.
  (String allocated, String remaining) get summary {
    String money(int m) => formatMinor(m, currency: currency);
    final v = validation;
    switch (_method) {
      case 'percent':
        final pct = inputs.fold(Decimal.zero, (a, i) => a + (i.value ?? Decimal.zero));
        return ('$pct%', '${Decimal.fromInt(100) - pct}%');
      case 'shares':
        final n = inputs.fold(Decimal.zero, (a, i) => a + (i.value ?? Decimal.zero));
        return ('$n ${n == Decimal.one ? 'share' : 'shares'}', money(v.remainingMinor));
      default:
        return (money(_total - v.remainingMinor), money(v.remainingMinor));
    }
  }
}

enum SplitTabsStyle {
  /// SplitConfig screen: 44px tabs, symbol above label.
  stacked,

  /// Components gallery: 40px tabs, "₹ Exact" on one line.
  inline,
}

/// Segmented control over every registered split method.
class SplitMethodTabs extends StatelessWidget {
  const SplitMethodTabs({
    super.key,
    required this.methods,
    required this.selected,
    required this.onSelected,
    this.style = SplitTabsStyle.stacked,
  });

  final List<SplitMethod> methods;
  final String selected;
  final ValueChanged<String> onSelected;
  final SplitTabsStyle style;

  @override
  Widget build(BuildContext context) {
    final stacked = style == SplitTabsStyle.stacked;
    return Semantics(
      label: 'Split method',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            for (var i = 0; i < methods.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _tab(methods[i], stacked)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tab(SplitMethod m, bool stacked) {
    final on = m.key == selected;
    final fg = on ? SkColors.brandInk : SkColors.ink2;
    return Semantics(
      selected: on,
      button: true,
      label: '${m.label} split',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(m.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: stacked ? 44 : 40,
          decoration: BoxDecoration(
            color: on ? SkColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: on ? const [BoxShadow(color: SkPalette.shadowInk, blurRadius: 3, offset: Offset(0, 1))] : null,
          ),
          alignment: Alignment.center,
          child: ExcludeSemantics(
            child: stacked
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(m.symbol, style: SkText.body(15, 700, color: fg, height: 1)),
                      Text(m.label, style: SkText.body(11, 600, color: fg)),
                    ],
                  )
                : Text('${m.symbol} ${m.label}', style: SkText.body(13, on ? 700 : 600, color: fg)),
          ),
        ),
      ),
    );
  }
}

({String text, Color fg, Color bg, Color border, String glyph}) splitStatus(SplitValidation v) {
  if (v.ok) {
    return (text: v.message, fg: SkColors.owed, bg: SkColors.owedSoft, border: SkPalette.validBorder, glyph: 'check');
  }
  if (v.remainingMinor < 0) {
    return (text: v.message, fg: SkColors.owe, bg: SkColors.oweSoft, border: SkPalette.dangerBorder, glyph: 'alert');
  }
  return (
    text: v.message,
    fg: SkColors.pending,
    bg: SkColors.pendingSoft,
    border: SkPalette.warnBorder,
    glyph: 'alert',
  );
}

/// The status line: green when valid, amber while incomplete, red when over.
class SplitStatusLine extends StatelessWidget {
  const SplitStatusLine(this.validation, {super.key, this.weight = 600});

  final SplitValidation validation;
  final int weight;

  @override
  Widget build(BuildContext context) {
    final s = splitStatus(validation);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            SkIcon(s.glyph, size: 18, color: s.fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.text, style: SkText.body(14, weight, color: s.fg)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer summary from SplitConfig: Total / Allocated / Remaining plus the status line.
class SplitSummary extends StatelessWidget {
  const SplitSummary({super.key, required this.controller});

  final SplitController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final v = controller.validation;
        final (allocated, remaining) = controller.summary;
        final remColor = splitStatus(v).fg;
        Widget figure(String label, String value, [Color? color]) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: SkText.body(12, 400, color: SkColors.ink2)),
              const SizedBox(height: 2),
              Text(value, style: SkText.display(17, 700, color: color)),
            ],
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                figure('Total', formatMinor(controller.totalMinor, currency: controller.currency)),
                const SizedBox(width: 8),
                figure('Allocated', allocated),
                const SizedBox(width: 8),
                figure('Remaining', remaining, remColor),
              ],
            ),
            const SizedBox(height: 12),
            SplitStatusLine(v),
          ],
        );
      },
    );
  }
}

/// Compact summary box from the Components gallery (bordered by status colour).
class SplitSummaryBox extends StatelessWidget {
  const SplitSummaryBox({super.key, required this.controller});

  final SplitController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final v = controller.validation;
        final s = splitStatus(v);
        final (allocated, remaining) = controller.summary;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: s.border, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 10,
                runSpacing: 2,
                children: [
                  Text(
                    'Total ${formatMinor(controller.totalMinor, currency: controller.currency)}',
                    style: SkText.body(13, 400),
                  ),
                  Text('Allocated $allocated', style: SkText.body(13, 400)),
                  Text('Remaining $remaining', style: v.ok ? SkText.body(13, 400) : SkText.body(13, 700, color: s.fg)),
                ],
              ),
              const SizedBox(height: 8),
              SplitStatusLine(v, weight: 700),
            ],
          ),
        );
      },
    );
  }
}

/// Method tabs, hint and one row per person, driven by [controller] (SplitConfig screen).
class SplitSelector extends StatelessWidget {
  const SplitSelector({super.key, required this.controller, this.payerId, this.payerName});

  final SplitController controller;
  final String? payerId;
  final String? payerName;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final method = controller.splitMethod;
        final preview = controller.previewMinor;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SplitMethodTabs(
              methods: controller.registry.all,
              selected: method.key,
              onSelected: controller.selectMethod,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
              child: Text(method.hint, style: SkText.body(13, 400, color: SkColors.ink2)),
            ),
            for (final p in controller.people) ...[
              _PersonRow(
                key: ValueKey('${method.key}-${p.id}'),
                person: p,
                controller: controller,
                previewMinor: preview[p.id] ?? 0,
                subtitle: _subtitle(p, method.key, preview[p.id] ?? 0),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  String _subtitle(SkPerson p, String method, int amount) {
    switch (method) {
      case 'equal':
        return controller.isIncluded(p.id) ? 'Included' : 'Not involved';
      case 'exact':
        if (p.id == payerId) return 'Paid the bill';
        return payerName == null ? 'Owes the payer' : 'Owes $payerName';
      default:
        return formatMinor(amount, currency: controller.currency);
    }
  }
}

class _PersonRow extends StatefulWidget {
  const _PersonRow({
    super.key,
    required this.person,
    required this.controller,
    required this.previewMinor,
    required this.subtitle,
  });

  final SkPerson person;
  final SplitController controller;
  final int previewMinor;
  final String subtitle;

  @override
  State<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<_PersonRow> {
  late final _text = TextEditingController(text: widget.controller.valueFor(widget.person.id));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final p = widget.person;
    final equal = c.method == 'equal';
    final on = c.isIncluded(p.id);
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SkColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SkColors.line),
      ),
      child: Row(
        children: [
          if (equal) ...[
            SizedBox.square(
              dimension: 22,
              child: Checkbox(
                value: on,
                onChanged: (_) => c.toggle(p.id),
                activeColor: SkColors.brand,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                semanticLabel: 'Include ${p.name}',
              ),
            ),
            const SizedBox(width: 12),
          ],
          Avatar(p, size: 36, fontSize: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: SkText.body(15, 600)),
                Text(widget.subtitle, style: SkText.body(13, 400, color: SkColors.ink2)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (equal)
            Text(
              on ? formatMinor(widget.previewMinor, currency: c.currency) : '—',
              style: SkText.display(18, 700, color: on ? SkColors.ink : SkColors.ink3),
            )
          else
            _ValueInput(
              controller: _text,
              prefix: c.method == 'exact' ? currencySymbol(c.currency) : '',
              suffix: switch (c.method) {
                'percent' => '%',
                'shares' => '×',
                _ => '',
              },
              label: '${c.splitMethod.label} for ${p.name}',
              onChanged: (t) => c.setValue(p.id, t),
            ),
        ],
      ),
    );
  }
}

class _ValueInput extends StatelessWidget {
  const _ValueInput({
    required this.controller,
    required this.prefix,
    required this.suffix,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String prefix;
  final String suffix;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final affix = SkText.body(14, 600, color: SkColors.ink3);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: SkColors.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SkColors.lineStrong, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefix.isNotEmpty) Text(prefix, style: affix),
          const SizedBox(width: 4),
          Semantics(
            label: label,
            textField: true,
            child: SizedBox(
              width: 64,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: SkText.body(16, 700),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: '0',
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (suffix.isNotEmpty) Text(suffix, style: affix),
        ],
      ),
    );
  }
}
