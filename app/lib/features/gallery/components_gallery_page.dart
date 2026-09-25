import 'package:flutter/material.dart';

import '../../core/splits/split_engine.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';

/// designs/Components.dc.html rebuilt from the real design-system widgets, with the
/// mockup's sample data. Wide screens get the mockup's grid; narrow ones stack.
class ComponentsGalleryPage extends StatefulWidget {
  const ComponentsGalleryPage({super.key});

  @override
  State<ComponentsGalleryPage> createState() => _ComponentsGalleryPageState();
}

// Sample people with the mockup's avatar colours.
const _you = SkPerson(id: 'you', name: 'You', initials: 'AC', colors: (Color(0xFFE4E0FB), Color(0xFF3326A8)));
const _rahul = SkPerson(id: 'rahul', name: 'Rahul', initials: 'RS', colors: (Color(0xFFFDE7D9), Color(0xFF9A3B0B)));
const _aman = SkPerson(id: 'aman', name: 'Aman', initials: 'AV', colors: (Color(0xFFDDF0E7), Color(0xFF0B6B45)));
const _vivek = SkPerson(id: 'vivek', name: 'Vivek', initials: 'VI', colors: (Color(0xFFE0EEF9), Color(0xFF1E5A8C)));
const _priya = SkPerson(id: 'priya', name: 'Priya', initials: 'PN', colors: (Color(0xFFF8E1EE), Color(0xFF8C2361)));
const _kabir = SkPerson(id: 'kabir', name: 'Kabir', initials: 'KM', colors: (Color(0xFFEFEBDD), Color(0xFF6A5712)));

class _ComponentsGalleryPageState extends State<ComponentsGalleryPage> {
  // "live validation" demo: ₹1,200 between You and Rahul.
  late final _validSplit = SplitController(
    people: const [_you, _rahul],
    totalMinor: 120000,
    method: 'exact',
    values: {
      'exact': {'you': '600', 'rahul': '600'},
      'percent': {'you': '50', 'rahul': '50'},
      'shares': {'you': '1', 'rahul': '1'},
    },
  );
  late final _shortSplit = SplitController(
    people: const [_you, _rahul],
    totalMinor: 120000,
    method: 'exact',
    values: {
      'exact': {'you': '600', 'rahul': '500'},
      'percent': {'you': '50', 'rahul': '40'},
      'shares': {'you': '0', 'rahul': '0'},
    },
    included: {},
  );

  // SplitConfig defaults: Dinner at Thalassa, ₹1,800, Rahul paid.
  late final _configSplit = SplitController(
    people: const [_you, _rahul, _aman, _vivek],
    totalMinor: 180000,
    values: {
      'exact': {'you': '600', 'rahul': '400', 'aman': '500', 'vivek': '200'},
      'percent': {'you': '40', 'rahul': '30', 'aman': '20', 'vivek': '10'},
      'shares': {'you': '2', 'rahul': '1', 'aman': '1', 'vivek': '1'},
    },
  );

  String _category = 'food';
  String _payer = 'rahul';
  String _nav = 'home';
  bool _unsettledOnly = true;
  DateTime _day = DateTime(2026, 9, 23);
  SkPerson? _viewAs = _rahul;

