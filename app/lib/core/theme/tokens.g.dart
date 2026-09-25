// GENERATED from splitkit-design/tokens.json by tool/gen_tokens.py. Do not edit.
// ignore_for_file: constant_identifier_names

import 'dart:ui';

enum SkFamily { display, body }

class SkTypeToken {
  const SkTypeToken({required this.size, required this.weight, required this.family});
  final double size;
  final int weight;
  final SkFamily family;
}

abstract final class SkColors {
  static const paper = Color(0xFFF4F3EF);
  static const surface = Color(0xFFFFFFFF);
  static const sunken = Color(0xFFECEAE3);
  static const line = Color(0xFFE3E0D8);
  static const lineStrong = Color(0xFFD6D3CA);
  static const ink = Color(0xFF15171C);
  static const ink2 = Color(0xFF4B505A);
  static const ink3 = Color(0xFF686D76);
  static const brand = Color(0xFF4636C9);
  static const brandInk = Color(0xFF3A2DB0);
  static const brandSoft = Color(0xFFECE9FB);
  static const owe = Color(0xFFB93A1F);
  static const oweInk = Color(0xFF8E2B15);
  static const oweSoft = Color(0xFFFBE9E3);
  static const owed = Color(0xFF0A7550);
  static const owedInk = Color(0xFF075C3F);
  static const owedSoft = Color(0xFFE1F3EA);
  static const settled = Color(0xFF4B505A);
  static const settledSoft = Color(0xFFECEAE3);
  static const pending = Color(0xFF8A5300);
  static const pendingSoft = Color(0xFFFCEFD6);
  static const personal = Color(0xFF0E8A7A);
  static const personalInk = Color(0xFF0B6E62);
  static const personalSoft = Color(0xFFDDF1EE);
  static const adminBand = Color(0xFFFFC933);
  static const adminInk = Color(0xFF1B1403);
  static const adminSoft = Color(0xFFFFF6D9);
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

/// Every colour token by name, for tests and the gallery.
const skColorTokens = <String, Color>{
  'paper': SkColors.paper,
  'surface': SkColors.surface,
  'sunken': SkColors.sunken,
  'line': SkColors.line,
  'lineStrong': SkColors.lineStrong,
  'ink': SkColors.ink,
  'ink2': SkColors.ink2,
  'ink3': SkColors.ink3,
  'brand': SkColors.brand,
  'brandInk': SkColors.brandInk,
  'brandSoft': SkColors.brandSoft,
  'owe': SkColors.owe,
  'oweInk': SkColors.oweInk,
  'oweSoft': SkColors.oweSoft,
  'owed': SkColors.owed,
  'owedInk': SkColors.owedInk,
  'owedSoft': SkColors.owedSoft,
  'settled': SkColors.settled,
  'settledSoft': SkColors.settledSoft,
  'pending': SkColors.pending,
  'pendingSoft': SkColors.pendingSoft,
  'personal': SkColors.personal,
  'personalInk': SkColors.personalInk,
  'personalSoft': SkColors.personalSoft,
  'adminBand': SkColors.adminBand,
  'adminInk': SkColors.adminInk,
  'adminSoft': SkColors.adminSoft,
};
