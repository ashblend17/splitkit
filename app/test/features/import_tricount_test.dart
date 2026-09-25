import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:splitkit/core/router/router.dart';
import 'package:splitkit/core/session/session.dart';
import 'package:splitkit/core/theme/theme.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/import_tricount/import_api.dart';

import '../fake_backend.dart';
import '../helpers.dart';

const _json = {'content-type': 'application/json'};

/// FakeBackend for everything else, plus the import endpoints (multipart, which FakeBackend
/// doesn't read). Responses are real ones captured from the API: import_preview.json is the
/// mockup's Goa Trip file, import_batch.json its commit into a new group.
class _ImportBackend {
  final be = FakeBackend();
  final preview = fixture('import_preview') as Map<String, dynamic>;
  late Map<String, dynamic> batch = fixture('import_batch') as Map<String, dynamic>;
  final posts = <(String path, String body)>[];

  http.Response _ok(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: _json);

  http.Client get client => MockClient((req) async {
    final path = req.url.path;
    final id = batch['id'];
    if (req.method == 'POST' && path.startsWith('/api/v1/import/')) {
      posts.add((path, req.body));
      if (path.endsWith('/preview')) return _ok(preview);
      if (path.endsWith('/commit')) return _ok(batch, 201);
      if (path.endsWith('/$id/undo')) {
        batch = {...batch, 'undone_at': '2026-09-25T17:30:00Z'};
        return _ok(batch);
      }
    }
    if (req.method == 'GET' && path == '/api/v1/import/batches/$id') return _ok(batch);
    return req.method == 'GET'
        ? be.client.get(req.url, headers: req.headers)
        : be.client.post(req.url, headers: req.headers, body: req.body);
  });

  /// The `options` form field of the last commit.
  Map<String, dynamic> get commitOptions {
    final body = posts.lastWhere((p) => p.$1.endsWith('/commit')).$2;
    final match = RegExp(r'name="options"\r\n\r\n(.*?)\r\n--', dotAll: true).firstMatch(body)!;
    return jsonDecode(match.group(1)!) as Map<String, dynamic>;
  }
}

class _Tokens extends TokenStore {
  @override
  Future<String?> read() async => 'test-token';
  @override
  Future<void> write(String t) async {}
  @override
  Future<void> clear() async {}
}

