import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sms/sms.dart';

/// The phone's SMS inbox, as far as the app may see it: messages from senders that match a
/// pattern (business headers), read on the phone. Android only; elsewhere [available] is false
/// and nothing is read.
abstract class SmsSource {
  bool get available;

  Future<bool> hasAccess();

  /// Asks for SMS access (the system prompt); true if it's allowed.
  Future<bool> requestAccess();

  /// The app's page in the system settings, for access that was refused for good.
  Future<void> openSettings();

  /// Messages from senders matching [senderPattern] that arrived at or after [since], oldest
  /// first, at most [limit].
  Future<List<RawSms>> inbox({required DateTime since, required String senderPattern, int limit = 500});

  /// Fires when the inbox changes while the app is open.
  Stream<void> get changes;
}

class AndroidSmsSource implements SmsSource {
  static const _methods = MethodChannel('splitkit/sms');
  static const _live = EventChannel('splitkit/sms/live');

  @override
  bool get available => true;

  @override
  Future<bool> hasAccess() async => await _methods.invokeMethod<bool>('access') ?? false;

  @override
  Future<bool> requestAccess() async => await _methods.invokeMethod<bool>('request') ?? false;

  @override
  Future<void> openSettings() => _methods.invokeMethod<void>('settings');

  @override
  Future<List<RawSms>> inbox({required DateTime since, required String senderPattern, int limit = 500}) async {
    final rows = await _methods.invokeListMethod<Map<Object?, Object?>>('inbox', {
      'since': since.millisecondsSinceEpoch,
      'senders': senderPattern,
      'limit': limit,
    });
    return [
      for (final r in rows ?? const <Map<Object?, Object?>>[])
        RawSms(
          address: r['address']! as String,
          body: r['body']! as String,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(r['date']! as int),
        ),
    ];
  }

  @override
  Stream<void> get changes => _live.receiveBroadcastStream();
}

/// Web, iOS, desktop: no SMS to read.
class NoSmsSource implements SmsSource {
  const NoSmsSource();

  @override
  bool get available => false;

  @override
  Future<bool> hasAccess() async => false;

  @override
  Future<bool> requestAccess() async => false;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<RawSms>> inbox({required DateTime since, required String senderPattern, int limit = 500}) async =>
      const [];

  @override
  Stream<void> get changes => const Stream.empty();
}

final smsSourceProvider = Provider<SmsSource>(
  (_) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? AndroidSmsSource() : const NoSmsSource(),
);
