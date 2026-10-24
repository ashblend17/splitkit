import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/config.dart';
import '../../core/sms/sms.dart';
import '../../core/sms/sms_notification.dart';

/// The Dart side of a bank SMS notification (SmsBackground.kt), run in its own short-lived
/// engine with the app closed: describes the message with the app's parser. It reads nothing
/// else and stores nothing; the app adds the payment when it's next opened.
Future<void> runSmsBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app/sms_bg');
  channel.setMethodCallHandler((call) async {
    if (call.method != 'describe') return null;
    final a = (call.arguments as Map).cast<String, Object?>();
    final described = describeForNotification(
      RawSms(
        address: a['address']! as String,
        body: a['body']! as String,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(a['date']! as int),
      ),
      testSenders: {if (AppConfig.smsTestSender.isNotEmpty) AppConfig.smsTestSender},
    );
    return described == null ? null : {'title': described.title, 'text': described.text, 'split': described.split};
  });
  await channel.invokeMethod<void>('ready');
}
