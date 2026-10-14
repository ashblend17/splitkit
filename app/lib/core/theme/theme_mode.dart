import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Light, dark, or as the phone or browser is set ([ThemeMode.system], the default). Kept on
/// this device only: a phone and a laptop can differ.
class ThemeModeStore {
  static const _key = 'splitkit.theme';

  Future<ThemeMode?> read() async => ThemeMode.values.asNameMap()[(await SharedPreferences.getInstance()).getString(_key)];
  Future<void> write(ThemeMode mode) async => (await SharedPreferences.getInstance()).setString(_key, mode.name);
}

final themeModeStoreProvider = Provider<ThemeModeStore>((_) => ThemeModeStore());

/// The theme mode saved last time, read once in main() before the app starts.
final savedThemeModeProvider = Provider<ThemeMode>((_) => ThemeMode.system);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(savedThemeModeProvider);

  void set(ThemeMode mode) {
    if (mode == state) return;
    state = mode;
    ref.read(themeModeStoreProvider).write(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// MaterialApp.router in the colours of [themeModeProvider]. Widgets read [SkColors] directly,
/// not the Material theme, so when light and dark swap (the setting, or the phone's own switch
/// under "system") the colour set changes and every widget is rebuilt, keeping its state.
class SkThemedApp extends ConsumerStatefulWidget {
  const SkThemedApp({super.key, required this.routerConfig, this.title = '', this.builder});

  final RouterConfig<Object> routerConfig;
  final String title;
  final TransitionBuilder? builder;

  @override
  ConsumerState<SkThemedApp> createState() => _SkThemedAppState();
}

class _SkThemedAppState extends ConsumerState<SkThemedApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apply(ref.read(themeModeProvider), rebuild: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _apply(ref.read(themeModeProvider));

  void _apply(ThemeMode mode, {bool rebuild = true}) {
    final dark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
    };
    final colors = dark ? skDarkColors : skLightColors;
    if (identical(colors, SkColors.current)) return;
    SkColors.current = colors;
    if (!rebuild || !mounted) return;
    setState(() {});
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(themeModeProvider, (_, mode) => _apply(mode));
    return MaterialApp.router(
      title: widget.title,
      debugShowCheckedModeBanner: false,
      theme: buildSplitkitTheme(),
      routerConfig: widget.routerConfig,
      // Status bar icons that show on the page behind them (the app draws its own headers).
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SkColors.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: widget.builder?.call(context, child) ?? child!,
      ),
    );
  }
}
