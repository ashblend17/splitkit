import 'dart:ui';

import 'tokens.g.dart';

/// Colours used in the mockups that are not in tokens.json. Kept here, named by role,
/// so widgets never hard-code hex values. Each has a light and a dark value.
abstract final class SkPalette {
  static Color _pick(int light, int dark) => Color(SkColors.isDark ? dark : light);

  static Color get divider => _pick(0xFFF0EEE8, 0xFF25262B); // row separators inside cards
  static Color get tableHead => _pick(0xFFFAF9F6, 0xFF212227); // desktop table header and row hover
  static Color get brandHover => _pick(0xFF2A1F8F, 0xFFB2AAFA);
  static Color get dangerBorder => _pick(0xFFE7B7A9, 0xFF6E3628); // Delete button, error card
  static Color get validBorder => _pick(0xFF9FD6BD, 0xFF2D6B54); // valid split summary
  static Color get warnBorder => _pick(0xFFE8C27A, 0xFF6D5424); // incomplete split summary
  static Color get brandTint => _pick(0xFFC9C3F2, 0xFF4A4390); // space swatches, dashed analytics frame
  static Color get brandWash => _pick(0xFFF7F5FE, 0xFF1F1D33); // analytics placeholder, highlighted row
  static Color get chartBar => _pick(0xFFB9B2EE, 0xFF5B52B8);
  static Color get chartBarAlt => _pick(0xFF6A5FD6, 0xFF9C93F8);
  static Color get scrim => _pick(0xFF7C7D80, 0xFF050506); // backdrop behind dialogs / sheets in the gallery
  // The admin band is amber in both modes, so what sits on it stays the same.
  static const adminBorder = Color(0xFFE8B820);
  static const adminDivider = Color(0xFFF3E7BF);
  static const adminMuted = Color(0xFF5C4A12);
  static const adminText = Color(0xFF3D3210);
  static Color get importWarn => _pick(0xFFE0A030, 0xFFE8B04A);
  static Color get importWarnWash => _pick(0xFFFFFBF1, 0xFF2B2410);
  static Color get pendingInk => _pick(0xFF6B4100, 0xFFF7CC85);
  static Color get shadowInk => _pick(0x1F15171C, 0x66000000); // rgba(21,23,28,0.12)
  static Color get fabShadow => _pick(0x594636C9, 0x66000000); // rgba(70,54,201,0.35)
}

/// Avatar background/foreground pairs from the mockups (AC, RS, AV, VI, PN, KM), and their
/// dark counterparts in the same order, so a person keeps their colour across modes.
abstract final class SkAvatarColors {
  static const _light = <(Color, Color)>[
    (Color(0xFFE4E0FB), Color(0xFF3326A8)),
    (Color(0xFFFDE7D9), Color(0xFF9A3B0B)),
    (Color(0xFFDDF0E7), Color(0xFF0B6B45)),
    (Color(0xFFE0EEF9), Color(0xFF1E5A8C)),
    (Color(0xFFF8E1EE), Color(0xFF8C2361)),
    (Color(0xFFEFEBDD), Color(0xFF6A5712)),
  ];
  static const _dark = <(Color, Color)>[
    (Color(0xFF2E2A5C), Color(0xFFC9C2FF)),
    (Color(0xFF4A2A1A), Color(0xFFFFC3A0)),
    (Color(0xFF183A2D), Color(0xFF9BE3C2)),
    (Color(0xFF1A3248), Color(0xFFA8D2F5)),
    (Color(0xFF452036), Color(0xFFF5B5D8)),
    (Color(0xFF3A3420), Color(0xFFE8D59A)),
  ];

  static List<(Color, Color)> get pairs => SkColors.isDark ? _dark : _light;

  /// The "+3" overflow bubble.
  static (Color, Color) get overflow => (SkColors.sunken, SkColors.ink2);

  /// A stable colour pair for a person, derived from their id (FNV-1a), so the same
  /// person always gets the same colour on every screen and device.
  static (Color, Color) forId(String id) {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return pairs[hash % pairs.length];
  }
}

/// The money vocabulary: every amount is shown in one of these tones, always next to words.
enum MoneyTone {
  owe,
  owed,
  settled,
  settle,
  income,
  expense,
  neutral;

  /// Amount and label colour.
  Color get fg => switch (this) {
    owe => SkColors.owe,
    owed || income => SkColors.owed,
    settled || neutral => SkColors.ink3,
    settle => SkColors.brand,
    expense => SkColors.ink,
  };

  /// Icon tile background and foreground on transaction cards.
  Color get tileBg => switch (this) {
    owe => SkColors.oweSoft,
    owed || income => SkColors.owedSoft,
    settled => SkColors.settledSoft,
    settle => SkColors.brandSoft,
    expense => SkColors.personalSoft,
    neutral => SkColors.sunken,
  };

  Color get tileFg => switch (this) {
    owe => SkColors.owe,
    owed || income => SkColors.owed,
    settled => SkColors.settled,
    settle => SkColors.brand,
    expense => SkColors.personalInk,
    neutral => SkColors.ink2,
  };

  /// owe / owed / settled for a net amount (positive = you are owed).
  static MoneyTone forNet(int netMinor) => netMinor > 0
      ? owed
      : netMinor < 0
      ? owe
      : settled;
}
