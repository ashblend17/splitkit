// GENERATED from design/tokens.json by tool/gen_tokens.py. Do not edit.
// ignore_for_file: constant_identifier_names

import 'dart:ui';

enum SkFamily { display, body }

class SkTypeToken {
  const SkTypeToken({required this.size, required this.weight, required this.family});
  final double size;
  final int weight;
  final SkFamily family;
}

/// One set of colour tokens: tokens.json "color" ([skLightColors]) or "colorDark"
/// ([skDarkColors]).
class SkColorSet {
  const SkColorSet({
    required this.paper,
    required this.surface,
    required this.sunken,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.brand,
    required this.brandInk,
    required this.brandSoft,
    required this.owe,
    required this.oweInk,
    required this.oweSoft,
    required this.owed,
    required this.owedInk,
    required this.owedSoft,
    required this.settled,
    required this.settledSoft,
    required this.pending,
    required this.pendingSoft,
    required this.personal,
    required this.personalInk,
    required this.personalSoft,
    required this.adminBand,
    required this.adminInk,
    required this.adminSoft,
    required this.onFill,
  });
  final Color paper;
  final Color surface;
  final Color sunken;
  final Color line;
  final Color lineStrong;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color brand;
  final Color brandInk;
  final Color brandSoft;
  final Color owe;
  final Color oweInk;
  final Color oweSoft;
  final Color owed;
  final Color owedInk;
  final Color owedSoft;
  final Color settled;
  final Color settledSoft;
  final Color pending;
  final Color pendingSoft;
  final Color personal;
  final Color personalInk;
  final Color personalSoft;
  final Color adminBand;
  final Color adminInk;
  final Color adminSoft;
  final Color onFill;
}

const skLightColors = SkColorSet(
  paper: Color(0xFFF4F3EF),
  surface: Color(0xFFFFFFFF),
  sunken: Color(0xFFECEAE3),
  line: Color(0xFFE3E0D8),
  lineStrong: Color(0xFFD6D3CA),
  ink: Color(0xFF15171C),
  ink2: Color(0xFF4B505A),
  ink3: Color(0xFF686D76),
  brand: Color(0xFF4636C9),
  brandInk: Color(0xFF3A2DB0),
  brandSoft: Color(0xFFECE9FB),
  owe: Color(0xFFB93A1F),
  oweInk: Color(0xFF8E2B15),
  oweSoft: Color(0xFFFBE9E3),
  owed: Color(0xFF0A7550),
  owedInk: Color(0xFF075C3F),
  owedSoft: Color(0xFFE1F3EA),
  settled: Color(0xFF4B505A),
  settledSoft: Color(0xFFECEAE3),
  pending: Color(0xFF8A5300),
  pendingSoft: Color(0xFFFCEFD6),
  personal: Color(0xFF0E8A7A),
  personalInk: Color(0xFF0B6E62),
  personalSoft: Color(0xFFDDF1EE),
  adminBand: Color(0xFFFFC933),
  adminInk: Color(0xFF1B1403),
  adminSoft: Color(0xFFFFF6D9),
  onFill: Color(0xFFFFFFFF),
);

const skDarkColors = SkColorSet(
  paper: Color(0xFF111215),
  surface: Color(0xFF1B1C20),
  sunken: Color(0xFF25262B),
  line: Color(0xFF2D2F35),
  lineStrong: Color(0xFF3B3E45),
  ink: Color(0xFFEDEDEF),
  ink2: Color(0xFFB3B7BF),
  ink3: Color(0xFF9095A0),
  brand: Color(0xFF958BF7),
  brandInk: Color(0xFFC8C2FF),
  brandSoft: Color(0xFF272350),
  owe: Color(0xFFFF8D73),
  oweInk: Color(0xFFFFB7A6),
  oweSoft: Color(0xFF3B1F18),
  owed: Color(0xFF4FCB9C),
  owedInk: Color(0xFF93E5C4),
  owedSoft: Color(0xFF12302A),
  settled: Color(0xFFB3B7BF),
  settledSoft: Color(0xFF25262B),
  pending: Color(0xFFF2B655),
  pendingSoft: Color(0xFF3A2D12),
  personal: Color(0xFF43C9B5),
  personalInk: Color(0xFF8AE2D5),
  personalSoft: Color(0xFF11302C),
  adminBand: Color(0xFFFFC933),
  adminInk: Color(0xFF1B1403),
  adminSoft: Color(0xFF2E2610),
  onFill: Color(0xFF111215),
);

/// The colours in use. Widgets read them here; the app root picks the set (theme.dart
/// SkTheme.apply) and rebuilds everything when light and dark change.
abstract final class SkColors {
  static SkColorSet current = skLightColors;

  static bool get isDark => identical(current, skDarkColors);

