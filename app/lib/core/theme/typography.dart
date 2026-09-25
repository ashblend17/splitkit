import 'package:flutter/painting.dart';

import 'tokens.g.dart';

/// Text styles built from the type tokens.
///
/// Both families are variable fonts, so weight is set with a `wght` variation (and
/// [FontWeight] for fallback). Bricolage Grotesque also gets an `opsz` equal to the size,
/// matching the browser's `font-optical-sizing: auto`, and the designs' -0.02em tracking.
/// Every style uses tabular figures so amounts line up.
abstract final class SkText {
  static const displayFamily = 'BricolageGrotesque';
  static const bodyFamily = 'InstrumentSans';

  static TextStyle display(double size, int weight, {Color? color, double? height, double tracking = -0.02}) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      fontWeight: _weight(weight),
      fontVariations: [FontVariation('wght', weight.toDouble()), FontVariation('opsz', size.clamp(12, 96).toDouble())],
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: size * tracking,
      height: height,
      color: color ?? SkColors.ink,
    );
  }

  static TextStyle body(double size, int weight, {Color? color, double? height, double letterSpacing = 0}) {
    return TextStyle(
      fontFamily: bodyFamily,
      fontSize: size,
      fontWeight: _weight(weight),
      fontVariations: [FontVariation('wght', weight.toDouble())],
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: letterSpacing,
      height: height,
      color: color ?? SkColors.ink,
    );
  }

  static TextStyle token(SkTypeToken t, {Color? color, double? height}) => switch (t.family) {
    SkFamily.display => display(t.size, t.weight, color: color, height: height),
    SkFamily.body => body(t.size, t.weight, color: color, height: height),
  };

  static final amountHero = token(SkType.amountHero, height: 1);
  static final title = token(SkType.title);
  static final section = token(SkType.section);
  static final cardAmount = display(19, 700, tracking: -0.01);
  static final bodyText = token(SkType.body);
  static final label = token(SkType.label, color: SkColors.ink2);
  static final caption = token(SkType.caption, color: SkColors.ink2);

  /// Day headers such as "YESTERDAY": 13/700, caps, 0.06em. Pass text already upper-cased.
  static final overline = body(13, 700, color: SkColors.ink2, letterSpacing: 13 * 0.06);

  static FontWeight _weight(int w) => FontWeight.values[((w ~/ 100) - 1).clamp(0, 8)];
}
