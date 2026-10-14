import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/theme/theme.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// The colour the "Hi, John" greeting is drawn in.
Color? _greeting(WidgetTester tester) => tester.widget<Text>(find.text('Hi, John')).style?.color;

void main() {
  setUpAll(loadFonts);
  tearDown(() => SkColors.current = skLightColors);

  testWidgets('Appearance switches to dark and back, everywhere at once', (tester) async {
    final themes = MemoryThemeStore();
    await pumpApp(tester, location: '/profile', themes: themes);
    expect(find.text('As the device'), findsOneWidget);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(SkColors.isDark, isTrue);
    expect(themes.mode, ThemeMode.dark); // remembered on this device
    expect(find.text('Dark'), findsOneWidget); // the row says so; still on Profile

    // Pages built before the switch and after it are both dark.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(_greeting(tester), skDarkColors.ink);
    expect(Theme.of(tester.element(find.text('Hi, John'))).scaffoldBackgroundColor, skDarkColors.paper);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(SkColors.isDark, isFalse);
  });

  testWidgets("as the device: follows the phone's own setting", (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    expect(_greeting(tester), skLightColors.ink);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(_greeting(tester), skDarkColors.ink);
  });

  testWidgets('a saved choice applies before the first frame', (tester) async {
    await pumpApp(tester, theme: ThemeMode.dark);
    expect(_greeting(tester), skDarkColors.ink);
  });
}
