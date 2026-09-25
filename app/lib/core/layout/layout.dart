import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Window size classes from the handoff: tab bar under 600px, navigation rail from 600px,
/// sidebar with multi-column pages from 1280px.
enum SkLayout {
  compact,
  medium,
  expanded;

  static const railFrom = 600.0;
  static const sidebarFrom = SkBreakpoints.desktop;

  static SkLayout forWidth(double width) => width >= sidebarFrom
      ? expanded
      : width >= railFrom
      ? medium
      : compact;

  static SkLayout of(BuildContext context) => forWidth(MediaQuery.sizeOf(context).width);

  /// The rail and the sidebar have their own "Add split", so pages drop the floating one.
  bool get showsFab => this == compact;
}
