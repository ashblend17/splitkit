import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import 'import_api.dart';

/// Where the import goes: an existing group, or a new one with this name and currency.
class ImportTarget {
  const ImportTarget.newGroup({this.name = '', this.currency}) : groupId = null;
  const ImportTarget.group(String this.groupId) : name = '', currency = null;

  final String? groupId;
  final String name;
  final String? currency;

  bool get isNew => groupId == null;
}

/// Everything the upload and review screens decide, kept until the import is committed.
/// `people` maps a Tricount name to a user id here; null means "create a placeholder".
/// `categories` maps a Tricount category to a category key.
class ImportDraft {
  const ImportDraft({
    this.file,
    this.target = const ImportTarget.newGroup(),
    this.preview,
    this.people = const {},
    this.categories = const {},
    this.loading = false,
    this.error,
  });

  final TricountFile? file;
  final ImportTarget target;
  final ImportPreviewOut? preview;
  final Map<String, String?> people;
  final Map<String, String> categories;
  final bool loading;
  final String? error;

  ImportDraft copyWith({
    TricountFile? file,
    ImportTarget? target,
    ImportPreviewOut? preview,
    Map<String, String?>? people,
    Map<String, String>? categories,
    bool? loading,
    String? error,
    bool clearPreview = false,
  }) => ImportDraft(
    file: file ?? this.file,
    target: target ?? this.target,
    preview: clearPreview ? null : preview ?? this.preview,
    people: people ?? this.people,
    categories: categories ?? this.categories,
    loading: loading ?? this.loading,
    error: error,
  );

  /// The name the new group will get: what the user typed, else the file's suggestion.
  String get groupName => target.name.trim().isNotEmpty ? target.name.trim() : preview?.groupName ?? '';

  List<ImportRowOut> get importable => [
    for (final r in preview?.rows ?? const <ImportRowOut>[])
      if (!r.issues.any((i) => i.level == RowIssueOutLevelEnum.error)) r,
  ];

  /// Why a row needs a look, given the current choices; empty when it's ready.
  List<String> flags(ImportRowOut r) {
    final out = <String>[
      for (final i in r.issues) i.level == RowIssueOutLevelEnum.error ? 'Skipped: ${i.message}' : i.message,
    ];
    if (r.payer != null && people[r.payer] == null) out.add('Payer not matched');
    for (final s in r.shares) {
      if (r.payer != s.name && people[s.name] == null) out.add('${s.name} in split');
    }
    final category = r.category;
    if (category != null && suggestedCategory(category) == null && categories[category] == 'other') {
      out.add('Category “$category”');
    }
    return out;
  }

  String? suggestedCategory(String name) => preview?.categories.where((c) => c.name == name).firstOrNull?.key;

  Map<String, Object?> commitOptions() => {
    if (target.isNew)
      'new_group': {'name': groupName, 'currency': preview?.currency ?? 'INR'}
    else
      'group_id': target.groupId,
    'people': [
      for (final p in preview?.people ?? const <PersonOut>[]) {'name': p.name, 'user_id': people[p.name]},
    ],
    'categories': categories,
  };
}

class ImportFlow extends Notifier<ImportDraft> {
  @override
  ImportDraft build() => const ImportDraft();

  ImportClient get _client => ref.read(importClientProvider);

  Future<void> pick() async {
    final file = await ref.read(pickTricountFileProvider)();
    if (file == null) return;
    state = state.copyWith(file: file, clearPreview: true);
    await _preview();
  }

  void removeFile() => state = ImportDraft(target: state.target);

  Future<void> setTarget(ImportTarget target) async {
    final refetch = target.groupId != state.target.groupId || target.currency != state.target.currency;
    state = state.copyWith(target: target);
    if (refetch && state.file != null) await _preview();
  }

  void renameGroup(String name) =>
      state = state.copyWith(target: ImportTarget.newGroup(name: name, currency: state.target.currency));

  void mapPerson(String name, String? userId) => state = state.copyWith(people: {...state.people, name: userId});

  void mapCategory(String name, String key) => state = state.copyWith(categories: {...state.categories, name: key});

  Future<void> _preview() async {
    final file = state.file!;
    state = state.copyWith(loading: true);
    try {
      final p = await _client.preview(file, groupId: state.target.groupId, currency: state.target.currency);
      if (state.file != file) return; // replaced or removed meanwhile
      state = state.copyWith(
        preview: p,
        loading: false,
        people: {for (final x in p.people) x.name: x.user?.id},
        categories: {for (final c in p.categories) c.name: c.key ?? 'other'},
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: apiErrorMessage(e), clearPreview: true);
    }
  }

  /// Commits and returns the batch, or throws [ApiException] with a human message.
  Future<ImportBatchOut> commit() async {
    final batch = await _client.commit(state.file!, state.commitOptions());
    state = const ImportDraft();
    return batch;
  }
}

final importFlowProvider = NotifierProvider<ImportFlow, ImportDraft>(ImportFlow.new);

/// "12 – 20 Sep", "30 Aug – 2 Sep".
String dateRangeLabel(DateTime? first, DateTime? last) {
  if (first == null || last == null) return '';
  String d(DateTime x, {bool month = true}) => month ? '${x.day} ${shortMonth(x)}' : '${x.day}';
  if (first == last) return d(first);
  return first.month == last.month && first.year == last.year
      ? '${d(first, month: false)} – ${d(last)}'
      : '${d(first)} – ${d(last)}';
}

String shortMonth(DateTime d) =>
    const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1];

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : many ?? '${one}s'}';
