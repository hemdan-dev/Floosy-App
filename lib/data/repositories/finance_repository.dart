import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/hybrid_clock.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

class CreateTransactionInput {
  const CreateTransactionInput({
    required this.kind,
    required this.amountMinor,
    required this.currencyCode,
    required this.accountId,
    required this.occurredAt,
    this.destinationAccountId,
    this.cardId,
    this.categoryId,
    this.merchant,
    this.note,
    this.tags = const [],
    this.source = 'manual',
    this.sourceFingerprint,
    this.status = 'posted',
    this.exchangeRateToBase = 1,
  });

  final String kind;
  final int amountMinor;
  final String currencyCode;
  final String accountId;
  final String? destinationAccountId;
  final String? cardId;
  final String? categoryId;
  final String? merchant;
  final String? note;
  final List<String> tags;
  final String source;
  final String? sourceFingerprint;
  final String status;
  final double exchangeRateToBase;
  final DateTime occurredAt;
}

class UpdateTransactionInput {
  const UpdateTransactionInput({
    required this.kind,
    required this.amountMinor,
    required this.currencyCode,
    required this.accountId,
    required this.occurredAt,
    this.destinationAccountId,
    this.categoryId,
    this.merchant,
    this.note,
  });

  final String kind;
  final int amountMinor;
  final String currencyCode;
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final String? merchant;
  final String? note;
  final DateTime occurredAt;
}

class DashboardSummary {
  const DashboardSummary({
    required this.expenseMinor,
    required this.incomeMinor,
    required this.balanceMinor,
    required this.currencyCode,
  });

  final int expenseMinor;
  final int incomeMinor;
  final int balanceMinor;
  final String currencyCode;
}

abstract interface class FinanceRepository {
  Stream<List<FinanceTransaction>> watchTransactions();
  Stream<List<Account>> watchAccounts();
  Stream<List<Category>> watchCategories();
  Stream<List<Budget>> watchBudgets();
  Stream<List<InstallmentPlan>> watchInstallments();
  Stream<List<Asset>> watchAssets();
  Stream<List<PendingCapture>> watchPendingCaptures();
  Future<DashboardSummary> dashboardSummary();
  Future<String> createTransaction(CreateTransactionInput input);
  Future<void> updateTransaction(String id, UpdateTransactionInput input);
  Future<String?> reconcileTotalBalance({
    required int targetBalanceMinor,
    required String accountId,
    DateTime? occurredAt,
    String? note,
  });
  Future<void> deleteTransaction(String id);
  Future<Map<String, Object?>> assistantContext();
}

class DriftFinanceRepository implements FinanceRepository {
  DriftFinanceRepository(this.db) : _deviceIdFuture = _loadDeviceId(db);

  final AppDatabase db;
  final Future<String> _deviceIdFuture;
  HybridClock? _clock;

  static Future<String> _loadDeviceId(AppDatabase db) async {
    final existing = await db.getSetting('deviceId');
    if (existing != null) return existing;
    final value = _uuid.v7();
    await db.setSetting('deviceId', value);
    return value;
  }

  Future<(String, HybridClock)> _identity() async {
    final deviceId = await _deviceIdFuture;
    return (deviceId, _clock ??= HybridClock(deviceId));
  }

  @override
  Stream<List<Account>> watchAccounts() => db.watchAccounts();

  @override
  Stream<List<Asset>> watchAssets() => db.watchAssets();

  @override
  Stream<List<Budget>> watchBudgets() => db.watchBudgets();

  @override
  Stream<List<Category>> watchCategories() => db.watchCategories();

  @override
  Stream<List<InstallmentPlan>> watchInstallments() => db.watchInstallments();

  @override
  Stream<List<PendingCapture>> watchPendingCaptures() =>
      db.watchPendingCaptures();

  @override
  Stream<List<FinanceTransaction>> watchTransactions() =>
      db.watchTransactions();

  @override
  Future<DashboardSummary> dashboardSummary() async {
    final data = await db.dashboardSnapshot();
    return DashboardSummary(
      expenseMinor: data['expenseMinor']! as int,
      incomeMinor: data['incomeMinor']! as int,
      balanceMinor: data['balanceMinor']! as int,
      currencyCode: data['currency']! as String,
    );
  }

