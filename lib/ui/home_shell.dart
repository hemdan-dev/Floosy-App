import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_providers.dart';
import '../core/app_localizations.dart';
import '../core/money.dart';
import '../data/database/app_database.dart' hide Card;
import '../data/repositories/finance_repository.dart';
import 'add_transaction_screen.dart';
import 'edit_transaction_screen.dart';
import 'management_screens.dart';
import 'settings_screen.dart';
import 'transaction_history_models.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({
    super.key,
    required this.onLocaleChanged,
    required this.onThemeChanged,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;
  bool _captureIngestionRunning = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>(() async {
      await _ingestCapturesAndOpenReview();
      try {
        final drive = ref.read(driveSyncProvider);
        await drive.initialize();
        final connectivity = await Connectivity().checkConnectivity();
        if (drive.connectedEmail != null &&
            !connectivity.contains(ConnectivityResult.none)) {
          await drive.sync();
        }
      } catch (_) {
        // Settings surfaces OAuth configuration errors when sync is requested.
      }
      try {
        await ref.read(notificationServiceProvider).rescheduleInstallments();
      } catch (_) {
        // Reminders can be granted later without blocking the finance app.
      }
      try {
        await ref.read(widgetServiceProvider).refresh();
      } catch (_) {
        // A missing home-screen widget must not block app startup.
      }
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      if (results.contains(ConnectivityResult.none)) return;
      final sync = ref.read(driveSyncProvider);
      if (sync.connectedEmail == null) return;
      try {
        await sync.sync();
      } catch (_) {
        // The next reconnect or manual refresh will retry the operation log.
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_ingestCapturesAndOpenReview());
    }
  }

  Future<void> _ingestCapturesAndOpenReview() async {
    if (_captureIngestionRunning) return;
    _captureIngestionRunning = true;
    try {
      final count = await ref
          .read(captureServiceProvider)
          .ingestPlatformCaptures(retryOnEmpty: true);
      if (count == 0 || !mounted) return;
      setState(() => _index = 2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                count == 1
                    ? 'SMS captured. Review it below.'
                    : '$count SMS messages captured. Review them below.',
              ),
            ),
          );
      });
    } catch (_) {
      // Platform capture remains optional and is retried on the next resume.
    } finally {
      _captureIngestionRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final pages = [
      OverviewScreen(onSelectTab: (index) => setState(() => _index = index)),
      const TransactionsScreen(),
      const AddTransactionScreen(),
      const InsightsScreen(),
      const AskScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      drawer: _AppDrawer(
        onLocaleChanged: widget.onLocaleChanged,
        onThemeChanged: widget.onThemeChanged,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          _destination(
            Icons.space_dashboard_outlined,
            Icons.space_dashboard_rounded,
            strings.text('overview'),
          ),
          _destination(
            Icons.receipt_long_outlined,
            Icons.receipt_long_rounded,
            strings.text('transactions'),
          ),
          _destination(
            Icons.add_circle_outline_rounded,
            Icons.add_circle_rounded,
            strings.text('add'),
          ),
          _destination(
            Icons.insights_outlined,
            Icons.insights_rounded,
            strings.text('insights'),
          ),
          _destination(
            Icons.auto_awesome_outlined,
            Icons.auto_awesome_rounded,
            strings.text('ask'),
          ),
        ],
      ),
    );
  }

  NavigationDestination _destination(
    IconData icon,
    IconData selected,
    String label,
  ) => NavigationDestination(
    icon: Icon(icon),
    selectedIcon: Icon(selected),
    label: label,
  );
}

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider).value;
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await ref.read(driveSyncProvider).sync();
        } catch (_) {
          // Local data remains available while offline or disconnected.
        }
        ref.invalidate(transactionsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.text('appName'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(DateFormat.yMMMM().format(DateTime.now())),
                  ],
                ),
              ),
              Builder(
                builder: (drawerContext) => IconButton.filledTonal(
                  onPressed: () => Scaffold.of(drawerContext).openDrawer(),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<DashboardSummary>(
            future: ref.read(financeRepositoryProvider).dashboardSummary(),
            builder: (context, snapshot) => _BalanceCard(
              summary: snapshot.data,
              onEdit: snapshot.data == null || accounts == null
                  ? null
                  : () => _reconcileBalance(
                      context,
                      ref,
                      snapshot.data!,
                      accounts,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<ConnectivityResult>>(
            stream: Connectivity().onConnectivityChanged,
            builder: (context, snapshot) {
              final offline =
                  snapshot.data?.contains(ConnectivityResult.none) ?? false;
              return offline
                  ? Card(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.cloud_off_rounded),
                        title: Text(strings.text('offline')),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
          _SectionHeader(
            title: strings.text('recent'),
            onTap: () => onSelectTab(1),
          ),
          transactions.when(
            data: (items) => items.isEmpty
                ? EmptyState(text: strings.text('emptyTransactions'))
                : Column(
                    children: items
                        .take(6)
                        .map((item) => TransactionTile(item: item))
                        .toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
          ),
          const SizedBox(height: 18),
          Text('Plan & track', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _feature(
                context,
                Icons.savings_outlined,
                strings.text('budgets'),
                const BudgetsScreen(),
              ),
              _feature(
                context,
                Icons.calendar_month_outlined,
                strings.text('installments'),
                const InstallmentsScreen(),
              ),
              _feature(
                context,
                Icons.account_balance_wallet_outlined,
                strings.text('accounts'),
                const AccountsScreen(),
              ),
              _feature(
                context,
                Icons.trending_up_rounded,
                strings.text('assets'),
                const AssetsScreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feature(
    BuildContext context,
    IconData icon,
    String label,
    Widget screen,
  ) => ActionChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    padding: const EdgeInsets.all(10),
    onPressed: () =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
  );

  Future<void> _reconcileBalance(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary summary,
    List<Account> accountRows,
  ) async {
    final strings = AppLocalizations.of(context);
    final accounts = accountRows
        .where((item) => item.includeInNetWorth)
        .toList();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('noBalanceAccounts'))),
      );
      return;
    }
    final reconciliation = await showDialog<_BalanceReconciliation>(
      context: context,
      builder: (context) =>
          _BalanceReconciliationDialog(summary: summary, accounts: accounts),
    );
    if (reconciliation == null || !context.mounted) return;
    try {
      final id = await ref
          .read(financeRepositoryProvider)
          .reconcileTotalBalance(
            targetBalanceMinor: reconciliation.targetBalanceMinor,
            accountId: reconciliation.accountId,
          );
      await ref.read(widgetServiceProvider).refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              strings.text(
                id == null ? 'noAdjustmentNeeded' : 'balanceUpdated',
              ),
            ),
          ),
        );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

typedef _BalanceReconciliation = ({String accountId, int targetBalanceMinor});

class _BalanceReconciliationDialog extends StatefulWidget {
  const _BalanceReconciliationDialog({
    required this.summary,
    required this.accounts,
  });

  final DashboardSummary summary;
  final List<Account> accounts;

  @override
  State<_BalanceReconciliationDialog> createState() =>
      _BalanceReconciliationDialogState();
}

class _BalanceReconciliationDialogState
    extends State<_BalanceReconciliationDialog> {
  late final TextEditingController _target;
  late String _accountId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _target = TextEditingController(
      text: (widget.summary.balanceMinor / 100).toStringAsFixed(2),
    );
    _accountId = widget.accounts.first.id;
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(strings.text('editTotalBalance')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${strings.text('currentBalance')}: '
              '${Money(widget.summary.balanceMinor, widget.summary.currencyCode).format()}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _target,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: strings.text('correctedBalance'),
                suffixText: widget.summary.currencyCode,
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(
                labelText: strings.text('adjustmentAccount'),
              ),
              items: widget.accounts
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text('${item.name} • ${item.currencyCode}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _accountId = value!),
            ),
            const SizedBox(height: 10),
            Text(
              strings.text('adjustmentExcluded'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.text('cancel')),
        ),
        FilledButton(
          onPressed: () {
            try {
              final targetBalanceMinor = Money.parseMinor(_target.text);
              Navigator.pop(context, (
                accountId: _accountId,
                targetBalanceMinor: targetBalanceMinor,
              ));
            } on FormatException {
              setState(() => _error = strings.text('invalidAmount'));
            }
          },
          child: Text(strings.text('saveChanges')),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.onEdit});
  final DashboardSummary? summary;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final currency = summary?.currencyCode ?? 'EGP';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0E684E), Color(0xFF1D9670)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33177A5B),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.text('balance'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    if (onEdit != null)
                      const Icon(
                        Icons.edit_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  Money(summary?.balanceMinor ?? 0, currency).format(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: strings.text('income'),
                        value: Money(
                          summary?.incomeMinor ?? 0,
                          currency,
                        ).format(),
                        icon: Icons.south_west_rounded,
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: strings.text('spent'),
                        value: Money(
                          summary?.expenseMinor ?? 0,
                          currency,
                        ).format(),
                        icon: Icons.north_east_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        backgroundColor: Colors.white12,
        child: Icon(icon, color: Colors.white),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ],
  );
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _query = '';
  String _kind = 'all';

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final data = ref.watch(transactionsProvider);
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final items = data.value ?? const <FinanceTransaction>[];
    final filtered = items.where((item) {
      final kindMatches = _kind == 'all' || item.kind == _kind;
      final searchable =
          '${item.merchant ?? ''} ${item.note ?? ''} ${item.kind}'
              .toLowerCase();
      return kindMatches && searchable.contains(_query);
    }).toList();
    final months = groupTransactionsByMonthAndDay(filtered);
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(title: Text(strings.text('transactions'))),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          sliver: SliverList.list(
            children: [
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search merchant or note',
                ),
                onChanged: (value) =>
                    setState(() => _query = value.toLowerCase()),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'expense', label: Text('Expenses')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {_kind},
                onSelectionChanged: (value) =>
                    setState(() => _kind = value.first),
              ),
            ],
          ),
        ),
        if (data.isLoading && items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (data.hasError && items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(data.error.toString())),
          )
        else if (months.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(text: strings.text('emptyTransactions')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList.builder(
              itemCount: months.length,
              itemBuilder: (context, index) {
                final month = months[index];
                final allMonthTransactions = items
                    .where((item) => transactionIsInMonth(item, month.month))
                    .toList();
                return _TransactionMonthSection(
                  group: month,
                  allMonthTransactions: allMonthTransactions,
                  categories: categories,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TransactionMonthSection extends StatelessWidget {
  const _TransactionMonthSection({
    required this.group,
    required this.allMonthTransactions,
    required this.categories,
  });

  final TransactionMonthGroup group;
  final List<FinanceTransaction> allMonthTransactions;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMM(locale).format(group.month),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          _MonthlyExpenseDonut(
            month: group.month,
            transactions: allMonthTransactions,
            categories: categories,
          ),
          const SizedBox(height: 18),
          for (final day in group.days) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text(
                DateFormat.yMMMMEEEEd(locale).format(day.day),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final item in day.transactions)
              TransactionTile(item: item, showDate: false),
          ],
        ],
      ),
    );
  }
}

class _MonthlyExpenseDonut extends StatelessWidget {
  const _MonthlyExpenseDonut({
    required this.month,
    required this.transactions,
    required this.categories,
  });

  final DateTime month;
  final List<FinanceTransaction> transactions;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final summaries = summarizeExpensesByCategory(
      transactions,
      categories,
      uncategorizedName: strings.text('uncategorized'),
    );
    if (summaries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.donut_large_outlined,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(strings.text('noMonthlyExpenses'))),
            ],
          ),
        ),
      );
    }
    final total = summaries.fold<int>(
      0,
      (sum, category) => sum + category.totalMinor,
    );
    final currency =
        transactions
            .where((item) => item.kind == 'expense')
            .firstOrNull
            ?.currencyCode ??
        'EGP';

    void openCategory(ExpenseCategorySummary summary) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryTransactionsScreen(
            month: month,
            categoryId: summary.categoryId,
            fallbackCategoryName: summary.name,
            colorValue: summary.colorValue,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.text('expensesByCategory'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 48,
                  sectionsSpace: 3,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final index =
                          response?.touchedSection?.touchedSectionIndex;
                      if (index == null ||
                          index < 0 ||
                          index >= summaries.length) {
                        return;
                      }
                      openCategory(summaries[index]);
                    },
                  ),
                  sections: summaries.map((summary) {
                    final percentage = summary.totalMinor / total * 100;
                    return PieChartSectionData(
                      value: summary.totalMinor.toDouble(),
                      color: Color(summary.colorValue),
                      radius: 36,
                      title: percentage >= 7
                          ? '${percentage.toStringAsFixed(0)}%'
                          : '',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (final summary in summaries)
              InkWell(
                onTap: () => openCategory(summary),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(summary.colorValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(summary.name)),
                      Text(
                        Money(summary.totalMinor, currency).format(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CategoryTransactionsScreen extends ConsumerWidget {
  const CategoryTransactionsScreen({
    super.key,
    required this.month,
    required this.categoryId,
    required this.fallbackCategoryName,
    required this.colorValue,
  });

  final DateTime month;
  final String? categoryId;
  final String fallbackCategoryName;
  final int colorValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final currentCategory = categoryId == null
        ? null
        : categories.where((item) => item.id == categoryId).firstOrNull;
    final categoryName = currentCategory?.name ?? fallbackCategoryName;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final transactions = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: transactions.when(
        data: (items) {
          final rows = transactionsForExpenseCategoryMonth(
            items,
            categories,
            month: month,
            categoryId: categoryId,
          );
          final days =
              groupTransactionsByMonthAndDay(rows).firstOrNull?.days ??
              const <TransactionDayGroup>[];
          final total = rows.fold<int>(
            0,
            (sum, transaction) => sum + transaction.amountMinor,
          );
          final currency = rows.firstOrNull?.currencyCode ?? 'EGP';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(colorValue),
                        child: const Icon(
                          Icons.category_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat.yMMMM(locale).format(month)),
                            Text(
                              Money(total, currency).format(),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              '${rows.length} ${strings.text('transactions').toLowerCase()}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (rows.isEmpty)
                EmptyState(text: strings.text('emptyCategoryTransactions'))
              else
                for (final day in days) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                    child: Text(
                      DateFormat.yMMMMEEEEd(locale).format(day.day),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final item in day.transactions)
                    TransactionTile(item: item, showDate: false),
                ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class TransactionTile extends ConsumerWidget {
  const TransactionTile({super.key, required this.item, this.showDate = true});
  final FinanceTransaction item;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = item.kind == 'income';
    final isAdjustment = item.kind == 'adjustment';
    final isTransfer = item.kind == 'transfer';
    final strings = AppLocalizations.of(context);
    final amountIsPositive =
        isIncome || (isAdjustment && item.amountMinor >= 0);
    final amountColor = isAdjustment
        ? Theme.of(context).colorScheme.primary
        : isIncome
        ? Colors.green
        : null;
    final icon = isAdjustment
        ? Icons.tune_rounded
        : isTransfer
        ? Icons.swap_horiz_rounded
        : isIncome
        ? Icons.south_west_rounded
        : Icons.north_east_rounded;
    final iconColor = isAdjustment
        ? Theme.of(context).colorScheme.primary
        : isTransfer
        ? Colors.indigo
        : isIncome
        ? Colors.green
        : Colors.deepOrange;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete transaction?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(financeRepositoryProvider).deleteTransaction(item.id);
        await ref.read(widgetServiceProvider).refresh();
      },
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.all(20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditTransactionScreen(transaction: item),
            ),
          ),
          leading: CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: .14),
            child: Icon(icon, color: iconColor),
          ),
          title: Text(
            isAdjustment
                ? strings.text('balanceAdjustment')
                : item.merchant ?? item.note ?? item.kind,
          ),
          subtitle: Text(
            showDate
                ? DateFormat.MMMd().add_jm().format(item.occurredAt.toLocal())
                : DateFormat.jm().format(item.occurredAt.toLocal()),
          ),
          trailing: Text(
            '${amountIsPositive ? '+' : '-'}'
            '${Money(item.amountMinor.abs(), item.currencyCode).format()}',
            style: TextStyle(fontWeight: FontWeight.w700, color: amountColor),
          ),
        ),
      ),
    );
  }
}

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(transactionsProvider);
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('Insights')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList.list(
            children: [
              items.when(
                data: (rows) {
                  final now = DateTime.now();
                  final monthly = rows
                      .where(
                        (row) =>
                            row.kind == 'expense' &&
                            row.occurredAt.year == now.year &&
                            row.occurredAt.month == now.month,
                      )
                      .toList();
                  final byDay = <int, int>{};
                  for (final row in monthly) {
                    byDay.update(
                      row.occurredAt.day,
                      (value) => value + row.amountMinor,
                      ifAbsent: () => row.amountMinor,
                    );
                  }
                  final maxMinor = byDay.values.isEmpty
                      ? 100
                      : byDay.values.reduce(math.max);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily spending',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(
                              topTitles: AxisTitles(),
                              rightTitles: AxisTitles(),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 44,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: true),
                              ),
                            ),
                            barGroups: byDay.entries
                                .map(
                                  (entry) => BarChartGroupData(
                                    x: entry.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value / 100,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: math.max(
                                          4,
                                          180 / math.max(1, byDay.length),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                            maxY: maxMinor / 100 * 1.2,
                          ),
                        ),
                      ),
                      _InsightCard(
                        icon: Icons.calendar_today_outlined,
                        title: 'Month pace',
                        text: monthly.isEmpty
                            ? 'Add expenses to see your monthly pace.'
                            : 'You recorded ${monthly.length} expenses this month.',
                      ),
                      _InsightCard(
                        icon: Icons.auto_graph_rounded,
                        title: 'Largest expense',
                        text: monthly.isEmpty
                            ? 'No expense yet.'
                            : Money(
                                monthly
                                    .map((row) => row.amountMinor)
                                    .reduce(math.max),
                                monthly.first.currencyCode,
                              ).format(),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text(error.toString()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key});

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _controller = TextEditingController();
  final _messages = <(bool, String)>[];
  bool _loading = false;

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _loading) return;
    setState(() {
      _messages.add((true, question));
      _controller.clear();
      _loading = true;
    });
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final data = await ref.read(financeRepositoryProvider).assistantContext();
      final answer = await ref
          .read(aiGatewayProvider)
          .answer(question: question, financialContext: data, locale: locale);
      if (mounted) setState(() => _messages.add((false, answer)));
    } catch (error) {
      if (mounted) setState(() => _messages.add((false, error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('ask'))),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const EmptyState(
                    text:
                        'Ask “How much did I spend this month?” or “What were my largest expenses?”',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.$1
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 340),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: message.$1
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(message.$2),
                        ),
                      );
                    },
                  ),
          ),
          if (_loading) const LinearProgressIndicator(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _ask(),
                      decoration: InputDecoration(
                        hintText: strings.text('askHint'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _ask,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.onLocaleChanged,
    required this.onThemeChanged,
  });
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const ListTile(
              leading: CircleAvatar(child: Text('F')),
              title: Text(
                'Floosy',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Private • Offline-first'),
            ),
            const Divider(),
            _link(
              context,
              Icons.account_balance_wallet_outlined,
              strings.text('accounts'),
              const AccountsScreen(),
            ),
            _link(
              context,
              Icons.credit_card_outlined,
              strings.text('cards'),
              const CardsScreen(),
            ),
            _link(
              context,
              Icons.savings_outlined,
              strings.text('budgets'),
              const BudgetsScreen(),
            ),
            _link(
              context,
              Icons.calendar_month_outlined,
              strings.text('installments'),
              const InstallmentsScreen(),
            ),
            _link(
              context,
              Icons.trending_up_rounded,
              strings.text('assets'),
              const AssetsScreen(),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(strings.text('settings')),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    onLocaleChanged: onLocaleChanged,
                    onThemeChanged: onThemeChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _link(
    BuildContext context,
    IconData icon,
    String title,
    Widget screen,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: () =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 44,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(
        onPressed: onTap,
        child: Text(AppLocalizations.of(context).text('seeAll')),
      ),
    ],
  );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(text),
    ),
  );
}
