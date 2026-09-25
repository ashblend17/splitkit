import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/api/api.dart';
import '../../core/data/providers.dart' show fetch;
import '../../core/session/session.dart';

/// A Tricount export the user picked: its name and bytes. The preview is stateless, so the
/// same bytes are sent again on commit.
class TricountFile {
  const TricountFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;

  String get sizeLabel {
    final kb = bytes.length / 1024;
    return kb < 1 ? '${bytes.length} B' : kb < 1024 ? '${kb.ceil()} KB' : '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

/// The import endpoints. Upload and commit are multipart, which the generated client only
/// takes as a String, so they are posted here with package:http through the same client,
/// base path and auth header; the rest use the generated [ImportApi].
class ImportClient {
  ImportClient(this.api);
  final Api api;

  late final _generated = ImportApi(api.client);

  Future<ImportPreviewOut> preview(TricountFile file, {String? groupId, String? currency}) async {
    final json = await _multipart('/api/v1/import/tricount/preview', file, {
      'group_id': ?groupId,
      'currency': ?currency,
    });
    return ImportPreviewOut.fromJson(json)!;
  }

  /// `options` is the API's ImportCommitIn: a target (`group_id` or `new_group`), `people`
  /// and `categories`.
  Future<ImportBatchOut> commit(TricountFile file, Map<String, Object?> options) async {
    final json = await _multipart('/api/v1/import/tricount/commit', file, {'options': jsonEncode(options)});
    return ImportBatchOut.fromJson(json)!;
  }

  Future<ImportBatchOut> batch(String id) async => (await _generated.getImportBatch(id))!;

  Future<ImportBatchOut> undo(String id) async => (await _generated.undoImportBatch(id))!;

  Future<Object?> _multipart(String path, TricountFile file, Map<String, String> fields) async {
    final request = http.MultipartRequest('POST', Uri.parse('${api.client.basePath}$path'))
      ..headers.addAll(api.client.defaultHeaderMap)
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes('file', file.bytes, filename: file.name));
    final response = await http.Response.fromStream(await api.client.client.send(request));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 400) throw ApiException(response.statusCode, body);
    return jsonDecode(body);
  }
}

final importClientProvider = Provider<ImportClient>((ref) => ImportClient(ref.watch(apiProvider)));

/// Opens the system file picker (web, Android, iOS). Replaced in tests.
final pickTricountFileProvider = Provider<Future<TricountFile?> Function()>(
  (_) => () async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    final picked = result?.files.firstOrNull;
    if (picked == null || picked.bytes == null) return null;
    return TricountFile(picked.name, picked.bytes!);
  },
);

final importBatchProvider = FutureProvider.family<ImportBatchOut, String>(
  (ref, id) => fetch(ref, ref.watch(importClientProvider).batch(id)),
);
