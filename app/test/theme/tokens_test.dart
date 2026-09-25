import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/theme/theme.dart';

/// tokens.g.dart must match splitkit-design/tokens.json. If this fails, run
/// `python3 tool/gen_tokens.py` from the repo root.
void main() {
  final tokens = jsonDecode(File('../splitkit-design/tokens.json').readAsStringSync()) as Map<String, dynamic>;

  test('colours', () {
    final colors = (tokens['color'] as Map).cast<String, String>();
    expect(skColorTokens.keys, colors.keys);
    colors.forEach((name, hex) {
      expect(skColorTokens[name], Color(int.parse('FF${hex.substring(1)}', radix: 16)), reason: name);
    });
  });

  test('type, space, radius, breakpoints', () {
    final type = (tokens['type'] as Map).cast<String, Map>();
    final generated = {
      'amountHero': SkType.amountHero,
      'title': SkType.title,
      'section': SkType.section,
      'cardAmount': SkType.cardAmount,
      'body': SkType.body,
      'label': SkType.label,
      'caption': SkType.caption,
    };
    expect(generated.keys, type.keys);
    type.forEach((k, v) {
      expect(
        (generated[k]!.size, generated[k]!.weight, generated[k]!.family.name),
        (v['size'], v['weight'], v['family']),
      );
    });
    expect(SkSpace.scale, (tokens['space'] as List).map((e) => (e as num).toDouble()));
    final r = tokens['radius'] as Map;
    expect(
      [SkRadius.input, SkRadius.button, SkRadius.card, SkRadius.sheet, SkRadius.chip],
      [r['input'], r['button'], r['card'], r['sheet'], r['chip']],
    );
    expect(skMinTouchTarget, tokens['minTouchTarget']);
    final b = tokens['breakpoints'] as Map;
    expect(
      [SkBreakpoints.mobile, SkBreakpoints.tablet, SkBreakpoints.desktop],
      [b['mobile'], b['tablet'], b['desktop']],
    );
  });

  test('display text uses optical size and tracking from the designs', () {
    final s = SkText.display(44, 800);
    expect(s.fontFamily, 'BricolageGrotesque');
    expect(s.letterSpacing, closeTo(-0.88, 1e-9));
    expect(s.fontVariations!.map((v) => (v.axis, v.value)), [('wght', 800.0), ('opsz', 44.0)]);
    expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
  });
}
