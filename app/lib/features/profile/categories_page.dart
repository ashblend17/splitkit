import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

const _scopeLabels = {'all': 'Groups and personal', 'group': 'Groups only', 'personal': 'Personal only'};

/// Categories come from the categories table: built-in ones plus your own.
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allCategoriesProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: HeaderIconButton(
                            glyph: 'back',
                            label: 'Back to profile',
                            onPressed: () => context.go('/profile'),
                          ),
                        ),
                        Expanded(
                          child: Semantics(header: true, child: Text('Categories', style: SkText.display(20, 700))),
                        ),
                        SkButton(
                          'Add',
                          icon: 'plus',
                          variant: SkButtonVariant.strong,
                          size: SkButtonSize.small,
                          onPressed: () =>
                              showAppBottomSheet<void>(context, title: 'New category', child: const _NewCategory()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AsyncBody(
                    value: categories,
                    onRetry: () => ref.invalidate(allCategoriesProvider),
                    builder: (all) {
                      final mine = all.where((c) => c.ownerId != null).toList();
                      final builtIn = all.where((c) => c.ownerId == null).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (mine.isNotEmpty) ...[
                            const Overline('Yours'),
                            const SizedBox(height: 8),
                            _list(context, ref, mine, deletable: true),
                            const SizedBox(height: 16),
                          ],
                          const Overline('Built in'),
                          const SizedBox(height: 8),
                          _list(context, ref, builtIn, deletable: false),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, List<CategoryOut> cats, {required bool deletable}) => SkCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (i, c) in cats.indexed)
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: i == cats.length - 1 ? null : const Border(bottom: BorderSide(color: SkPalette.divider)),
            ),
            child: Row(
              children: [
                IconTile(
                  glyphOr(c.icon),
                  background: SkColors.sunken,
                  foreground: SkColors.ink,
                  size: 32,
                  radius: 8,
                  iconSize: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.label, style: SkText.body(15, 600)),
                      Text(_scopeLabels[c.scope] ?? c.scope, style: SkText.body(12, 400, color: SkColors.ink2)),
                    ],
                  ),
                ),
                if (deletable)
                  HeaderIconButton(
                    glyph: 'trash',
                    label: 'Delete ${c.label}',
                    color: SkColors.owe,
                    onPressed: () => _delete(context, ref, c),
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  Future<void> _delete(BuildContext context, WidgetRef ref, CategoryOut c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete “${c.label}”?',
      body: 'Only possible while nothing uses it.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).categories.deleteCategory(c.id);
      ref.invalidate(allCategoriesProvider);
      ref.invalidate(personalCategoriesProvider);
      ref.invalidate(groupCategoriesProvider);
    } catch (e) {
      if (context.mounted) showMessage(context, apiErrorMessage(e));
    }
  }
}

const _icons = [
  'other',
  'food',
  'transport',
  'shopping',
  'entertainment',
  'bills',
  'health',
  'education',
  'rent',
  'travel',
  'income',
  'groups',
];

class _NewCategory extends ConsumerStatefulWidget {
  const _NewCategory();

  @override
  ConsumerState<_NewCategory> createState() => _NewCategoryState();
}

class _NewCategoryState extends ConsumerState<_NewCategory> {
  final _label = TextEditingController();
  String _icon = 'other';
  String _scope = 'all';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_label.text.trim().isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(apiProvider)
          .categories
          .createCategory(
            CategoryIn(label: _label.text.trim(), icon: _icon, scope: CategoryInScopeEnum.fromJson(_scope)!),
          );
      ref.invalidate(allCategoriesProvider);
      ref.invalidate(personalCategoriesProvider);
      ref.invalidate(groupCategoriesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkTextField(label: 'Name', controller: _label, hint: 'Pets, gym, gifts…', autofocus: true, errorText: _error),
          const SizedBox(height: 14),
          Text('Icon', style: SkText.body(13, 600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in _icons)
                Semantics(
                  button: true,
                  selected: g == _icon,
                  label: g,
                  child: InkWell(
                    onTap: () => setState(() => _icon = g),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: g == _icon ? SkColors.brandSoft : SkColors.paper,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: g == _icon ? SkColors.brand : Colors.transparent, width: 1.5),
                      ),
                      child: Center(child: SkIcon(g, size: 20, color: g == _icon ? SkColors.brandInk : SkColors.ink)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Use for', style: SkText.body(13, 600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(:key, :value) in _scopeLabels.entries)
                SelectableChip(label: value, selected: _scope == key, onTap: () => setState(() => _scope = key)),
            ],
          ),
          const SizedBox(height: 18),
          SkButton(
            _busy ? 'Adding…' : 'Add category',
            size: SkButtonSize.large,
            expand: true,
            onPressed: _busy ? null : _create,
          ),
        ],
      ),
    );
  }
}