  @override
  Future<String> createTransaction(CreateTransactionInput input) async {
    if (input.amountMinor <= 0) throw ArgumentError('Amount must be positive.');
    if (!['expense', 'income', 'transfer'].contains(input.kind)) {
      throw ArgumentError.value(input.kind, 'kind');
    }
    if (input.kind == 'transfer' && input.destinationAccountId == null) {
      throw ArgumentError('A transfer requires a destination account.');
    }
    final identity = await _identity();
    final stamp = identity.$2.tick();
    final id = _uuid.v7();
    final now = DateTime.now().toUtc();
    final transferGroupId = input.kind == 'transfer' ? _uuid.v7() : null;
    final companion = FinanceTransactionsCompanion.insert(
      id: id,
      kind: input.kind,
      amountMinor: input.amountMinor,
      currencyCode: Value(input.currencyCode),
      accountId: input.accountId,
      destinationAccountId: Value(input.destinationAccountId),
      transferGroupId: Value(transferGroupId),
      cardId: Value(input.cardId),
      categoryId: Value(input.categoryId),
      merchant: Value(input.merchant),
      note: Value(input.note),
      tagsJson: Value(jsonEncode(input.tags)),
      source: Value(input.source),
      sourceFingerprint: Value(input.sourceFingerprint),
      status: Value(input.status),
      exchangeRateToBase: Value(input.exchangeRateToBase),
      occurredAt: input.occurredAt.toUtc(),
      createdAt: now,
      updatedAt: now,
      syncStamp: Value(stamp),
    );
    await db.transaction(() async {
      await db.createTransaction(companion);
      final row = await (db.select(
        db.financeTransactions,
      )..where((t) => t.id.equals(id))).getSingle();
      await _enqueueUpsert(row, identity.$1, stamp, now);
    });
    return id;
  }