  static Color get paper => current.paper;
  static Color get surface => current.surface;
  static Color get sunken => current.sunken;
  static Color get line => current.line;
  static Color get lineStrong => current.lineStrong;
  static Color get ink => current.ink;
  static Color get ink2 => current.ink2;
  static Color get ink3 => current.ink3;
  static Color get brand => current.brand;
  static Color get brandInk => current.brandInk;
  static Color get brandSoft => current.brandSoft;
  static Color get owe => current.owe;
  static Color get oweInk => current.oweInk;
  static Color get oweSoft => current.oweSoft;
  static Color get owed => current.owed;
  static Color get owedInk => current.owedInk;
  static Color get owedSoft => current.owedSoft;
  static Color get settled => current.settled;
  static Color get settledSoft => current.settledSoft;
  static Color get pending => current.pending;
  static Color get pendingSoft => current.pendingSoft;
  static Color get personal => current.personal;
  static Color get personalInk => current.personalInk;
  static Color get personalSoft => current.personalSoft;
  static Color get adminBand => current.adminBand;
  static Color get adminInk => current.adminInk;
  static Color get adminSoft => current.adminSoft;
  static Color get onFill => current.onFill;
}

abstract final class SkType {
  static const amountHero = SkTypeToken(size: 44.0, weight: 800, family: SkFamily.display);
  static const title = SkTypeToken(size: 28.0, weight: 700, family: SkFamily.display);
  static const section = SkTypeToken(size: 20.0, weight: 700, family: SkFamily.display);
  static const cardAmount = SkTypeToken(size: 19.0, weight: 700, family: SkFamily.display);
  static const body = SkTypeToken(size: 16.0, weight: 400, family: SkFamily.body);
  static const label = SkTypeToken(size: 13.0, weight: 600, family: SkFamily.body);
  static const caption = SkTypeToken(size: 12.0, weight: 500, family: SkFamily.body);
}

abstract final class SkSpace {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const scale = <double>[4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0];
}

abstract final class SkRadius {
  static const input = 8.0;
  static const button = 12.0;
  static const card = 16.0;
  static const sheet = 24.0;
  static const chip = 999.0;
}

abstract final class SkBreakpoints {
  static const mobile = 390.0;
  static const tablet = 834.0;
  static const desktop = 1280.0;
}

const skMinTouchTarget = 44.0;

/// Every light colour token by name, for tests and the gallery.
const skColorTokens = <String, Color>{
  'paper': Color(0xFFF4F3EF),
  'surface': Color(0xFFFFFFFF),
  'sunken': Color(0xFFECEAE3),
  'line': Color(0xFFE3E0D8),
  'lineStrong': Color(0xFFD6D3CA),
  'ink': Color(0xFF15171C),
  'ink2': Color(0xFF4B505A),
  'ink3': Color(0xFF686D76),
  'brand': Color(0xFF4636C9),
  'brandInk': Color(0xFF3A2DB0),
  'brandSoft': Color(0xFFECE9FB),
  'owe': Color(0xFFB93A1F),
  'oweInk': Color(0xFF8E2B15),
  'oweSoft': Color(0xFFFBE9E3),
  'owed': Color(0xFF0A7550),
  'owedInk': Color(0xFF075C3F),
  'owedSoft': Color(0xFFE1F3EA),
  'settled': Color(0xFF4B505A),
  'settledSoft': Color(0xFFECEAE3),
  'pending': Color(0xFF8A5300),
  'pendingSoft': Color(0xFFFCEFD6),
  'personal': Color(0xFF0E8A7A),
  'personalInk': Color(0xFF0B6E62),
  'personalSoft': Color(0xFFDDF1EE),
  'adminBand': Color(0xFFFFC933),
  'adminInk': Color(0xFF1B1403),
  'adminSoft': Color(0xFFFFF6D9),
  'onFill': Color(0xFFFFFFFF),
};

/// Every dark colour token by name.
const skDarkColorTokens = <String, Color>{
  'paper': Color(0xFF111215),
  'surface': Color(0xFF1B1C20),
  'sunken': Color(0xFF25262B),
  'line': Color(0xFF2D2F35),
  'lineStrong': Color(0xFF3B3E45),
  'ink': Color(0xFFEDEDEF),
  'ink2': Color(0xFFB3B7BF),
  'ink3': Color(0xFF9095A0),
  'brand': Color(0xFF958BF7),
  'brandInk': Color(0xFFC8C2FF),
  'brandSoft': Color(0xFF272350),
  'owe': Color(0xFFFF8D73),
  'oweInk': Color(0xFFFFB7A6),
  'oweSoft': Color(0xFF3B1F18),
  'owed': Color(0xFF4FCB9C),
  'owedInk': Color(0xFF93E5C4),
  'owedSoft': Color(0xFF12302A),
  'settled': Color(0xFFB3B7BF),
  'settledSoft': Color(0xFF25262B),
  'pending': Color(0xFFF2B655),
  'pendingSoft': Color(0xFF3A2D12),
  'personal': Color(0xFF43C9B5),
  'personalInk': Color(0xFF8AE2D5),
  'personalSoft': Color(0xFF11302C),
  'adminBand': Color(0xFFFFC933),
  'adminInk': Color(0xFF1B1403),
  'adminSoft': Color(0xFF2E2610),
  'onFill': Color(0xFF111215),
};
