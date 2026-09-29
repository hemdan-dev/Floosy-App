import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floosy/data/database/app_database.dart';
import 'package:floosy/data/repositories/finance_repository.dart';

void main() {
  test(
    'editing preserves technical metadata and queues a full upsert',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftFinanceRepository(database);
      final occurredAt = DateTime.utc(2026, 2, 10, 9, 30);
      final id = await repository.createTransaction(
        CreateTransactionInput(
          kind: 'expense',
          amountMinor: 1200,
          currencyCode: 'EGP',
          accountId: 'account-cash',
          categoryId: 'category-food',
          cardId: 'card-preserved',
          merchant: 'Old merchant',
          tags: const ['imported'],
          source: 'sms',
          sourceFingerprint: 'sms-1',
          status: 'posted',
          exchangeRateToBase: 1.25,
          occurredAt: occurredAt,
        ),
      );
      final before = await (database.select(
        database.financeTransactions,
      )..where((row) => row.id.equals(id))).getSingle();

      await repository.updateTransaction(
        id,
        UpdateTransactionInput(
          kind: 'income',
          amountMinor: 2500,
          currencyCode: 'EGP',
          accountId: 'account-cash',
          categoryId: 'category-income',
          merchant: 'Updated merchant',
          note: 'Corrected',
          occurredAt: DateTime.utc(2026, 2, 11, 15, 45),
        ),
      );

      final after = await (database.select(
        database.financeTransactions,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(after.kind, 'income');
      expect(after.amountMinor, 2500);
      expect(after.categoryId, 'category-income');
      expect(after.cardId, 'card-preserved');
      expect(after.tagsJson, '["imported"]');
      expect(after.source, 'sms');
      expect(after.sourceFingerprint, 'sms-1');
      expect(after.status, 'posted');
      expect(after.exchangeRateToBase, 1.25);
      expect(after.createdAt, before.createdAt);
      expect(after.syncStamp, isNot(before.syncStamp));

      final operations =
          await (database.select(database.syncOperations)
                ..where((row) => row.entityId.equals(id))
                ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
              .get();
      expect(operations, hasLength(2));
      final payload = operations
          .map((operation) => jsonDecode(operation.payloadJson) as Map)
          .singleWhere((payload) => payload['kind'] == 'income');
      expect(payload['kind'], 'income');
      expect(payload['amountMinor'], 2500);
      expect(payload['source'], 'sms');
      expect(payload['tags'], ['imported']);
    },
  );

  test('balance reconciliation is signed and excluded from reports', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftFinanceRepository(database);
    final now = DateTime.now();
    await repository.createTransaction(
      CreateTransactionInput(
        kind: 'expense',
        amountMinor: 1000,
        currencyCode: 'EGP',
        accountId: 'account-cash',
        categoryId: 'category-food',
        occurredAt: now,
      ),
    );

    final increaseId = await repository.reconcileTotalBalance(
      targetBalanceMinor: 5000,
      accountId: 'account-cash',
      occurredAt: now,
    );
    expect(increaseId, isNotNull);
    expect(await database.balanceForAccount('account-cash'), 5000);
    var summary = await repository.dashboardSummary();
    expect(summary.expenseMinor, 1000);
    expect(summary.incomeMinor, 0);

    final decreaseId = await repository.reconcileTotalBalance(
      targetBalanceMinor: -2000,
      accountId: 'account-cash',
      occurredAt: now,
    );
    expect(decreaseId, isNotNull);
    expect(await database.balanceForAccount('account-cash'), -2000);
    final adjustments = await (database.select(
      database.financeTransactions,
    )..where((row) => row.kind.equals('adjustment'))).get();
    expect(adjustments.map((row) => row.amountMinor), [6000, -7000]);

    final countBefore = adjustments.length;
    final unchanged = await repository.reconcileTotalBalance(
      targetBalanceMinor: -2000,
      accountId: 'account-cash',
    );
    expect(unchanged, isNull);
    final countAfter =
        await (database.select(database.financeTransactions)
              ..where((row) => row.kind.equals('adjustment')))
            .get()
            .then((rows) => rows.length);
    expect(countAfter, countBefore);
    summary = await repository.dashboardSummary();
    expect(summary.expenseMinor, 1000);
    expect(summary.incomeMinor, 0);
    expect(summary.balanceMinor, -2000);
  });

  test(
    'transfer edits require different source and destination accounts',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftFinanceRepository(database);
      final id = await repository.createTransaction(
        CreateTransactionInput(
          kind: 'expense',
          amountMinor: 100,
          currencyCode: 'EGP',
          accountId: 'account-cash',
          occurredAt: DateTime.now(),
        ),
      );

      expect(
        () => repository.updateTransaction(
          id,
          UpdateTransactionInput(
            kind: 'transfer',
            amountMinor: 100,
            currencyCode: 'EGP',
            accountId: 'account-cash',
            destinationAccountId: 'account-cash',
            occurredAt: DateTime.now(),
          ),
        ),
        throwsArgumentError,
      );
    },
  );
}
