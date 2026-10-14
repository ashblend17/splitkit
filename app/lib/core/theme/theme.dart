import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.g.dart';
import 'typography.dart';

export 'palette.dart';
export 'tokens.g.dart';
export 'typography.dart';

/// Material theme built from the colour set in use ([SkColors.current]). Splitkit widgets style
/// themselves from the tokens directly; this makes stock Material pieces (text fields, dialogs,
/// pickers) match.
ThemeData buildSplitkitTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SkColors.brand,
    brightness: SkColors.isDark ? Brightness.dark : Brightness.light,
    primary: SkColors.brand,
    onPrimary: SkColors.onFill,
    secondary: SkColors.personal,
    error: SkColors.owe,
    surface: SkColors.surface,
    onSurface: SkColors.ink,
    onSurfaceVariant: SkColors.ink2,
    outline: SkColors.lineStrong,
    outlineVariant: SkColors.line,
  );

  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(SkRadius.button),
    borderSide: BorderSide(color: color, width: 1.5),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: SkColors.paper,
    fontFamily: SkText.bodyFamily,
    textTheme: TextTheme(
      displaySmall: SkText.amountHero,
      headlineMedium: SkText.title,
      titleLarge: SkText.section,
      bodyLarge: SkText.bodyText,
      bodyMedium: SkText.body(15, 400),
      labelLarge: SkText.body(15, 700),
      labelMedium: SkText.label,
      bodySmall: SkText.caption,
    ),
    dividerTheme: DividerThemeData(color: SkColors.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SkColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: SkText.body(15, 400, color: SkColors.ink3),
      errorStyle: SkText.body(12, 500, color: SkColors.owe),
      border: border(SkColors.lineStrong),
      enabledBorder: border(SkColors.lineStrong),
      focusedBorder: border(SkColors.brand),
      errorBorder: border(SkColors.owe),
      focusedErrorBorder: border(SkColors.owe),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: SkColors.brand, selectionColor: SkColors.brandSoft),
    dialogTheme: DialogThemeData(
      backgroundColor: SkColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: SkColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: SkColors.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: SkColors.brand,
      headerForegroundColor: SkColors.onFill,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SkColors.ink,
      contentTextStyle: SkText.body(14, 600, color: SkColors.onFill),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SkRadius.button)),
    ),
    splashFactory: InkSparkle.splashFactory,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// The amber frame colour drawn around the viewport in admin mode.
Color get skAdminFrameColor => SkColors.adminBand;

/// Divider inside cards (lighter than [SkColors.line]).
Color get skCardDivider => SkPalette.divider;
