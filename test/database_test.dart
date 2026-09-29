import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floosy/data/database/app_database.dart';

void main() {
  test('new database seeds a cash account and categories', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final accounts = await database.watchAccounts().first;
    final categories = await database.watchCategories().first;

    expect(accounts.single.id, 'account-cash');
    expect(categories, isNotEmpty);
    expect(await database.balanceForAccount('account-cash'), 0);
  });

  test('transaction stream is unlimited and newest first', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.utc(2026, 1, 1);

    await database.batch((batch) {
      for (var index = 0; index < 501; index++) {
        final timestamp = now.add(Duration(minutes: index));
        batch.insert(
          database.financeTransactions,
          FinanceTransactionsCompanion.insert(
            id: 'transaction-$index',
            kind: 'expense',
            amountMinor: index + 1,
            accountId: 'account-cash',
            occurredAt: timestamp,
            createdAt: timestamp,
            updatedAt: timestamp,
            sourceFingerprint: Value('fingerprint-$index'),
          ),
        );
      }
    });

    final transactions = await database.watchTransactions().first;

    expect(transactions, hasLength(501));
    expect(transactions.first.id, 'transaction-500');
    expect(transactions.last.id, 'transaction-0');
  });
}
