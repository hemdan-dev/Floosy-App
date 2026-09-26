import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../app_providers.dart';
import '../core/money.dart';
import '../data/database/app_database.dart' as data;

const _uuid = Uuid();

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    return _ManagementScaffold(
      title: 'Accounts',
      onAdd: () => _addAccount(context, ref),
      child: accounts.when(
        data: (items) => items.isEmpty
            ? const _NoItems('No accounts yet.')
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return FutureBuilder<int>(
                    future: ref
                        .read(databaseProvider)
                        .balanceForAccount(item.id),
                    builder: (context, snapshot) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        title: Text(item.name),
                        subtitle: Text('${item.type} • ${item.currencyCode}'),
                        trailing: Text(
                          Money(
                            snapshot.data ?? item.initialBalanceMinor,
                            item.currencyCode,
                          ).format(),
                        ),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final balance = TextEditingController(text: '0');
    var type = 'cash';
    var currency = 'EGP';
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('New account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const ['cash', 'bank', 'wallet', 'credit']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => update(() => type = value!),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: balance,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Opening balance',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: currency,
                    items: const ['EGP', 'USD', 'EUR', 'GBP', 'SAR', 'AED']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => update(() => currency = value!),
                  ),
                ],
              ),
            ],
          ),
          actions: _dialogActions(context),
        ),
      ),
    );
    if (approved != true || name.text.trim().isEmpty) return;
    final now = DateTime.now().toUtc();
    await ref
        .read(databaseProvider)
        .into(ref.read(databaseProvider).accounts)
        .insert(
          data.AccountsCompanion.insert(
            id: _uuid.v7(),
            name: name.text.trim(),
            type: Value(type),
            currencyCode: Value(currency),
            initialBalanceMinor: Value(Money.parseMinor(balance.text)),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}

class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);
    return _ManagementScaffold(
      title: 'Cards',
      onAdd: () => _addCard(context, ref),
      child: StreamBuilder<List<data.Card>>(
        stream: (database.select(
          database.cards,
        )..where((row) => row.deletedAt.isNull())).watch(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const _NoItems('Add a debit or credit card.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: items
                .map(
                  (item) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.credit_card),
                      title: Text(item.name),
                      subtitle: Text(
                        item.lastFour == null
                            ? 'No ending digits'
                            : '•••• ${item.lastFour}',
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Future<void> _addCard(BuildContext context, WidgetRef ref) async {
    final accounts = await ref.read(accountsProvider.future);
    if (!context.mounted) return;
    if (accounts.isEmpty) return;
    final name = TextEditingController();
    final lastFour = TextEditingController();
    var accountId = accounts.first.id;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('New card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Card name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lastFour,
                maxLength: 4,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Last four digits',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Linked account'),
                items: accounts
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => update(() => accountId = value!),
              ),
            ],
          ),
          actions: _dialogActions(context),
        ),
      ),
    );
    if (approved != true || name.text.trim().isEmpty) return;
    final now = DateTime.now().toUtc();
    final database = ref.read(databaseProvider);
    await database
        .into(database.cards)
        .insert(
          data.CardsCompanion.insert(
            id: _uuid.v7(),
            accountId: accountId,
            name: name.text.trim(),
            lastFour: Value(
              lastFour.text.trim().isEmpty ? null : lastFour.text.trim(),
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    return _ManagementScaffold(
      title: 'Budgets',
      onAdd: () => _addBudget(context, ref),
      child: budgets.when(
        data: (items) => items.isEmpty
            ? const _NoItems('Create a monthly spending limit.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: items
                    .map(
                      (item) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.savings_outlined),
                          title: Text(item.name),
                          subtitle: const Text('Monthly limit'),
                          trailing: Text(
                            Money(item.limitMinor, item.currencyCode).format(),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Future<void> _addBudget(BuildContext context, WidgetRef ref) async {
    final categories = await ref.read(categoriesProvider.future);
    if (!context.mounted) return;
    final name = TextEditingController();
    final amount = TextEditingController();
    String? categoryId;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('New budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly limit (EGP)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: categoryId,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All expenses'),
                  ),
                  ...categories.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: (value) => update(() => categoryId = value),
              ),
            ],
          ),
          actions: _dialogActions(context),
        ),
      ),
    );
    if (approved != true) return;
    final now = DateTime.now().toUtc();
    final database = ref.read(databaseProvider);
    await database
        .into(database.budgets)
        .insert(
          data.BudgetsCompanion.insert(
            id: _uuid.v7(),
            name: name.text.trim(),
            categoryId: Value(categoryId),
            limitMinor: Money.parseMinor(amount.text),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}

class InstallmentsScreen extends ConsumerWidget {
  const InstallmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(installmentsProvider);
    return _ManagementScaffold(
      title: 'Installments',
      onAdd: () => _addPlan(context, ref),
      child: plans.when(
        data: (items) => items.isEmpty
            ? const _NoItems('Track a purchase installment plan.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: items
                    .map(
                      (item) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_month_outlined),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.paidCount}/${item.installmentCount} paid • next ${item.nextDueAt.toLocal().toString().split(' ').first}',
                          ),
                          trailing: Text(
                            Money(
                              item.paymentMinor,
                              item.currencyCode,
                            ).format(),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Future<void> _addPlan(BuildContext context, WidgetRef ref) async {
    final accounts = await ref.read(accountsProvider.future);
    if (!context.mounted) return;
    if (accounts.isEmpty) return;
    final name = TextEditingController();
    final total = TextEditingController();
    final count = TextEditingController(text: '12');
    var accountId = accounts.first.id;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('New installment plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Purchase'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: total,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Total (EGP)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: count,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of payments',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: accounts
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => update(() => accountId = value!),
              ),
            ],
          ),
          actions: _dialogActions(context),
        ),
      ),
    );
    if (approved != true) return;
    final totalMinor = Money.parseMinor(total.text);
    final number = int.parse(count.text);
    final now = DateTime.now().toUtc();
    final database = ref.read(databaseProvider);
    final id = _uuid.v7();
    await database
        .into(database.installmentPlans)
        .insert(
          data.InstallmentPlansCompanion.insert(
            id: id,
            name: name.text.trim(),
            accountId: accountId,
            totalMinor: totalMinor,
            paymentMinor: (totalMinor / number).round(),
            installmentCount: number,
            nextDueAt: DateTime(now.year, now.month + 1, now.day),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final plan = await (database.select(
      database.installmentPlans,
    )..where((row) => row.id.equals(id))).getSingle();
    await ref.read(notificationServiceProvider).scheduleInstallment(plan);
  }
}

class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetsProvider);
    return _ManagementScaffold(
      title: 'Assets & net worth',
      onAdd: () => _addAsset(context, ref),
      actions: [
        IconButton(
          tooltip: 'Refresh gold price',
          onPressed: () async {
            try {
              final price = await ref
                  .read(marketDataProvider)
                  .goldOunceUsd(refresh: true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gold: USD ${price.toStringAsFixed(2)} / oz'),
                  ),
                );
              }
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: assets.when(
        data: (items) => items.isEmpty
            ? const _NoItems('Track cash, property, gold, or investments.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: items
                    .map(
                      (item) => Card(
                        child: ListTile(
                          leading: Icon(
                            item.type == 'gold'
                                ? Icons.diamond_outlined
                                : Icons.trending_up,
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.quantity} ${item.unit} • ${item.type}',
                          ),
                          trailing: item.manualValueMinor == null
                              ? const Text('Market')
                              : Text(
                                  Money(
                                    item.manualValueMinor!,
                                    item.currencyCode,
                                  ).format(),
                                ),
                        ),
                      ),
                    )
                    .toList(),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Future<void> _addAsset(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final value = TextEditingController();
    var type = 'manual';
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('New asset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const ['manual', 'gold', 'property', 'investment']
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (item) => update(() => type = item!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Current value (EGP)',
                ),
              ),
            ],
          ),
          actions: _dialogActions(context),
        ),
      ),
    );
    if (approved != true) return;
    final now = DateTime.now().toUtc();
    final database = ref.read(databaseProvider);
    await database
        .into(database.assets)
        .insert(
          data.AssetsCompanion.insert(
            id: _uuid.v7(),
            name: name.text.trim(),
            type: type,
            manualValueMinor: Value(Money.parseMinor(value.text)),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return _ManagementScaffold(
      title: 'Categories',
      onAdd: () async {
        final name = TextEditingController();
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('New category'),
            content: TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            actions: _dialogActions(context),
          ),
        );
        if (approved != true || name.text.trim().isEmpty) return;
        final now = DateTime.now().toUtc();
        final database = ref.read(databaseProvider);
        await database
            .into(database.categories)
            .insert(
              data.CategoriesCompanion.insert(
                id: _uuid.v7(),
                name: name.text.trim(),
                createdAt: now,
                updatedAt: now,
              ),
            );
      },
      child: categories.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: items
              .map(
                (item) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(item.colorValue),
                      child: const Icon(
                        Icons.category_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(item.name),
                    subtitle: Text(item.kind),
                  ),
                ),
              )
              .toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _ManagementScaffold extends StatelessWidget {
  const _ManagementScaffold({
    required this.title,
    required this.onAdd,
    required this.child,
    this.actions = const [],
  });
  final String title;
  final VoidCallback onAdd;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: child,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: onAdd,
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    ),
  );
}

class _NoItems extends StatelessWidget {
  const _NoItems(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

List<Widget> _dialogActions(BuildContext context) => [
  TextButton(
    onPressed: () => Navigator.pop(context, false),
    child: const Text('Cancel'),
  ),
  FilledButton(
    onPressed: () => Navigator.pop(context, true),
    child: const Text('Save'),
  ),
];
