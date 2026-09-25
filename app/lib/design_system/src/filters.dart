import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/theme.dart';
import 'category_selector.dart';
import 'sk_icon.dart';

/// 34px filter pill: "Unsettled only" (selected) or "All groups ▾" (menu trigger).
class SkFilterChip extends StatelessWidget {
  const SkFilterChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.dropdown = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? SkColors.brandInk : SkColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? SkColors.brandSoft : SkColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? SkColors.brand : SkColors.line, width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: SkText.body(13, selected ? 700 : 600, color: fg)),
                  if (dropdown) ...[const SizedBox(width: 4), SkIcon('down', size: 14, color: fg)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of options where several can be on at once ("All" clears the rest).
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.allLabel,
    this.accent = ChipAccent.personal,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// If set, a leading chip that is on when nothing else is.
  final String? allLabel;
  final ChipAccent accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (allLabel != null)
          SelectableChip(label: allLabel!, selected: selected.isEmpty, accent: accent, onTap: () => onChanged({})),
        for (final o in options)
          SelectableChip(
            label: o,
            selected: selected.contains(o),
            accent: accent,
            onTap: () => onChanged(selected.contains(o) ? ({...selected}..remove(o)) : {...selected, o}),
          ),
      ],
    );
  }
}

/// Date or date-range trigger: calendar icon, bold label, ink border ("1 – 23 Sep").
class DateSelector extends StatelessWidget {
  const DateSelector({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static String rangeLabel(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} – ${end.day} ${DateFormat.MMM().format(end)}';
    }
    return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Dates: $label',
      child: Material(
        color: SkColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: SkColors.ink, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ExcludeSemantics(
            child: SizedBox(
              height: 34,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SkIcon('calendar', size: 16),
                    const SizedBox(width: 6),
                    Text(label, style: SkText.body(13, 700)),
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

/// Calendar grid: 7 columns, 40px cells, radius 10, selected day filled indigo.
class MiniCalendar extends StatelessWidget {
  /// Every day of [month], Monday first.
  MiniCalendar.month({super.key, required DateTime month, required this.selected, this.onSelected, this.width = 320})
    : days = _monthDays(month),
      dimOutside = month.month;

  /// One week (Mon–Sun) containing [day].
  MiniCalendar.week({super.key, required DateTime day, required this.selected, this.onSelected, this.width = 320})
    : days = [for (var i = 0; i < 7; i++) DateTime(day.year, day.month, day.day - (day.weekday - 1) + i)],
      dimOutside = null;

  final List<DateTime> days;
  final DateTime? selected;
  final ValueChanged<DateTime>? onSelected;
  final double width;
  final int? dimOutside;

  static List<DateTime> _monthDays(DateTime month) {
    final first = DateTime(month.year, month.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final last = DateTime(month.year, month.month + 1, 0);
    final end = last.add(Duration(days: 7 - last.weekday));
    return [for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) d];
  }

  bool _same(DateTime a, DateTime? b) => b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    const headers = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final cells = <Widget>[
      for (final h in headers)
        Center(
          child: Text(h, style: SkText.body(13, 700, color: SkColors.ink2)),
        ),
      for (final d in days) _day(d),
    ];
    return SizedBox(
      width: width,
      child: GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          mainAxisExtent: 40,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cells,
      ),
    );
  }

  Widget _day(DateTime d) {
    final on = _same(d, selected);
    final outside = dimOutside != null && d.month != dimOutside;
    return Semantics(
      button: onSelected != null,
      selected: on,
      label: DateFormat.yMMMMd().format(d),
      child: Material(
        color: on ? SkColors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected == null ? null : () => onSelected!(d),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                '${d.day}',
                style: SkText.body(
                  13,
                  500,
                  color: on
                      ? Colors.white
                      : outside
                      ? SkColors.ink3
                      : SkColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