Future<_ImportBackend> _pump(WidgetTester tester, {String location = '/profile', Size size = const Size(390, 844)}) async {
  final be = _ImportBackend();
  setViewport(tester, size);
  final container = ProviderContainer(
    overrides: [
      httpClientProvider.overrideWithValue(be.client),
      tokenStoreProvider.overrideWithValue(_Tokens()),
      pickTricountFileProvider.overrideWithValue(
        () async => TricountFile('tricount-goa-trip.csv', utf8.encode('Title,Amount\nTrain,6680\n')),
      ),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: buildSplitkitTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.go(location);
  await tester.pumpAndSettle();
  return be;
}

Finder _labelled(String label) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('Profile links to the importer', (tester) async {
    await _pump(tester);
    await _tapText(tester, 'Import from Tricount');
    expect(find.textContaining('Nothing is saved until you press Import.'), findsOneWidget);
    expect(find.text('Upload your Tricount export'), findsOneWidget);
  });

  testWidgets('upload reads the file and shows what was found', (tester) async {
    final be = await _pump(tester, location: '/profile/import');
    await _tapText(tester, 'Choose file');

    final (path, body) = be.posts.single;
    expect(path, '/api/v1/import/tricount/preview');
    expect(body, contains('filename="tricount-goa-trip.csv"'));
    expect(body, isNot(contains('name="group_id"')));

    expect(find.text('tricount-goa-trip.csv'), findsOneWidget);
    expect(find.text('6 people found'), findsOneWidget);
    expect(find.text('6 match existing users'), findsOneWidget);
    expect(find.text('17 expenses found'), findsOneWidget);
    expect(find.text('₹49,630 · 12 – 20 Sep'), findsOneWidget);
    expect(find.text('1 money transfer found'), findsOneWidget);
    expect(find.text('Needs a look'.toUpperCase()), findsOneWidget);
    expect(find.text('2 expenses with unsupported categories'), findsOneWidget);
    expect(find.text('Parking, Tips'), findsOneWidget);
    expect(find.text('2 rows can’t be imported'), findsOneWidget);
    // The group name comes from the file name.
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'Goa Trip');
  });

  testWidgets('choosing an existing group previews against its members', (tester) async {
    final be = await _pump(tester, location: '/profile/import');
    await _tapText(tester, 'Choose file');
    await tester.tap(find.widgetWithText(SelectableChip, 'Goa Trip'));
    await tester.pumpAndSettle();
    expect(be.posts, hasLength(2));
    expect(be.posts.last.$2, contains('name="group_id"\r\n\r\n${be.be.goa['id']}'));
  });

  testWidgets('review: mapping people and categories, then import', (tester) async {
    final be = await _pump(tester, location: '/profile/import');
    await _tapText(tester, 'Choose file');
    await _tapText(tester, 'Review');

    expect(find.text('Check before importing'), findsOneWidget);
    expect(find.text('6 of 6 matched'), findsOneWidget);
    expect(find.text('2 need a choice'), findsOneWidget);
    expect(find.text('Suggested'), findsNWidgets(5));
    expect(find.text('You'), findsOneWidget);
    // Parking and Tips are flagged until a category is chosen; skipped rows say why.
    expect(find.textContaining('Category “Parking”'), findsOneWidget);
    expect(find.textContaining('Skipped: ₹100 still needs to be allocated'), findsOneWidget);

    // Kabir becomes a placeholder member, as in the mockup.
    await tester.ensureVisible(_labelled('Match Kabir M.'));
    await tester.pumpAndSettle();
    await tester.tap(_labelled('Match Kabir M.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create placeholder member').last);
    await tester.pumpAndSettle();
    expect(find.text('5 of 6 matched'), findsOneWidget);
    expect(find.text('New placeholder'), findsOneWidget);
    expect(find.textContaining('Payer not matched'), findsWidgets);
    expect(find.textContaining('1 placeholder member for Kabir M.'), findsOneWidget);

    // Parking goes to Transport.
    await tester.ensureVisible(_labelled('Category for Parking'));
    await tester.pumpAndSettle();
    await tester.tap(_labelled('Category for Parking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();
    expect(find.text('1 need a choice'), findsOneWidget);
    expect(find.textContaining('Category “Parking”'), findsNothing);

    await tester.tap(find.text('Import 17 expenses'));
    await tester.pumpAndSettle();

    final options = be.commitOptions;
    expect(options['new_group'], {'name': 'Goa Trip', 'currency': 'INR'});
    final people = {for (final p in options['people'] as List) p['name']: p['user_id']};
    expect(people['Kabir M.'], isNull);
    expect(people['Ansh'], isNotNull);
    expect((options['categories'] as Map)['Parking'], 'transport');
    expect((options['categories'] as Map)['Tips'], 'other');

    expect(find.text('Import completed'), findsOneWidget);
    expect(find.text('Goa Trip is ready. Balances were recalculated from the imported splits.'), findsOneWidget);
  });

  testWidgets('done: stats, items to review and undo', (tester) async {
    final be = await _pump(tester, location: '/profile/import/done/${(fixture('import_batch') as Map)['id']}');
    expect(find.text('17'), findsOneWidget);
    expect(find.text('expenses imported'), findsOneWidget);
    expect(find.text('people matched'), findsOneWidget);
    expect(find.text('items need review'), findsOneWidget);
    expect(find.textContaining('paid by placeholder “Kabir M.”'), findsNWidgets(2)); // parasailing, dolphins
    expect(find.text('Open Goa Trip'), findsOneWidget);

    await _tapText(tester, 'Undo this import');
    expect(find.text('Undo this import?'), findsOneWidget);
    await _tapText(tester, 'Undo import');
    expect(be.posts.last.$1, endsWith('/undo'));
    expect(find.text('Import undone'), findsWidgets);
    expect(find.text('Undo this import'), findsNothing);
    expect(find.text('Back to profile'), findsOneWidget);
  });

  testWidgets('review without a file asks for one', (tester) async {
    await _pump(tester, location: '/profile/import/review');
    expect(find.text('Choose a file first'), findsOneWidget);
  });

  for (final size in const [Size(834, 1112), Size(1440, 900)]) {
    testWidgets('upload and review lay out at ${size.width.toInt()}px', (tester) async {
      await _pump(tester, location: '/profile/import', size: size);
      await _tapText(tester, 'Choose file');
      expect(find.text('What we found'), findsOneWidget);
      await _tapText(tester, 'Review');
      expect(find.text('Expenses with issues'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
