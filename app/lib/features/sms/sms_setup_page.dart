import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/clock.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/integrations.dart';
import '../../core/local/providers.dart';
import '../../core/sms/sms.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'sms_importer.dart';
import 'sms_source.dart';

/// Whether this phone reads bank SMS for you, and the skipped ones (Profile → Bank SMS and
/// Overview's prompt read it).
typedef SmsSetup = ({SmsSettings? settings, bool dismissed, int skipped});

final smsSetupProvider = FutureProvider<SmsSetup>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  final importer = ref.watch(smsImporterProvider);
  return (
    settings: await importer.settings(),
    dismissed: await store.deviceValue(SmsKeys.promptDismissed) == true,
    skipped: (await importer.skipped()).length,
  );
});

/// Profile → Bank SMS (/profile/sms): what reading SMS does, then turning it on, reading
/// again, or off. Says first, before the system asks, what's read and what leaves the phone.
class SmsSetupPage extends ConsumerStatefulWidget {
  const SmsSetupPage({super.key});

  @override
  ConsumerState<SmsSetupPage> createState() => _SmsSetupPageState();
}

class _SmsSetupPageState extends ConsumerState<SmsSetupPage> {
  /// Months back to read: 1 is this month.
  int _months = 3;
  bool _busy = false;
  bool _refused = false;
  SmsScan? _result;

  DateTime get _since {
    final now = appClock.now();
    return DateTime(now.year, now.month - (_months - 1));
  }

  Future<void> _run(Future<SmsScan> Function(SmsImporter importer) work) async {
    setState(() => _busy = true);
    try {
      final result = await work(ref.read(smsImporterProvider));
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) showMessage(context, "Couldn't read your SMS: $e");
    } finally {
      ref.invalidate(smsSetupProvider);
      refreshPersonal(ref.invalidate);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOn() async {
    final source = ref.read(smsSourceProvider);
    setState(() => _busy = true);
    final allowed = await source.hasAccess() || await source.requestAccess();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _refused = !allowed;
    });
    if (!allowed) return;
    // Then notifications (Android 13 and up ask); without them it still reads in the app.
    if (ref.read(featuresProvider).smsNotifications) await source.requestNotificationAccess();
    await _run((importer) => importer.setUp(_since));
  }

  Future<void> _setNotify(bool on) async {
    final source = ref.read(smsSourceProvider);
    if (on && !await source.hasNotificationAccess() && !await source.requestNotificationAccess()) {
      if (mounted) showMessage(context, "Notifications are off for Splitkit. You can allow them in the phone's settings.");
      return;
    }
    await ref.read(smsImporterProvider).setNotify(on);
    ref.invalidate(smsSetupProvider);
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(smsSourceProvider);
    final setup = ref.watch(smsSetupProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: HeaderIconButton(
                            glyph: 'back',
                            label: 'Back to profile',
                            onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
                          ),
                        ),
                        Semantics(header: true, child: Text('Bank SMS', style: SkText.display(20, 700))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!source.available)
                    const EmptyState(
                      glyph: 'lock',
                      title: 'Only on Android',
                      body: 'Reading bank SMS works in the Android app. What it adds shows here too.',
                    )
                  else
                    AsyncBody(
                      value: setup,
                      onRetry: () => ref.invalidate(smsSetupProvider),
                      builder: (s) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Disclosure(),
                          const SizedBox(height: 16),
                          if (s.settings case final settings?) ..._on(settings, s.skipped) else ..._off(),
                          if (_result case final r?) ...[const SizedBox(height: 12), _resultLine(r)],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _off() => [
    Text('Read from', style: SkText.body(14, 600)),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (months, label) in const [(1, 'This month'), (3, 'Last 3 months'), (12, 'Last 12 months')])
          SelectableChip(
            label: label,
            selected: _months == months,
            accent: ChipAccent.personal,
            onTap: () => setState(() => _months = months),
          ),
      ],
    ),
    const SizedBox(height: 16),
    SkButton(
      _busy ? 'Reading…' : 'Allow and read my bank SMS',
      variant: SkButtonVariant.strong,
      expand: true,
      onPressed: _busy ? null : _turnOn,
    ),
    if (_refused) ...[
      const SizedBox(height: 12),
      Text(
        "Splitkit isn't allowed to read SMS. You can allow it in the phone's settings.",
        style: SkText.body(13, 400, color: SkColors.ink2),
      ),
      const SizedBox(height: 8),
      SkButton(
        'Open settings',
        variant: SkButtonVariant.secondary,
        expand: true,
        onPressed: () => ref.read(smsSourceProvider).openSettings(),
      ),
    ],
  ];

  List<Widget> _on(SmsSettings settings, int skipped) => [
    SkCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SkIcon('check', size: 20, color: SkColors.personal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'On. Reading SMS from ${DateFormat('d MMM y').format(settings.since)}.',
              style: SkText.body(15, 600),
            ),
          ),
        ],
      ),
    ),
    if (ref.watch(featuresProvider).smsNotifications) ...[
      const SizedBox(height: 8),
      SkCard(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tell me when one arrives', style: SkText.body(15, 600)),
                  Text(
                    'A notification for each payment, with Split.',
                    style: SkText.body(12, 400, color: SkColors.ink2),
                  ),
                ],
              ),
            ),
            Switch(value: settings.notify, activeColor: SkColors.personal, onChanged: _busy ? null : _setNotify),
          ],
        ),
      ),
    ],
    const SizedBox(height: 12),
    SkButton(
      _busy ? 'Reading…' : 'Read again',
      icon: 'refresh',
      variant: SkButtonVariant.secondary,
      expand: true,
      onPressed: _busy ? null : () => _run((importer) => importer.scan(fromStart: true)),
    ),
    const SizedBox(height: 8),
    SkButton(
      skipped == 0 ? 'Messages we skipped' : 'Messages we skipped ($skipped)',
      variant: SkButtonVariant.secondary,
      expand: true,
      onPressed: () => context.go('/profile/sms/skipped'),
    ),
    const SizedBox(height: 8),
    SkButton(
      'Turn off',
      variant: SkButtonVariant.ghost,
      expand: true,
      onPressed: _busy ? null : () => _run((importer) => importer.setUp(null)),
    ),
    const SizedBox(height: 4),
    Text("Turning it off keeps what's been added.", style: SkText.body(12, 400, color: SkColors.ink2)),
  ];

  Widget _resultLine(SmsScan r) {
    final done = [
      if (r.added > 0) 'Added ${r.added} ${r.added == 1 ? 'entry' : 'entries'}',
      if (r.attached > 0) 'matched ${r.attached} you had entered',
    ];
    return Text(
      done.isEmpty ? 'Nothing new.' : '${done.join(', ')}.',
      style: SkText.body(14, 600, color: SkColors.personalInk),
    );
  }
}