  @override
  void dispose() {
    _validSplit.dispose();
    _shortSplit.dispose();
    _configSplit.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width >= 1000 ? 64.0 : 16.0;
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440 - 128),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 32),
                _transactionCards(),
                const SizedBox(height: 32),
                _Grid(columns: 2, gap: 24, minColumnWidth: 520, children: [_buttons(), _inputs()]),
                const SizedBox(height: 32),
                _Grid(columns: 4, gap: 24, minColumnWidth: 280, children: [_balance(), _friends(), _group(), _user()]),
                const SizedBox(height: 32),
                _Grid(columns: 2, gap: 24, minColumnWidth: 520, children: [_splitSelector(), _filters()]),
                const SizedBox(height: 32),
                _Grid(
                  columns: 4,
                  gap: 24,
                  minColumnWidth: 280,
                  children: [_analytics(), _empty(), _loading(), _error()],
                ),
                const SizedBox(height: 32),
                _Grid(columns: 3, gap: 24, minColumnWidth: 400, children: [_dialog(), _sheet(), _admin()]),
                const SizedBox(height: 48),
                _extrasHeader(),
                const SizedBox(height: 24),
                _Grid(columns: 2, gap: 24, minColumnWidth: 400, children: [_splitConfig(), _addSplitPieces()]),
                const SizedBox(height: 32),
                _navigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- header ----

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'SPLITKIT DESIGN SYSTEM',
        style: SkText.body(14, 700, color: SkColors.brandInk, letterSpacing: 14 * 0.08),
      ),
      const SizedBox(height: 8),
      Text('Components', style: SkText.display(56, 800)),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Text(
          'Each piece is independent and data-driven. Screens compose them; none of them knows about groups, analytics or admin on its own.',
          style: SkText.body(18, 400, color: SkColors.ink2, height: 1.5),
        ),
      ),
    ],
  );

  Widget _extrasHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Also in the design system', style: SkText.display(26, 700)),
      const SizedBox(height: 6),
      Text(
        'Pieces the screens use that the Components board shows only in context.',
        style: SkText.body(15, 500, color: SkColors.ink2),
      ),
    ],
  );

  // ---- sections ----

  Widget _transactionCards() {
    const cards = [
      (
        'owe',
        TransactionCard(
          title: 'Dinner at Thalassa',
          subtitle: 'Rahul paid ₹1,800 · split 4 ways',
          tag: 'Goa Trip',
          when: '9:40 PM',
          label: 'you owe',
          amount: '₹450',
          glyph: 'food',
          tone: MoneyTone.owe,
        ),
      ),
      (
        'owed',
        TransactionCard(
          title: 'Groceries',
          subtitle: 'You paid ₹2,340 · your share ₹780',
          tag: 'Flatmates',
          when: '6:15 PM',
          label: 'you are owed',
          amount: '₹1,560',
          glyph: 'shopping',
          tone: MoneyTone.owed,
        ),
      ),
      (
        'settled',
        TransactionCard(
          title: 'Electricity bill',
          subtitle: 'Aman paid ₹3,200 · split 4 ways',
          tag: 'Flatmates',
          when: 'Mon',
          label: 'your share',
          amount: '₹800',
          glyph: 'bills',
          tone: MoneyTone.settled,
        ),
      ),
      (
        'settle',
        TransactionCard(
          title: 'You paid Rahul',
          subtitle: 'Settlement · UPI',
          tag: 'Goa Trip',
          when: 'Yesterday',
          label: 'payment',
          amount: '₹500',
          glyph: 'settle',
          tone: MoneyTone.settle,
        ),
      ),
      (
        'expense',
        TransactionCard(
          title: 'Swiggy order',
          subtitle: 'Food · UPI',
          tag: 'Personal',
          when: '1:10 PM',
          label: 'spent',
          amount: '₹486',
          glyph: 'food',
          tone: MoneyTone.expense,
          scope: TxnScope.personal,
        ),
      ),
      (
        'income',
        TransactionCard(
          title: 'Salary',
          subtitle: 'Income · Bank transfer',
          tag: 'Personal',
          when: '1 Sep',
          label: 'received',
          amount: '+₹85,000',
          glyph: 'income',
          tone: MoneyTone.income,
          scope: TxnScope.personal,
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'TransactionCard ', style: SkText.display(26, 700)),
              TextSpan(
                text: '· one card, seven tones',
                style: SkText.body(15, 500, color: SkColors.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Grid(
          columns: 3,
          gap: 16,
          minColumnWidth: 340,
          children: [
            for (final (tone, card) in cards)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('tone: $tone', style: _mono),
                  const SizedBox(height: 6),
                  card,
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buttons() => _Panel(
    title: 'Buttons',
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SkButton('Primary', onPressed: () {}),
          SkButton('Strong', onPressed: () {}, variant: SkButtonVariant.strong),
          SkButton('Secondary', onPressed: () {}, variant: SkButtonVariant.secondary),
          SkButton('Ghost', onPressed: () {}, variant: SkButtonVariant.ghost),
          SkButton('Delete', onPressed: () {}, variant: SkButtonVariant.danger),
          const SkButton('Disabled', onPressed: null),
        ],
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AddSplitFab(onPressed: () => _toast('Add split')),
          Text(
            'Floating action · one per screen, always “Add split”',
            style: SkText.body(13, 400, color: SkColors.ink2),
          ),
        ],
      ),
    ],
  );

  Widget _inputs() => _Panel(
    title: 'Inputs',
    children: [
      _Grid(
        columns: 3,
        gap: 12,
        minColumnWidth: 150,
        children: [
          SkTextField(
            label: 'Default',
            controller: TextEditingController(text: 'Dinner'),
          ),
          SkTextField(
            label: 'Focus',
            controller: TextEditingController(text: 'Dinner at'),
            autofocus: true,
          ),
          const SkTextField(label: 'Error', errorText: 'Add a description'),
        ],
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: SkColors.paper, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('₹', style: SkText.display(28, 600, color: SkColors.ink3)),
                const SizedBox(width: 4),
                Text('1,800', style: SkText.display(48, 800)),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AmountInput', style: SkText.body(13, 700)),
                  const SizedBox(height: 2),
                  Text(
                    'Numeric keypad, currency chip, formats as you type. Currency stays single per group in the MVP.',
                    style: SkText.body(13, 400, color: SkColors.ink2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _balance() => _Titled(
    'BalanceCard',
    const BalanceCard(
      netMinor: 115000,
      youOweMinor: 125000,
      youAreOwedMinor: 240000,
      layout: BalanceCardLayout.compact,
    ),
  );

  Widget _friends() => _Titled(
    'FriendBalance',
    SkCard(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          FriendBalanceRow(person: _rahul, state: 'You owe ₹500', tone: MoneyTone.owe, onTap: () {}),
          FriendBalanceRow(person: _aman, state: 'Aman owes you ₹850', tone: MoneyTone.owed, onTap: () {}),
          FriendBalanceRow(person: _vivek, state: 'Settled', tone: MoneyTone.settled, onTap: () {}),
        ],
      ),
    ),
  );

  Widget _group() => _Titled(
    'GroupCard',
    GroupCard(
      name: 'Goa Trip',
      glyph: 'travel',
      meta: '6 members · ₹48,260',
      label: 'you are owed',
      amount: '₹1,150',
      tone: MoneyTone.owed,
      lastActive: 'Active today',
      members: const [_you, _rahul, _aman, _vivek, _priya, _kabir],
      onTap: () {},
    ),
  );

  Widget _user() => _Titled(
    'UserCard',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UserCard(
          person: SkPerson(id: 'rahul', name: 'Rahul Sharma', colors: (Color(0xFFFDE7D9), Color(0xFF9A3B0B))),
          subtitle: '3 shared groups',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (p, size) in const [
              (_you, 24.0),
              (_rahul, 28.0),
              (_aman, 32.0),
              (_vivek, 36.0),
              (_priya, 40.0),
              (_kabir, 48.0),
            ]) ...[Avatar(p, size: size, fontSize: 11), const SizedBox(width: 6)],
          ],
        ),
      ],
    ),
  );

  Widget _splitSelector() => _Panel(
    titleSpan: TextSpan(
      children: [
        TextSpan(text: 'SplitSelector ', style: SkText.display(22, 700)),
        TextSpan(
          text: '· live validation',
          style: SkText.body(14, 500, color: SkColors.ink2),
        ),
      ],
    ),
    children: [
      ListenableBuilder(
        listenable: _validSplit,
        builder: (context, _) => SplitMethodTabs(
          methods: splitRegistry.all,
          selected: _validSplit.method,
          style: SplitTabsStyle.inline,
          onSelected: (k) {
            _validSplit.selectMethod(k);
            _shortSplit.selectMethod(k);
          },
        ),
      ),
      _Grid(
        columns: 2,
        gap: 12,
        minColumnWidth: 230,
        children: [
          SplitSummaryBox(controller: _validSplit),
          SplitSummaryBox(controller: _shortSplit),
        ],
      ),
      Text(
        'Methods are plug-ins of the split engine (equal, exact, percent, shares). The selector renders whatever methods the engine registers.',
        style: SkText.body(13, 400, color: SkColors.ink2),
      ),
    ],
  );

  Widget _filters() => _Panel(
    title: 'Filters, status & dates',
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SkFilterChip(
            label: 'Unsettled only',
            selected: _unsettledOnly,
            onTap: () => setState(() => _unsettledOnly = !_unsettledOnly),
          ),
          SkFilterChip(label: 'All groups', dropdown: true, onTap: () => _toast('Group filter')),
          DateSelector(
            label: DateSelector.rangeLabel(DateTime(2026, 9, 1), DateTime(2026, 9, 23)),
            onTap: () => _toast('Pick dates'),
          ),
        ],
      ),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusChip('You owe', tone: StatusTone.youOwe),
          StatusChip('Owed to you', tone: StatusTone.owedToYou),
          StatusChip('Settled', tone: StatusTone.settled),
          StatusChip('Pending', tone: StatusTone.pending),
          StatusChip('Group', tone: StatusTone.group),
          StatusChip('Personal', tone: StatusTone.personal),
          StatusChip('Income', tone: StatusTone.income),
          StatusChip('Expense', tone: StatusTone.expense),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: MiniCalendar.week(
          day: DateTime(2026, 9, 23),
          selected: _day,
          onSelected: (d) => setState(() => _day = d),
        ),
      ),
    ],
  );

  Widget _analytics() => _Titled(
    'AnalyticsCard',
    AnalyticsCard(
      title: '{title}',
      period: '{period}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AnalyticsPlaceholder(type: '{type}'),
          const SizedBox(height: 10),
          Text('type · title · period · source', style: _mono.copyWith(fontWeight: FontWeight.w400)),
        ],
      ),
    ),
  );

  Widget _empty() => _Titled(
    'Empty',
    EmptyState(
      title: 'No expenses yet',
      body: "Add the first one and we'll keep the balances.",
      actionLabel: 'Add split',
      onAction: () => _toast('Add split'),
    ),
  );

  Widget _loading() => const _Titled('Loading', LoadingSkeleton());

  Widget _error() => _Titled(
    'Error',
    ErrorState(
      title: "Couldn't save this split",
      body: "You're offline. Your draft is kept on this device.",
      onRetry: () => _toast('Retrying…'),
    ),
  );

  Widget _dialog() => _Titled(
    'Confirmation dialog',
    _Scrim(
      alignment: Alignment.center,
      child: ConfirmDialog(
        title: 'Delete “Dinner at Thalassa”?',
        body: 'Balances for 4 people will change. You can restore it from the group for 30 days.',
        confirmLabel: 'Delete',
        onCancel: () => _toast('Cancelled'),
        onConfirm: () async {
          final ok = await showConfirmDialog(
            context,
            title: 'Delete “Dinner at Thalassa”?',
            body: 'Balances for 4 people will change. You can restore it from the group for 30 days.',
            confirmLabel: 'Delete',
          );
          _toast(ok ? 'Deleted (demo)' : 'Kept');
        },
      ),
    ),
  );

  Widget _sheet() {
    Widget options(void Function(String) pick) => Column(
      children: [
        for (final p in const [_you, _rahul, _aman])
          SheetPersonOption(person: p, selected: p.id == _payer, onTap: () => pick(p.id)),
      ],
    );
    return _Titled(
      'Bottom sheet',
      _Scrim(
        alignment: Alignment.bottomCenter,
        child: AppBottomSheet(
          title: 'Paid by',
          child: options((id) async {
            setState(() => _payer = id);
          }),
        ),
      ),
    );
  }

  Widget _admin() => _Titled(
    'Admin mode indicator',
    SkCard(
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 390,
              child: AdminFrame(
                active: true,
                radius: 8,
                child: AdminBanner(viewingAs: 'Rahul Sharma', onExit: () => _toast('Exit admin mode')),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AdminFrame(
            active: true,
            radius: 8,
            child: AdminBanner(
              viewingAs: 'Rahul Sharma',
              wide: true,
              modeNote: 'Read-only · any change is logged as Admin (Ansh C)',
              onSwitchUser: () => _toast('Switch user'),
              onExit: () => _toast('Exit admin mode'),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Amber band + amber frame around the whole viewport, on every screen, while impersonating. Never dismissible; only Exit ends it. Entries made in this mode carry an “Admin” badge everywhere they appear.',
            style: SkText.body(13, 400, color: SkColors.ink2, height: 1.45),
          ),
          const SizedBox(height: 14),
          UserSwitcher(
            users: const [_rahul, _aman, _priya, _vivek, _kabir],
            selected: _viewAs,
            onChanged: (u) => setState(() => _viewAs = u),
            onOpen: () => _toast('Open as ${_viewAs?.name}'),
          ),
        ],
      ),
    ),
  );

  Widget _splitConfig() => _Panel(
    titleSpan: TextSpan(
      children: [
        TextSpan(text: 'SplitSelector ', style: SkText.display(22, 700)),
        TextSpan(
          text: '· full, as on “How to split?”',
          style: SkText.body(14, 500, color: SkColors.ink2),
        ),
      ],
    ),
    children: [
      SplitSelector(controller: _configSplit, payerId: 'rahul', payerName: 'Rahul'),
      SplitSummary(controller: _configSplit),
    ],
  );

  Widget _addSplitPieces() => _Panel(
    title: 'AmountInput & CategorySelector',
    children: [
      AmountInput(initialMinor: 180000, onChanged: (m) => debugPrint('amount: $m')),
      CategorySelector(
        categories: const [
          CategoryOption(key: 'food', label: 'Food', icon: 'food'),
          CategoryOption(key: 'transport', label: 'Transport', icon: 'transport'),
          CategoryOption(key: 'shopping', label: 'Shopping', icon: 'shopping'),
          CategoryOption(key: 'entertainment', label: 'Fun', icon: 'entertainment'),
          CategoryOption(key: 'travel', label: 'Travel', icon: 'travel'),
          CategoryOption(key: 'stay', label: 'Stay', icon: 'rent'),
          CategoryOption(key: 'other', label: 'More', icon: 'other'),
        ],
        selected: _category,
        onSelected: (k) => setState(() => _category = k),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FriendBalanceChip(person: _rahul, state: 'you owe ₹500', tone: MoneyTone.owe, onTap: () {}),
          FriendBalanceChip(person: _priya, state: 'owes you ₹1,550', tone: MoneyTone.owed, onTap: () {}),
          SkPillButton('All groups', leading: 'filter', onPressed: () {}),
        ],
      ),
      const BalanceCard(
        netMinor: 115000,
        youOweMinor: 125000,
        youAreOwedMinor: 240000,
        layout: BalanceCardLayout.stacked,
      ),
      SkButton('Save split', onPressed: () {}, size: SkButtonSize.large, expand: true),
      Text('Icons', style: SkText.body(14, 700)),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final g in SkIcon.names)
            Tooltip(
              message: g,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: SkColors.paper, borderRadius: BorderRadius.circular(8)),
                child: SkIcon(g, size: 20),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _navigation() => _Panel(
    title: 'Navigation · BottomNav, NavRail, WebSidebar',
    children: [
      Text(
        'Under 600px a bottom bar, 600–1279px a rail, 1280px and up a sidebar.',
        style: SkText.body(13, 400, color: SkColors.ink2),
      ),
      Wrap(
        spacing: 24,
        runSpacing: 24,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          _framed(
            width: 390,
            height: 84,
            child: BottomNav(
              destinations: NavDestination.primary(),
              current: _nav,
              onSelected: (k) => setState(() => _nav = k),
            ),
          ),
          _framed(
            width: 88,
            height: 520,
            child: NavRail(
              destinations: NavDestination.primary(),
              current: _nav,
              onSelected: (k) => setState(() => _nav = k),
              onAdd: () => _toast('Add split'),
            ),
          ),
          _framed(
            width: 248,
            height: 520,
            child: WebSidebar(
              destinations: NavDestination.primary(admin: true),
              current: _nav,
              onSelected: (k) => setState(() => _nav = k),
              onAdd: () => _toast('Add split'),
              user: const SkPerson(id: 'you', name: 'Ansh C', colors: (Color(0xFFE4E0FB), Color(0xFF3326A8))),
              role: 'Administrator',
            ),
          ),
        ],
      ),
    ],
  );

  Widget _framed({required double width, required double height, required Widget child}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      border: Border.all(color: SkColors.line),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: MediaQuery.removePadding(context: context, removeBottom: true, child: child),
  );
}