  @override
  Future<void> updateTransaction(
    String id,
    UpdateTransactionInput input,
  ) async {
    final existing = await (db.select(
      db.financeTransactions,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (existing == null) throw StateError('Transaction not found.');

    final isAdjustment = existing.kind == 'adjustment';
    if (isAdjustment) {
      if (input.kind != 'adjustment') {
        throw ArgumentError('Balance adjustments cannot change type.');
      }
      if (input.amountMinor == 0) {
        throw ArgumentError('Adjustment amount cannot be zero.');
      }
    } else {
      if (!['expense', 'income', 'transfer'].contains(input.kind)) {
        throw ArgumentError.value(input.kind, 'kind');
      }
      if (input.amountMinor <= 0) {
        throw ArgumentError('Amount must be positive.');
      }
      if (input.kind == 'transfer' && input.destinationAccountId == null) {
        throw ArgumentError('A transfer requires a destination account.');
      }
      if (input.kind == 'transfer' &&
          input.destinationAccountId == input.accountId) {
        throw ArgumentError('Transfer accounts must be different.');
      }
    }

    final identity = await _identity();
    final stamp = identity.$2.tick();
    final now = DateTime.now().toUtc();
    final transferGroupId = input.kind == 'transfer'
        ? (existing.kind == 'transfer'
              ? existing.transferGroupId ?? _uuid.v7()
              : _uuid.v7())
        : null;
    await db.transaction(() async {
      await (db.update(
        db.financeTransactions,
      )..where((t) => t.id.equals(id))).write(
        FinanceTransactionsCompanion(
          kind: Value(input.kind),
          amountMinor: Value(input.amountMinor),
          currencyCode: Value(input.currencyCode),
          accountId: Value(input.accountId),
          destinationAccountId: Value(
            input.kind == 'transfer' ? input.destinationAccountId : null,
          ),
          transferGroupId: Value(transferGroupId),
          categoryId: Value(
            input.kind == 'expense' || input.kind == 'income'
                ? input.categoryId
                : null,
          ),
          merchant: Value(input.merchant),
          note: Value(input.note),
          occurredAt: Value(input.occurredAt.toUtc()),
          updatedAt: Value(now),
          syncStamp: Value(stamp),
        ),
      );
      final updated = await (db.select(
        db.financeTransactions,
      )..where((t) => t.id.equals(id))).getSingle();
      await _enqueueUpsert(updated, identity.$1, stamp, now);
    });
  }

  @override
  Future<String?> reconcileTotalBalance({
    required int targetBalanceMinor,
    required String accountId,
    DateTime? occurredAt,
    String? note,
  }) async {
    final account =
        await (db.select(db.accounts)..where(
              (row) =>
                  row.id.equals(accountId) &
                  row.deletedAt.isNull() &
                  row.includeInNetWorth.equals(true),
            ))
            .getSingleOrNull();
    if (account == null) {
      throw StateError('Choose an account included in total balance.');
    }
    final current = (await dashboardSummary()).balanceMinor;
    final difference = targetBalanceMinor - current;
    if (difference == 0) return null;

    final identity = await _identity();
    final stamp = identity.$2.tick();
    final id = _uuid.v7();
    final now = DateTime.now().toUtc();
    final rowOccurredAt = (occurredAt ?? DateTime.now()).toUtc();
    await db.transaction(() async {
      await db.createTransaction(
        FinanceTransactionsCompanion.insert(
          id: id,
          kind: 'adjustment',
          amountMinor: difference,
          currencyCode: Value(account.currencyCode),
          accountId: accountId,
          note: Value(note),
          source: const Value('manual'),
          status: const Value('posted'),
          occurredAt: rowOccurredAt,
          createdAt: now,
          updatedAt: now,
          syncStamp: Value(stamp),
        ),
      );
      final row = await (db.select(
        db.financeTransactions,
      )..where((t) => t.id.equals(id))).getSingle();
      await _enqueueUpsert(row, identity.$1, stamp, now);
    });
    return id;
  }

  Future<void> _enqueueUpsert(
    FinanceTransaction row,
    String deviceId,
    String stamp,
    DateTime createdAt,
  ) {
    return db
        .into(db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: _uuid.v7(),
            deviceId: deviceId,
            entityType: 'transaction',
            entityId: row.id,
            action: 'upsert',
            stamp: stamp,
            payloadJson: jsonEncode({
              'id': row.id,
              'kind': row.kind,
              'amountMinor': row.amountMinor,
              'currencyCode': row.currencyCode,
              'accountId': row.accountId,
              'destinationAccountId': row.destinationAccountId,
              'transferGroupId': row.transferGroupId,
              'cardId': row.cardId,
              'categoryId': row.categoryId,
              'merchant': row.merchant,
              'note': row.note,
              'tags': jsonDecode(row.tagsJson),
              'source': row.source,
              'sourceFingerprint': row.sourceFingerprint,
              'status': row.status,
              'exchangeRateToBase': row.exchangeRateToBase,
              'occurredAt': row.occurredAt.toUtc().toIso8601String(),
              'createdAt': row.createdAt.toUtc().toIso8601String(),
              'updatedAt': row.updatedAt.toUtc().toIso8601String(),
              'syncStamp': stamp,
            }),
            createdAt: createdAt,
          ),
        );
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final identity = await _identity();
    final stamp = identity.$2.tick();
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      await (db.update(
        db.financeTransactions,
      )..where((t) => t.id.equals(id))).write(
        FinanceTransactionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStamp: Value(stamp),
        ),
      );
      await db
          .into(db.syncOperations)
          .insert(
            SyncOperationsCompanion.insert(
              id: _uuid.v7(),
              deviceId: identity.$1,
              entityType: 'transaction',
              entityId: id,
              action: 'delete',
              stamp: stamp,
              payloadJson: jsonEncode({
                'id': id,
                'deletedAt': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }

  @override
  Future<Map<String, Object?>> assistantContext() async {
    final dashboard = await db.dashboardSnapshot();
    final rows =
        await (db.select(db.financeTransactions)
              ..where((t) => t.deletedAt.isNull() & t.status.equals('posted'))
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
              ..limit(100))
            .get();
    final categories = await db.watchCategories().first;
    final categoryNames = {for (final item in categories) item.id: item.name};
    return {
      'summary': dashboard,
      'recentTransactions': rows
          .map(
            (row) => {
              'kind': row.kind,
              'amountMinor': row.amountMinor,
              'currency': row.currencyCode,
              'merchant': row.merchant,
              'note': row.note,
              'category': categoryNames[row.categoryId],
              'date': row.occurredAt.toIso8601String(),
            },
          )
          .toList(growable: false),
    };
  }
}
