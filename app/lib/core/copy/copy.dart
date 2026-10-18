/// Human copy from API data, following the designs' money language: words always travel with
/// colour ("You owe Rahul ₹450", never "−450.00").
library;

import 'package:flutter/painting.dart' show Color;
import 'package:intl/intl.dart';

import '../../design_system/design_system.dart';
import '../api/api.dart';
import '../clock.dart';
import '../finance/finance.dart' show FinanceEngine;
import '../money/money.dart';
import '../theme/theme.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Today", "Yesterday", "Mon, 21 Sep", or "21 Sep 2025" for other years.
String dayLabel(DateTime date, {DateTime? now}) {
  final today = _day(now ?? appClock.now());
  final day = _day(date);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (day.year == today.year) return DateFormat('EEE, d MMM').format(day);
  return DateFormat('d MMM y').format(day);
}

/// "9:40 PM" in the device's time zone.
String timeLabel(DateTime at) => DateFormat.jm().format(at.toLocal());

/// "Wednesday, 23 September".
String longDateLabel(DateTime date) => DateFormat('EEEE, d MMMM').format(date);

/// "Today, 23 Sep" for date rows in forms.
String formDateLabel(DateTime date, {DateTime? now}) {
  final label = dayLabel(date, now: now);
  final short = DateFormat('d MMM').format(date);
  return label == 'Today' || label == 'Yesterday' ? '$label, $short' : label;
}

/// "Active today", "Active yesterday", "3 days ago", "Last week", "12 Aug".
String activityLabel(DateTime? at, {DateTime? now}) {
  if (at == null) return 'No activity yet';
  final days = _day(now ?? appClock.now()).difference(_day(at.toLocal())).inDays;
  if (days <= 0) return 'Active today';
  if (days == 1) return 'Active yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return 'Last week';
  return DateFormat('d MMM').format(at.toLocal());
}

/// When an entry happened. Entries added on their own date show a time ("9:40 PM", or
/// "Today, 9:40 PM" with [withDay]); back-dated or imported ones show only the day.
String entryWhen(DateTime date, DateTime createdAt, {bool withDay = false, DateTime? now}) {
  final sameDay = _day(createdAt.toLocal()) == _day(date);
  final day = dayLabel(date, now: now);
  if (!withDay) return sameDay ? timeLabel(createdAt) : '';
  return sameDay && day == 'Today' ? 'Today, ${timeLabel(createdAt)}' : day;
}

String firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

/// "You" for the viewer, otherwise the first name.
String displayName(UserBrief user, String meId) => user.id == meId ? 'You' : firstName(user.name);

SkPerson personOf(UserBrief user) => SkPerson(id: user.id, name: user.name);

String money(int minor, String currency) => formatMinor(minor, currency: currency);

const paymentMethodLabels = {'upi': 'UPI', 'cash': 'Cash', 'bank': 'Bank transfer', 'other': 'Other'};

/// Everything a [TransactionCard] needs for one feed item.
class TxnView {
  const TxnView({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.label,
    required this.amount,
    required this.glyph,
    required this.tone,
  });

  final String title;
  final String subtitle;
  final String tag;
  final String label;
  final String amount;
  final String glyph;
  final MoneyTone tone;
}

/// [onHome]: tag with the group name (Home) instead of the category (group detail).
TxnView feedView(FeedItem i, String meId, {required bool onHome}) {
  final c = i.currency;
  if (i.kind == FeedItemKindEnum.settlement) {
    final to = i.toUser!;
    final title = i.payer.id == meId
        ? 'You paid ${firstName(to.name)}'
        : to.id == meId
        ? '${firstName(i.payer.name)} paid you'
        : '${firstName(i.payer.name)} paid ${firstName(to.name)}';
    return TxnView(
      title: title,
      subtitle: 'Settlement · ${paymentMethodLabels[i.method] ?? i.method}',
      tag: onHome ? i.groupName : 'Payment',
      label: 'payment',
      amount: money(i.amountMinor, c),
      glyph: 'settle',
      tone: MoneyTone.settle,
    );
  }

  final payer = displayName(i.payer, meId);
  final total = money(i.amountMinor, c);
  final subtitle = i.payer.id == meId
      ? (i.myShareMinor > 0 ? 'You paid $total · your share ${money(i.myShareMinor, c)}' : 'You paid $total for others')
      : '$payer paid $total · split ${i.participantCount} ways';

  final (label, amount, tone) = switch (i.myNetMinor) {
    > 0 => ('you are owed', i.myNetMinor, MoneyTone.owed),
    < 0 when i.settled => ('your share', i.myShareMinor, MoneyTone.settled),
    < 0 => ('you owe', -i.myNetMinor, MoneyTone.owe),
    _ when i.myShareMinor > 0 => ('your share', i.myShareMinor, MoneyTone.settled),
    _ => ('not involved', i.amountMinor, MoneyTone.neutral),
  };
  return TxnView(
    title: i.title ?? '',
    subtitle: subtitle,
    tag: onHome ? i.groupName : (i.category?.label ?? 'Other'),
    label: label,
    amount: money(amount, c),
    glyph: i.category?.icon ?? 'other',
    tone: tone,
  );
}

/// Friend chip on Home: "you owe ₹500", "owes you ₹1,550", "settled".
String friendChipState(int net, String currency) => net < 0
    ? 'you owe ${money(-net, currency)}'
    : net > 0
    ? 'owes you ${money(net, currency)}'
    : 'settled';

