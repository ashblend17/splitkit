import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

/// Line icons from designs/Icon.dc.html: 24-unit grid, 1.8 stroke, round caps and joins.
/// [glyph] is a plain string because category icons come from the categories table;
/// unknown names fall back to "other".
class SkIcon extends StatelessWidget {
  const SkIcon(this.glyph, {super.key, this.size = 24, this.color, this.semanticLabel});

  final String glyph;
  final double size;
  final Color? color;
  final String? semanticLabel;

  static final names = List<String>.unmodifiable(_paths.keys);

  static bool has(String glyph) => _paths.containsKey(glyph);

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF15171C);
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconPainter(_parsed(glyph), color)),
    );
    return semanticLabel == null ? ExcludeSemantics(child: icon) : Semantics(label: semanticLabel, child: icon);
  }

  static final _cache = <String, Path>{};

  static Path _parsed(String glyph) =>
      _cache.putIfAbsent(glyph, () => parseSvgPathData(_paths[glyph] ?? _paths['other']!));
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.path != path || old.color != color;
}

/// A full circle as SVG path data, like the `c(x, y, r)` helper in Icon.dc.html.
String _c(num x, num y, num r) => 'M${x - r} ${y}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0';

final _paths = <String, String>{
  'food': 'M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2M7 2v20M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3v7',
  'transport': 'M5 17h14v-5l-2-5H7l-2 5zM5 17v2M19 17v2M8 13h.01M16 13h.01M5 12h14',
  'shopping': 'M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4ZM3 6h18M16 10a4 4 0 0 1-8 0',
  'entertainment':
      'M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2ZM13 5v2M13 17v2M13 11v2',
  'bills': 'M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1ZM16 8H8M16 12H8M13 16H8',
  'rent': 'M3 10 12 3l9 7v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM9 22V12h6v10',
  'travel':
      'M17.8 19.2 16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z',
  'health':
      'M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7ZM3.5 12h4l2-3 3 6 2-3h6',
  'education': 'M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20',
  'other': '${_c(12, 12, 10)}M8 12h.01M12 12h.01M16 12h.01',
  'settle': 'M8 3 4 7l4 4M4 7h16M16 21l4-4-4-4M20 17H4',
  'income': 'M22 7 13.5 15.5 8.5 10.5 2 17M16 7h6v6',
  'home': 'M3 10 12 3l9 7v10a2 2 0 0 1-2 2h-4v-7H9v7H5a2 2 0 0 1-2-2z',
  'groups': '${_c(9, 7, 4)}M2 21v-2a4 4 0 0 1 4-4h6a4 4 0 0 1 4 4v2M16 3.1a4 4 0 0 1 0 7.8M22 21v-2a4 4 0 0 0-3-3.9',
  'wallet':
      'M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4',
  'user': '${_c(12, 8, 4.5)}M20 21a8 8 0 0 0-16 0',
  'shield':
      'M20 13c0 5-3.5 7.5-7.7 9a1 1 0 0 1-.6 0C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.2-2.7a1.2 1.2 0 0 1 1.6 0C14.5 3.8 17 5 19 5a1 1 0 0 1 1 1zM9 12l2 2 4-4',
  'plus': 'M12 5v14M5 12h14',
  'back': 'm15 18-6-6 6-6',
  'next': 'm9 18 6-6-6-6',
  'down': 'm6 9 6 6 6-6',
  'search': '${_c(11, 11, 7.5)}m21 21-4.3-4.3',
  'check': 'M20 6 9 17l-5-5',
  'alert': 'm21.7 18-8-14a2 2 0 0 0-3.5 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.7-3M12 9v4M12 17h.01',
  'upload': 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12',
  'filter': 'M22 3H2l8 9.5V19l4 2v-8.5z',
  'calendar': 'M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2zM16 2v4M8 2v4M3 10h18',
  'edit': 'M17 3a2.8 2.8 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z',
  'trash': 'M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2',
  'close': 'M18 6 6 18M6 6l12 12',
  'eye': 'M2 12s3-7 10-7 10 7 10 7-3 7-10 7S2 12 2 12Z${_c(12, 12, 3)}',
  'logout': 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9',
  'chart': 'M3 3v18h18M18 17V9M13 17V5M8 17v-3',
  'file': 'M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5ZM14 2v6h6M9 13h6M9 17h4',
  'refresh': 'M3 12a9 9 0 0 1 15.7-6L21 8M21 3v5h-5M21 12a9 9 0 0 1-15.7 6L3 16M8 16H3v5',
  'lock': 'M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2zM7 11V7a5 5 0 0 1 10 0v4',
  'link': 'M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7',
  'grid': 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z',
  'more': 'M12 5h.01M12 12h.01M12 19h.01',
  'swap': 'M7 16V4M3 8l4-4 4 4M17 8v12M21 16l-4 4-4-4',
};