final _mono = SkText.body(
  12,
  700,
  color: SkColors.ink2,
).copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Courier New']);

/// Section with a display title above free-standing content (BalanceCard, Empty, …).
class _Titled extends StatelessWidget {
  const _Titled(this.title, this.child);
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: SkText.display(20, 700)),
      const SizedBox(height: 10),
      child,
    ],
  );
}

/// White bordered panel (Buttons, Inputs, SplitSelector…): padding 24, radius 20, gap 14.
class _Panel extends StatelessWidget {
  const _Panel({this.title, this.titleSpan, required this.children});
  final String? title;
  final TextSpan? titleSpan;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SkCard(
    radius: 20,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titleSpan != null ? Text.rich(titleSpan!) : Text(title!, style: SkText.display(22, 700)),
        for (final c in children) ...[const SizedBox(height: 14), c],
      ],
    ),
  );
}

/// Grey backdrop the mockup uses to show a dialog or sheet in place.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.child, required this.alignment});
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Container(
    height: 300,
    decoration: BoxDecoration(color: SkPalette.scrim, borderRadius: BorderRadius.circular(18)),
    clipBehavior: Clip.antiAlias,
    alignment: alignment,
    child: child,
  );
}

/// The mockup's CSS grids: up to [columns] equal columns, fewer when each would be
/// narrower than [minColumnWidth].
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.gap, required this.minColumnWidth, required this.children});
  final int columns;
  final double gap;
  final double minColumnWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = ((constraints.maxWidth + gap) / (minColumnWidth + gap)).floor().clamp(1, columns);
        final width = (constraints.maxWidth - gap * (fit - 1)) / fit;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in children) SizedBox(width: width, child: c)],
        );
      },
    );
  }
}
