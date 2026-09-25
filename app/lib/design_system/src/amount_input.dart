import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/money.dart';
import '../../core/theme/theme.dart';

/// Keeps digits and one decimal point (max 2 places) and regroups the whole part in the
/// Indian style as you type: "180000" -> "1,80,000".
class IndianAmountFormatter extends TextInputFormatter {
  const IndianAmountFormatter({this.decimals = 2});

  final int decimals;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var raw = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final dot = raw.indexOf('.');
    if (dot != -1) {
      final whole = raw.substring(0, dot);
      var fraction = raw.substring(dot + 1).replaceAll('.', '');
      if (fraction.length > decimals) fraction = fraction.substring(0, decimals);
      raw = '$whole.$fraction';
    }
    final parts = raw.split('.');
    var whole = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.isEmpty && parts.length > 1) whole = '0';
    final text = parts.length > 1 ? '${groupIndian(whole)}.${parts[1]}' : groupIndian(whole);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Big centred amount entry from Add split: "₹" prefix, 56/800 figure, currency chip.
/// Reports the value in minor units (null while empty or unparseable).
class AmountInput extends StatefulWidget {
  const AmountInput({
    super.key,
    this.initialMinor,
    this.currency = 'INR',
    this.onChanged,
    this.onCurrencyTap,
    this.label = 'Amount',
    this.autofocus = false,
    this.controller,
    this.symbolSize = 32,
    this.fontSize = 56,
    this.showCurrencyChip = true,
  });

  final int? initialMinor;
  final String currency;
  final ValueChanged<int?>? onChanged;
  final VoidCallback? onCurrencyTap;
  final String label;
  final bool autofocus;

  /// Supply one to set the text from outside (e.g. a "Full balance" chip).
  final TextEditingController? controller;

  /// Add split uses 32/56; the payment sheet 30/52.
  final double symbolSize;
  final double fontSize;
  final bool showCurrencyChip;

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController(text: _initialText());

  String _initialText() {
    final m = widget.initialMinor;
    if (m == null) return '';
    return formatMinor(m, currency: widget.currency).substring(currencySymbol(widget.currency).length);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: SkText.body(13, 600, color: SkColors.ink2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(currencySymbol(widget.currency), style: SkText.display(widget.symbolSize, 600, color: SkColors.ink3)),
            const SizedBox(width: 6),
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 260),
                child: TextField(
                  controller: _controller,
                  autofocus: widget.autofocus,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [IndianAmountFormatter()],
                  onChanged: (t) => widget.onChanged?.call(parseMinor(t, currency: widget.currency)),
                  style: SkText.display(widget.fontSize, 800),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '0',
                    hintStyle: SkText.display(widget.fontSize, 800, color: SkColors.lineStrong),
                    semanticCounterText: '',
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.showCurrencyChip) const SizedBox(height: 8),
        if (widget.showCurrencyChip)
          Center(
            child: Material(
              color: SkColors.paper,
              shape: const StadiumBorder(side: BorderSide(color: SkColors.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onCurrencyTap,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    widthFactor: 1,
                    child: Text(widget.currency, style: SkText.body(12, 600, color: SkColors.ink2)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
