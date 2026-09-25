import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'sk_icon.dart';

/// A category as it comes from the categories table.
class CategoryOption {
  const CategoryOption({required this.key, required this.label, required this.icon});
  final String key;
  final String label;
  final String icon;
}

/// Colour of the selected state. Group screens use indigo, personal screens teal.
enum ChipAccent {
  brand(SkColors.brand, SkColors.brandSoft, SkColors.brandInk),
  personal(SkColors.personal, SkColors.personalSoft, SkColors.personalInk);

  const ChipAccent(this.border, this.background, this.foreground);
  final Color border;
  final Color background;
  final Color foreground;
}

/// Single-choice category chips (Add split). Renders whatever categories it is given.
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.accent = ChipAccent.brand,
  });

  final List<CategoryOption> categories;
  final String? selected;
  final ValueChanged<String> onSelected;
  final ChipAccent accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          SelectableChip(
            label: c.label,
            icon: c.icon,
            selected: c.key == selected,
            accent: accent,
            onTap: () => onSelected(c.key),
          ),
      ],
    );
  }
}

/// 36px chip used for categories and history filters.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accent = ChipAccent.brand,
  });

  final String label;
  final String? icon;
  final bool selected;
  final VoidCallback onTap;
  final ChipAccent accent;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? accent.foreground : SkColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? accent.background : SkColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? accent.border : SkColors.line, width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ExcludeSemantics(
            child: SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[SkIcon(icon!, size: 16, color: fg), const SizedBox(width: 6)],
                    Text(label, style: SkText.body(13, 600, color: fg)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