/// What's read, what's saved, what never leaves the phone (Google Play's prominent
/// disclosure, shown before the system's permission prompt).
class _Disclosure extends StatelessWidget {
  const _Disclosure();

  @override
  Widget build(BuildContext context) => SkCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SkIcon('lock', size: 18, color: SkColors.personalInk),
            const SizedBox(width: 8),
            Expanded(child: Text('Your bank SMS, read on this phone', style: SkText.body(16, 700))),
          ],
        ),
        const SizedBox(height: 10),
        for (final line in const [
          "Splitkit reads the SMS your bank sends to this phone and adds what you spend and receive to Personal: the amount, who was paid, the account, how it was paid and the balance.",
          'Only those details are saved to your account. The messages stay on this phone, and OTPs and messages from people are never read into the app.',
          "Each payment is added once. You can split it, mark it as a payment to a friend, or remove it.",
        ]) ...[
          Text(line, style: SkText.body(14, 400, color: SkColors.ink2, height: 1.4)),
          const SizedBox(height: 8),
        ],
      ],
    ),
  );
}

/// Profile → Bank SMS → Messages we skipped (/profile/sms/skipped): bank messages that weren't
/// added, and why. Shown from this phone only.
class SmsSkippedPage extends ConsumerWidget {
  const SmsSkippedPage({super.key});

  static const _why = {
    SmsSkip.promotional: 'An offer',
    SmsSkip.notYet: 'Still to come, or asked for',
    SmsSkip.failed: "Didn't go through",
    SmsSkip.refund: 'A refund (not added yet)',
    SmsSkip.statement: 'A statement or bill',
    SmsSkip.cardBill: 'A credit card bill paid',
    SmsSkip.ownTransfer: 'Between your own accounts',
    SmsSkip.foreignCurrency: 'Not in rupees',
    SmsSkip.noTransaction: 'No payment in it',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipped = ref.watch(_skippedProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: HeaderIconButton(
                            glyph: 'back',
                            label: 'Back to Bank SMS',
                            onPressed: () => context.canPop() ? context.pop() : context.go('/profile/sms'),
                          ),
                        ),
                        Semantics(header: true, child: Text('Messages we skipped', style: SkText.display(20, 700))),
                      ],
                    ),
                  ),
                  Text(
                    "From bank senders, but not added. If one was a payment, add it with Add entry; it helps to know "
                    'which ones the app misses.',
                    style: SkText.body(13, 400, color: SkColors.ink2),
                  ),
                  const SizedBox(height: 12),
                  AsyncBody(
                    value: skipped,
                    onRetry: () => ref.invalidate(_skippedProvider),
                    builder: (list) => list.isEmpty
                        ? const EmptyState(glyph: 'check', title: 'None', body: 'Every bank message was added or known.')
                        : Column(
                            children: [
                              for (final s in list) ...[
                                SkCard(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${s.sms.address} · ${dayLabel(s.sms.receivedAt)}',
                                              style: SkText.body(12, 600, color: SkColors.ink2),
                                            ),
                                          ),
                                          StatusChip(_why[s.reason] ?? s.reason.name, tone: StatusTone.expense, showDot: false),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(s.sms.body, style: SkText.body(14, 400, height: 1.4)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _skippedProvider = FutureProvider<List<SkippedSms>>((ref) => ref.watch(smsImporterProvider).skipped());
