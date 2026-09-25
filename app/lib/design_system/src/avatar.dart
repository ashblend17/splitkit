import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// "Ansh C" -> "AC", "Vivek Iyer" -> "VI", "Priya" -> "PR".
String initialsFor(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
  return (words.first[0] + words.last[0]).toUpperCase();
}

/// A person, as avatars and rows need them. [id] picks a stable colour pair.
class SkPerson {
  const SkPerson({required this.id, required this.name, String? initials, this.colors}) : _initials = initials;

  final String id;
  final String name;
  final String? _initials;
  final (Color, Color)? colors;

  String get initials => _initials ?? initialsFor(name);
  (Color, Color) get palette => colors ?? SkAvatarColors.forId(id);
}

class Avatar extends StatelessWidget {
  const Avatar(this.person, {super.key, this.size = 36, this.fontSize, this.ring, this.ringColor = SkColors.surface});

  final SkPerson person;
  final double size;
  final double? fontSize;

  /// Optional white ring, used in overlapping stacks.
  final double? ring;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = person.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: ring == null ? null : Border.all(color: ringColor, width: ring!),
      ),
      child: Text(
        person.initials,
        style: SkText.body(fontSize ?? (size * 0.34).roundToDouble(), 700, color: fg, height: 1),
        maxLines: 1,
        overflow: TextOverflow.clip,
        semanticsLabel: person.name,
      ),
    );
  }
}

/// Overlapping avatars (GroupList): 28px, 2px white ring, 6px overlap, "+N" overflow.
class AvatarStack extends StatelessWidget {
  const AvatarStack(
    this.people, {
    super.key,
    this.size = 28,
    this.max = 6,
    this.overlap = 6,
    this.ringColor = SkColors.surface,
  });

  final List<SkPerson> people;
  final double size;
  final int max;
  final double overlap;

  /// Match the background the stack sits on (white on cards, paper on pages).
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final shown = people.length > max ? people.take(max - 1).toList() : people;
    final extra = people.length - shown.length;
    final items = [
      for (final p in shown) Avatar(p, size: size, fontSize: size <= 26 ? 9 : 10, ring: 2, ringColor: ringColor),
      if (extra > 0)
        Avatar(
          SkPerson(id: '+', name: '+$extra', initials: '+$extra', colors: SkAvatarColors.overflow),
          size: size,
          fontSize: 10,
          ring: 2,
          ringColor: ringColor,
        ),
    ];
    final step = size - overlap;
    return Semantics(
      label: people.map((p) => p.name).join(', '),
      child: ExcludeSemantics(
        child: SizedBox(
          width: items.isEmpty ? 0 : step * (items.length - 1) + size,
          height: size,
          child: Stack(
            children: [for (var i = 0; i < items.length; i++) Positioned(left: step * i, top: 0, child: items[i])],
          ),
        ),
      ),
    );
  }
}
