import 'dart:async';

import 'package:splitkit/core/sms/sms.dart';
import 'package:splitkit/features/sms/sms_source.dart';

/// An SMS inbox for tests. Off (like web) unless [available]; [inbox] holds the messages,
/// [access] whether reading is allowed, and [grant] what the system prompt answers.
class FakeSmsSource implements SmsSource {
  FakeSmsSource({this.available = false, this.access = false, this.grant = true, List<RawSms>? inbox})
    : messages = inbox ?? [];

  @override
  final bool available;
  bool access;
  bool grant;
  final List<RawSms> messages;
  final reads = <({DateTime since, String pattern})>[];
  final _changes = StreamController<void>.broadcast();

  /// A message arrives (the inbox changes).
  void receive(RawSms sms) {
    messages.add(sms);
    _changes.add(null);
  }

  @override
  Future<bool> hasAccess() async => access;

  @override
  Future<bool> requestAccess() async => access = grant;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<RawSms>> inbox({required DateTime since, required String senderPattern, int limit = 500}) async {
    reads.add((since: since, pattern: senderPattern));
    final pattern = RegExp(senderPattern);
    final found = [
      for (final m in messages)
        if (!m.receivedAt.isBefore(since) && pattern.hasMatch(m.address)) m,
    ]..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    return found.take(limit).toList();
  }

  @override
  Stream<void> get changes => _changes.stream;
}
