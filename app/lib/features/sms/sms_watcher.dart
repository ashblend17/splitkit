import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/integrations.dart';

import 'sms_importer.dart';
import 'sms_source.dart';

/// Reads bank SMS (if you've turned it on) when the app opens, when it comes back to the
/// front, and when the inbox changes while it's open. Everything else is the importer's call:
/// it reads nothing when off, in view-as, or off Android.
///
/// Opened from a bank SMS notification, it adds that payment and opens it: Add split for
/// "Split", Personal otherwise.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _read();
      _launched();
    });
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
    if (state == AppLifecycleState.resumed && ref.read(smsSourceProvider).available) {
      _read();
      _launched();
    }
  }

  /// A tapped notification: add its payment, take the notification away, open it.
  Future<void> _launched() async {
    final source = ref.read(smsSourceProvider);
    final launch = await source.takeLaunch();
    if (launch == null || !mounted) return;
    final id = await ref.read(smsImporterProvider).importOne(launch.sms);
    await source.cancelNotification(launch.notification);
    if (!mounted) return;
    final links = ref.read(integrationsProvider);
    final router = GoRouter.of(context);
    if (id != null && launch.split && links.splitFromTransaction && links.notificationSplitAction) {
      router.push('/expenses/new?from_txn=$id');
    } else {
      router.go('/personal');
    }
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
