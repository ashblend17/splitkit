/// The ids the app makes itself, so every phone (and the server's backfill) makes the same row
/// for the same thing and a repeat create returns it: a bank SMS label's account, the app-made
/// half of a transfer and the pair's group, a rule's plan for an income, and your decision on a
/// reminder. The namespaces are the server's (api/app/modules/personal/ledger_rules.py; migration
/// 0013 keeps its own copy of the account one), and shared/ledger_vectors.json pins both sides.
library;

import 'package:uuid/uuid.dart';

import 'model.dart';

/// uuid5(NAMESPACE_URL, "https://splitkit.app/sms-account"): ledger_rules.ACCOUNT_NAMESPACE.
/// Never change it, or every phone would make a second account for each bank label.
const accountNamespace = 'e90fe153-8f9c-5d42-8516-3ac04850d447';

/// uuid5(NAMESPACE_URL, "https://splitkit.app/allocation-plan"): ledger_rules.PLAN_NAMESPACE.
const planNamespace = '1e9fd80e-c002-5f96-bd4e-d295ec89c7fc';

/// uuid5(NAMESPACE_URL, "https://splitkit.app/reminder-state"): ledger_rules.REMINDER_NAMESPACE.
const reminderNamespace = '3b36adfa-75dd-550a-ac0b-0e156df727cc';

const _uuid = Uuid();

/// The account for bank SMS label [label] ("HDFC ··4821") of user [userId] (the API's lowercase
/// form): ledger_rules.sms_account_id.
String smsAccountId(String userId, String label) => _uuid.v5(accountNamespace, '$userId|$label');

/// The other half the app makes for transfer leg [legId] (an ATM withdrawal's cash leg), so a
/// re-read SMS makes the same leg again rather than a second one.
String pairedLegId(String legId) => _uuid.v5(accountNamespace, '$legId|pair');

/// The transfer group of legs [legA] and [legB] (or of [legA] alone, when the other leg is
/// [pairedLegId] of it). The same whichever order the legs are given in.
String transferGroupIdFor(String legA, [String? legB]) {
  final legs = [legA, ?legB]..sort();
  return _uuid.v5(accountNamespace, '${legs.join('|')}|group');
}

/// The plan rule [ruleId] makes for income [incomeId]: ledger_rules.plan_id.
String planId(String incomeId, String ruleId) => _uuid.v5(planNamespace, '$incomeId|$ruleId');

/// Your decision on the reminder with [dedupKey] (`goal_behind:<goal id>:2026-10`):
/// ledger_rules.reminder_state_id.
String reminderStateId(String userId, String dedupKey) => _uuid.v5(reminderNamespace, '$userId|$dedupKey');

/// The type of the account a bank SMS label gets: the parser labels cards "ICICI Credit card
/// ··9012", and debit cards draw from a bank account (ledger_rules.account_type_for_label).
AccountType accountTypeForLabel(String label) =>
    label.toLowerCase().contains('credit card') ? AccountType.creditCard : AccountType.bank;
