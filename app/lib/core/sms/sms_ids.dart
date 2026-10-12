import 'package:uuid/uuid.dart';

import 'banks.dart';
import 'sms.dart';

/// Made for this (uuid5 of the url namespace and "https://splitkit.app/sms"); never change it,
/// or every SMS already read would come back as a new entry.
const _namespace = 'aad579b2-f47f-534f-8b91-c87b76358e34';

final _upiReference = RegExp(r'^\d{12}$');

/// The id the entry for [sms] gets: the same every time the message is read (a rescan, a
/// reinstall, another phone), so it's made once, and once deleted stays deleted.
///
/// With a 12-digit UPI or IMPS reference it's made from that, so two messages about one
/// payment (some banks send two) are one entry. Otherwise from the sender and the text, not
/// the time: the inbox's time and the time the message is delivered to the app differ.
String smsEntryId(String userId, RawSms sms, SmsTxn txn) {
  final ref = txn.reference;
  final name = ref != null && _upiReference.hasMatch(ref)
      ? '$userId|ref:$ref|${txn.amountMinor}|${txn.direction.name}'
      : '$userId|sms:${senderKey(sms.address)}|${sms.body.replaceAll(RegExp(r'\s+'), ' ').trim()}';
  return const Uuid().v5(_namespace, name);
}

/// The sender without its operator prefix and category suffix: VM-HDFCBK-S and AD-HDFCBK are
/// both HDFCBK.
String senderKey(String address) {
  final a = address.trim().toUpperCase();
  return senderHeader.firstMatch(a)?.group(1) ?? a;
}
