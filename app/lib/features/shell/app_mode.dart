import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/session/session.dart';
import '../../core/fixed_names.dart';

/// The app's two halves. Each has its own tabs, add button and accent colour; Profile (and
/// Admin) belong to both.
enum AppMode { split, personal }

/// Where a mode starts.
String homeOf(AppMode mode) => switch (mode) {
  AppMode.split => '/home',
  AppMode.personal => '/personal',
};

class AppModeStore {
  static const _key = FixedNames.mode;

  Future<AppMode?> read() async => AppMode.values.asNameMap()[(await SharedPreferences.getInstance()).getString(_key)];
  Future<void> write(AppMode mode) async => (await SharedPreferences.getInstance()).setString(_key, mode.name);
}

final appModeStoreProvider = Provider<AppModeStore>((_) => AppModeStore());

/// The mode the app was in last time, read once in main() before the app starts.
final savedAppModeProvider = Provider<AppMode>((_) => AppMode.split);

/// The mode on screen, and the tab you last used in each, so switching back returns there.
class AppModeController extends Notifier<AppMode> {
  final _lastTab = {AppMode.split: 'home', AppMode.personal: 'overview'};

  @override
  AppMode build() => ref.watch(savedAppModeProvider);

  String lastTab(AppMode mode) => _lastTab[mode]!;

  void visited(AppMode mode, String tab) => _lastTab[mode] = tab;

  void set(AppMode mode) {
    if (mode == state) return;
    state = mode;
    // In view-as the app is someone else's: leave your own choice for next time alone.
    if (ref.read(sessionProvider).value?.isViewAs ?? false) return;
    ref.read(appModeStoreProvider).write(mode).ignore();
  }
}

final appModeProvider = NotifierProvider<AppModeController, AppMode>(AppModeController.new);
