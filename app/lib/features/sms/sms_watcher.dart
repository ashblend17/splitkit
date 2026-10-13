import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sms_importer.dart';
import 'sms_source.dart';

/// Reads bank SMS (if you've turned it on) when the app opens, when it comes back to the
/// front, and when the inbox changes while it's open. Everything else is the importer's call:
/// it reads nothing when off, in view-as, or off Android.
class SmsWatcher extends ConsumerStatefulWidget {
  const SmsWatcher({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SmsWatcher> createState() => _SmsWatcherState();
}

class _SmsWatcherState extends ConsumerState<SmsWatcher> with WidgetsBindingObserver {
  StreamSubscription<void>? _changes;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final source = ref.read(smsSourceProvider);
    if (!source.available) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
    // A message changes the inbox more than once (stored, then marked seen): read once it
    // settles.
    _changes = source.changes.listen(
      (_) {
        _settle?.cancel();
        _settle = Timer(const Duration(seconds: 2), _read);
      },
      onError: (Object e) => debugPrint('SMS changes: $e'),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(smsSourceProvider).available) _read();
  }

  void _read() {
    if (!mounted) return;
    ref.read(smsImporterProvider).scan().ignore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changes?.cancel();
    _settle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
