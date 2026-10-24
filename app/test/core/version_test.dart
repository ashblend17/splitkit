import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config.dart';
import 'package:app/core/version.dart';

import '../fake_backend.dart';

void main() {
  test("the app's version is pubspec.yaml's (tool/version.py bumps both)", () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\s*$', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(AppVersion.name, version);
    expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(AppVersion.name), isTrue, reason: 'semantic versioning');
  });

  testWidgets("Profile says which app and which server you're on", (tester) async {
    await pumpApp(tester, location: '/profile', size: const Size(390, 2000));
    expect(find.text('${AppConfig.appName} ${AppVersion.name} · server 1.0.0'), findsOneWidget);
  });
}
