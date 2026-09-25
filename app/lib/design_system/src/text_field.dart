import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme.dart';
import 'sk_icon.dart';

enum SkFieldSize {
  /// Components "Inputs": 48 high, 15px text, 13/600 label.
  regular(48, 15, 13, 14),

  /// Add expense form: 52 high, 16px text, 14/600 label.
  large(52, 16, 14, 16);

  const SkFieldSize(this.height, this.fontSize, this.labelSize, this.padding);
  final double height;
  final double fontSize;
  final double labelSize;
  final double padding;
}

/// Labelled text field with the design's three states: default, focus (indigo border plus
/// a 3px soft ring) and error (red border plus message underneath).
class SkTextField extends StatefulWidget {
  const SkTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.size = SkFieldSize.regular,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.autofocus = false,
    this.errorIcon = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final SkFieldSize size;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;

  /// Register style: alert icon and 13px message instead of the compact 12px line.
  final bool errorIcon;

  @override
  State<SkTextField> createState() => _SkTextFieldState();
}

class _SkTextFieldState extends State<SkTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final focused = _focus.hasFocus;
    final borderColor = hasError
        ? SkColors.owe
        : focused
        ? SkColors.brand
        : SkColors.lineStrong;
    final size = widget.size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: SkText.body(size.labelSize, 600)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: size.height,
          decoration: BoxDecoration(
            color: SkColors.surface,
            borderRadius: BorderRadius.circular(SkRadius.button),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: focused && !hasError ? const [BoxShadow(color: SkColors.brandSoft, spreadRadius: 3)] : null,
          ),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(horizontal: size.padding),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            autofillHints: widget.autofillHints,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            inputFormatters: widget.inputFormatters,
            style: SkText.body(size.fontSize, 400),
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: widget.hint,
              hintStyle: SkText.body(size.fontSize, 400, color: SkColors.ink3),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          if (widget.errorIcon)
            Row(
              children: [
                const SkIcon('alert', size: 14, color: SkColors.owe),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.errorText!, style: SkText.body(13, 500, color: SkColors.owe)),
                ),
              ],
            )
          else
            Text(widget.errorText!, style: SkText.body(12, 500, color: SkColors.owe)),
        ],
      ],
    );
  }
}