/// Row on group balances: "You owe ₹500", "Owes you ₹1,550", "All square".
String personRowState(int net, String currency) => net < 0
    ? 'You owe ${money(-net, currency)}'
    : net > 0
    ? 'Owes you ${money(net, currency)}'
    : 'All square';

/// Group card words: "you are owed", "you owe", "all settled".
String groupNetLabel(int net) => net > 0
    ? 'you are owed'
    : net < 0
    ? 'you owe'
    : 'all settled';

/// Glyph fallback for any icon name the app doesn't know.
String glyphOr(String? name, [String fallback = 'other']) => name != null && SkIcon.has(name) ? name : fallback;

/// Colour for figures that sit on white: settled amounts read in ink2, not the grey tone.
MoneyTone toneFor(int net) => MoneyTone.forNet(net);
Color textColorFor(int net) => net == 0 ? SkColors.ink2 : MoneyTone.forNet(net).fg;

/// "₹32.5k" for bar tops; small amounts stay exact ("₹486").
String compactMoney(int minor, String currency) {
  final whole = minor ~/ minorUnitsPerMajor(currency);
  if (whole < 1000) return money(minor, currency);
  final k = (whole / 1000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  return '${currencySymbol(currency)}${k}k';
}

/// How a personal entry was paid (personal_transactions.channel), in the order the sheet
/// offers them. ATM only comes from bank SMS.
const channelLabels = {
  'upi': 'UPI',
  'card': 'Card',
  'bank': 'Bank transfer',
  'cash': 'Cash',
  'other': 'Other',
  'atm': 'ATM',
};

/// "From an SMS · HDFC ··4821 · balance after ₹42,276": where an entry the app read came from.
String smsOrigin(PersonalTxnOut t) => [
  'From an SMS',
  ?t.account,
  if (t.balanceMinor case final b?) 'balance after ${money(b, t.currency)}',
].join(' · ');

/// The entry's category as a list shows it. A payment to a friend needs none; a transfer, a
/// balance correction, a refund or an investment with none says what it is.
String? categoryLabel(PersonalTxnOut t) =>
    t.category?.label ??
    switch (t.type.value) {
      'income' => 'Income',
      'transfer' => 'Transfer',
      'adjustment' => 'Balance correction',
      'refund' => 'Refund',
      'investment_contribution' || 'investment_withdrawal' => 'Investment',
      _ => t.settlementId != null ? null : 'Uncategorised',
    };

/// "Split, not counted": an entry that became a split or a payment, left out of the totals.
String? notCounted(PersonalTxnOut t) =>
    t.counted ? null : (t.settlementId != null ? 'Payment, not counted' : 'Split, not counted');

/// A personal entry as every list shows it (a [TransactionCard], a Transactions row): "Swiggy
/// order · Food · UPI · spent ₹486". A transfer half names the account on the other side ("To
/// ICICI Credit card ··9012", "From HDFC ··4821", read from [finance]) and is money moved, in a
/// neutral tone; a refund is money back; a balance correction and investments say what they are.
/// Money coming in has a "+". [brief] leaves out how it was paid and the note (Transactions).
TxnView personalView(PersonalTxnOut t, {FinanceEngine? finance, bool brief = false}) {
  final type = t.type.value;
  final comesIn = t.direction == PersonalTxnOutDirectionEnum.in_;
  final paidWith = channelLabels[t.channel?.value] ?? ((t.notes ?? '').isEmpty ? null : t.notes);
  String? accountName(String? id) => id == null ? null : finance?.account(id)?.name;
  String moved() {
    final other = accountName(finance?.partnerLeg(t.id)?.accountId) ?? 'another account';
    return comesIn ? 'From $other' : 'To $other';
  }

  final what = switch (type) {
    'transfer' => moved(),
    'adjustment' => ['Balance correction', ?accountName(t.accountId)].join(' · '),
    _ => categoryLabel(t),
  };
  return TxnView(
    title: t.description,
    subtitle: [?what, if (notCounted(t) case final note?) note else if (!brief) ?paidWith].join(' · '),
    tag: t.source_ == PersonalTxnOutSource_Enum.sms ? 'From SMS' : 'Personal',
    label: switch (type) {
      'income' => 'received',
      'transfer' => 'moved',
      'refund' => 'refunded',
      'adjustment' => 'correction',
      'investment_contribution' => 'invested',
      'investment_withdrawal' => 'withdrawn',
      _ => 'spent',
    },
    amount: comesIn ? formatMinor(t.amountMinor, currency: t.currency, signed: true) : money(t.amountMinor, t.currency),
    glyph: switch (type) {
      'transfer' => 'swap',
      'adjustment' => 'edit',
      'investment_contribution' || 'investment_withdrawal' => 'chart',
      'refund' => glyphOr(t.category?.icon, 'refresh'),
      _ => glyphOr(t.category?.icon, type == 'income' ? 'income' : 'other'),
    },
    tone: switch (type) {
      'income' || 'refund' => MoneyTone.income,
      'expense' => MoneyTone.expense,
      _ => MoneyTone.neutral,
    },
  );
}

/// The icon tile colours of a personal entry's row: Personal's own, or grey for money that only
/// moved (a transfer, a correction, an investment).
(Color, Color) personalTile(TxnView v) =>
    v.tone == MoneyTone.neutral ? (SkColors.sunken, SkColors.ink2) : (SkColors.personalSoft, SkColors.personalInk);

/// "Sep 2026".
String shortMonthLabel(DateTime month) => DateFormat('MMM y').format(month);
