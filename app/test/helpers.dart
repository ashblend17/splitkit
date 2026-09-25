import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/theme/theme.dart';

/// Loads the bundled variable fonts so layout in tests matches the app (the default test
/// font is much wider and would report false overflows).
Future<void> loadFonts() async {
  for (final (family, file) in [
    (SkText.displayFamily, 'assets/fonts/BricolageGrotesque.ttf'),
    (SkText.bodyFamily, 'assets/fonts/InstrumentSans.ttf'),
  ]) {
    final bytes = File(file).readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  }
}

Widget wrap(Widget child) => MaterialApp(
  theme: buildSplitkitTheme(),
  home: Scaffold(
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child),
  ),
);

void setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
