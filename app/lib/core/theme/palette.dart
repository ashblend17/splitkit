import 'dart:ui';

import 'tokens.g.dart';

/// Colours used in the mockups that are not in tokens.json. Kept here, named by role,
/// so widgets never hard-code hex values.
abstract final class SkPalette {
  static const divider = Color(0xFFF0EEE8); // row separators inside cards
  static const tableHead = Color(0xFFFAF9F6); // desktop table header and row hover
  static const brandHover = Color(0xFF2A1F8F);
  static const dangerBorder = Color(0xFFE7B7A9); // Delete button, error card
  static const validBorder = Color(0xFF9FD6BD); // valid split summary
  static const warnBorder = Color(0xFFE8C27A); // incomplete split summary
  static const brandTint = Color(0xFFC9C3F2); // space swatches, dashed analytics frame
  static const brandWash = Color(0xFFF7F5FE); // analytics placeholder, highlighted row
  static const chartBar = Color(0xFFB9B2EE);
  static const chartBarAlt = Color(0xFF6A5FD6);
  static const scrim = Color(0xFF7C7D80); // backdrop behind dialogs / sheets in the gallery
  static const adminBorder = Color(0xFFE8B820);
  static const adminDivider = Color(0xFFF3E7BF);
  static const adminMuted = Color(0xFF5C4A12);
  static const adminText = Color(0xFF3D3210);
  static const importWarn = Color(0xFFE0A030);
  static const importWarnWash = Color(0xFFFFFBF1);
  static const pendingInk = Color(0xFF6B4100);
  static const shadowInk = Color(0x1F15171C); // rgba(21,23,28,0.12)
  static const fabShadow = Color(0x594636C9); // rgba(70,54,201,0.35)
}

/// Avatar background/foreground pairs from the mockups (AC, RS, AV, VI, PN, KM).
abstract final class SkAvatarColors {
  static const pairs = <(Color, Color)>[
    (Color(0xFFE4E0FB), Color(0xFF3326A8)),
    (Color(0xFFFDE7D9), Color(0xFF9A3B0B)),
    (Color(0xFFDDF0E7), Color(0xFF0B6B45)),
    (Color(0xFFE0EEF9), Color(0xFF1E5A8C)),
    (Color(0xFFF8E1EE), Color(0xFF8C2361)),
    (Color(0xFFEFEBDD), Color(0xFF6A5712)),
  ];

  /// The "+3" overflow bubble.
  static const overflow = (SkColors.sunken, SkColors.ink2);

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
  owe(SkColors.owe, SkColors.oweSoft, SkColors.owe),
  owed(SkColors.owed, SkColors.owedSoft, SkColors.owed),
  settled(SkColors.ink3, SkColors.settledSoft, SkColors.settled),
  settle(SkColors.brand, SkColors.brandSoft, SkColors.brand),
  income(SkColors.owed, SkColors.owedSoft, SkColors.owed),
  expense(SkColors.ink, SkColors.personalSoft, SkColors.personalInk),
  neutral(SkColors.ink3, SkColors.sunken, SkColors.ink2);

  const MoneyTone(this.fg, this.tileBg, this.tileFg);

  /// Amount and label colour.
  final Color fg;

  /// Icon tile background and foreground on transaction cards.
  final Color tileBg;
  final Color tileFg;

  /// owe / owed / settled for a net amount (positive = you are owed).
  static MoneyTone forNet(int netMinor) => netMinor > 0
      ? owed
      : netMinor < 0
      ? owe
      : settled;
}
