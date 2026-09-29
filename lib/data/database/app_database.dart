import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

const _uuid = Uuid();

class SyncColumns {
  static const initialStamp = '0-0-seed';
}

@DataClassName('Account')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('cash'))();
  TextColumn get currencyCode => text().withDefault(const Constant('EGP'))();
  IntColumn get initialBalanceMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get creditLimitMinor => integer().nullable()();
  BoolColumn get includeInNetWorth =>
      boolean().withDefault(const Constant(true))();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF177A5B))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStamp =>
      text().withDefault(const Constant(SyncColumns.initialStamp))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Card')
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get name => text()();
  TextColumn get lastFour => text().nullable()();
  TextColumn get senderAliasesJson =>
      text().withDefault(const Constant('[]'))();
  IntColumn get statementDay => integer().nullable()();
  IntColumn get dueDay => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStamp =>
      text().withDefault(const Constant(SyncColumns.initialStamp))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Category')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text().withDefault(const Constant('expense'))();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF607D8B))();
  TextColumn get iconName => text().withDefault(const Constant('category'))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get legacyId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStamp =>
      text().withDefault(const Constant(SyncColumns.initialStamp))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FinanceTransaction')
class FinanceTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('EGP'))();
  TextColumn get accountId => text()();
  TextColumn get destinationAccountId => text().nullable()();
  TextColumn get transferGroupId => text().nullable()();
  TextColumn get cardId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get sourceFingerprint => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('posted'))();
  RealColumn get exchangeRateToBase => real().withDefault(const Constant(1))();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get legacyId => text().nullable()();
  TextColumn get legacyTransferId => text().nullable()();
  TextColumn get syncStamp =>
      text().withDefault(const Constant(SyncColumns.initialStamp))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceFingerprint},
  ];
}

@DataClassName('MerchantRule')
class MerchantRules extends Table {
  TextColumn get id => text()();
  TextColumn get pattern => text()();
  TextColumn get categoryId => text()();
  TextColumn get accountId => text().nullable()();
  BoolColumn get isRegex => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStamp =>
      text().withDefault(const Constant(SyncColumns.initialStamp))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Budget')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get limitMinor => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('EGP'))();
  TextColumn get cycle => text().withDefault(const Constant('monthly'))();
  IntColumn get cycleStartDay => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStamp =>
      text().withDefault(const Constant(SyncColumns.initialStamp))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('InstallmentPlan')
class InstallmentPlans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get accountId => text()();
  TextColumn get cardId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get totalMinor => integer()();
  IntColumn get paymentMinor => integer()();
  IntColumn get installmentCount => integer()();
  IntColumn get paidCount => integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('EGP'))();
  DateTimeColumn get nextDueAt => dateTime()();
  IntColumn get reminderDays => integer().withDefault(const Constant(3))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStamp =>
      text().withDefault(const Constant(SyncColumns.initialStamp))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Asset')
class Assets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant('unit'))();
  IntColumn get manualValueMinor => integer().nullable()();
  TextColumn get currencyCode => text().withDefault(const Constant('EGP'))();
  TextColumn get symbol => text().nullable()();
  IntColumn get goldKarat => integer().nullable()();
  BoolColumn get useMarketPrice =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStamp =>
      text().withDefault(const Constant(SyncColumns.initialStamp))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MarketQuote')
class MarketQuotes extends Table {
  TextColumn get id => text()();
  TextColumn get symbol => text()();
  TextColumn get baseCurrency => text()();
  TextColumn get quoteCurrency => text()();
  RealColumn get rate => real()();
  TextColumn get source => text()();
  DateTimeColumn get fetchedAt => dateTime()();
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PendingCapture')
class PendingCaptures extends Table {
  TextColumn get id => text()();
  TextColumn get source => text()();
  TextColumn get payload => text()();
  TextColumn get attachmentPath => text().nullable()();
  TextColumn get sender => text().nullable()();
  TextColumn get fingerprint => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  TextColumn get error => text().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AiMessage')
class AiMessages extends Table {
  TextColumn get id => text()();
  TextColumn get threadId => text()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStamp =>
      text().withDefault(const Constant(SyncColumns.initialStamp))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncOperation')
class SyncOperations extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get stamp => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get uploadedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AppliedOperation')
class AppliedOperations extends Table {
  TextColumn get id => text()();
  DateTimeColumn get appliedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncConflict')
class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get winningStamp => text()();
  TextColumn get losingPayloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('MigrationRun')
class MigrationRuns extends Table {
  TextColumn get id => text()();
  TextColumn get sourceFingerprint => text()();
  IntColumn get importedCount => integer()();
  TextColumn get reportJson => text()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Accounts,
    Cards,
    Categories,
    FinanceTransactions,
    MerchantRules,
    Budgets,
    InstallmentPlans,
    Assets,
    MarketQuotes,
    PendingCaptures,
    AiMessages,
    SyncOperations,
    AppliedOperations,
    SyncConflicts,
    AppSettings,
    MigrationRuns,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'floosy'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaults();
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedDefaults() async {
    final now = DateTime.now().toUtc();
    await into(accounts).insert(
      AccountsCompanion.insert(
        id: 'account-cash',
        name: 'Cash',
        currencyCode: const Value('EGP'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    const seeds = <(String, String, int)>[
      ('category-food', 'Food & Drinks', 0xFFFF7043),
      ('category-transport', 'Transportation', 0xFF78909C),
      ('category-bills', 'Bills & Utilities', 0xFFFFA726),
      ('category-shopping', 'Shopping', 0xFF42A5F5),
      ('category-health', 'Health', 0xFF66BB6A),
      ('category-other', 'Other', 0xFF9E9E9E),
      ('category-income', 'Income', 0xFFFFC107),
    ];
    for (final seed in seeds) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          id: seed.$1,
          name: seed.$2,
          kind: Value(seed.$1 == 'category-income' ? 'income' : 'expense'),
          colorValue: Value(seed.$3),
          isSystem: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await into(
      appSettings,
    ).insert(AppSettingsCompanion.insert(key: 'baseCurrency', value: 'EGP'));
    await into(
      appSettings,
    ).insert(AppSettingsCompanion.insert(key: 'locale', value: 'en'));
  }

  Stream<List<FinanceTransaction>> watchTransactions() {
    final query = select(financeTransactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return query.watch();
  }

  Stream<List<Account>> watchAccounts() {
    return (select(accounts)..where((t) => t.deletedAt.isNull())).watch();
  }

  Stream<List<Category>> watchCategories() {
    return (select(categories)..where((t) => t.deletedAt.isNull())).watch();
  }

  Stream<List<Budget>> watchBudgets() {
    return (select(budgets)..where((t) => t.deletedAt.isNull())).watch();
  }

  Stream<List<InstallmentPlan>> watchInstallments() {
    return (select(
      installmentPlans,
    )..where((t) => t.deletedAt.isNull())).watch();
  }

  Stream<List<Asset>> watchAssets() {
    return (select(assets)..where((t) => t.deletedAt.isNull())).watch();
  }

  Stream<List<PendingCapture>> watchPendingCaptures() {
    return (select(pendingCaptures)
          ..where((t) => t.state.isNotIn(const ['completed', 'dismissed']))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<int> totalForKind(
    String kind, {
    required DateTime from,
    required DateTime to,
  }) async {
    final amount = financeTransactions.amountMinor.sum();
    final query = selectOnly(financeTransactions)
      ..addColumns([amount])
      ..where(
        financeTransactions.kind.equals(kind) &
            financeTransactions.status.equals('posted') &
            financeTransactions.deletedAt.isNull() &
            financeTransactions.occurredAt.isBiggerOrEqualValue(from) &
            financeTransactions.occurredAt.isSmallerThanValue(to),
      );
    return (await query.getSingle()).read(amount) ?? 0;
  }

  Future<int> balanceForAccount(String accountId) async {
    final account = await (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).getSingle();
    final rows = await (select(
      financeTransactions,
    )..where((t) => t.deletedAt.isNull() & t.status.equals('posted'))).get();
    var balance = account.initialBalanceMinor;
    for (final row in rows) {
      if (row.kind == 'income' && row.accountId == accountId) {
        balance += row.amountMinor;
      } else if (row.kind == 'expense' && row.accountId == accountId) {
        balance -= row.amountMinor;
      } else if (row.kind == 'transfer') {
        if (row.accountId == accountId) balance -= row.amountMinor;
        if (row.destinationAccountId == accountId) balance += row.amountMinor;
      } else if (row.kind == 'adjustment' && row.accountId == accountId) {
        balance += row.amountMinor;
      }
    }
    return balance;
  }

  Future<void> createTransaction(FinanceTransactionsCompanion companion) async {
    await into(financeTransactions).insert(companion);
  }

  Future<String> queueCapture({
    required String source,
    required String payload,
    String? attachmentPath,
    String? sender,
    String? fingerprint,
  }) async {
    final id = _uuid.v7();
    final now = DateTime.now().toUtc();
    await into(pendingCaptures).insert(
      PendingCapturesCompanion.insert(
        id: id,
        source: source,
        payload: payload,
        attachmentPath: Value(attachmentPath),
        sender: Value(sender),
        fingerprint: Value(fingerprint),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<String?> getSetting(String key) async {
    final row = await (select(
      appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<Map<String, Object?>> dashboardSnapshot() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final next = DateTime(now.year, now.month + 1);
    final expense = await totalForKind('expense', from: start, to: next);
    final income = await totalForKind('income', from: start, to: next);
    final accountRows = await (select(
      accounts,
    )..where((a) => a.deletedAt.isNull())).get();
    var balance = 0;
    for (final account in accountRows) {
      if (account.includeInNetWorth) {
        balance += await balanceForAccount(account.id);
      }
    }
    return {
      'expenseMinor': expense,
      'incomeMinor': income,
      'balanceMinor': balance,
      'currency': await getSetting('baseCurrency') ?? 'EGP',
    };
  }

  Future<List<Map<String, Object?>>> transactionExportRows() async {
    final rows =
        await (select(financeTransactions)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
            .get();
    return rows
        .map(
          (row) => {
            'id': row.id,
            'kind': row.kind,
            'amountMinor': row.amountMinor,
            'currencyCode': row.currencyCode,
            'accountId': row.accountId,
            'destinationAccountId': row.destinationAccountId,
            'categoryId': row.categoryId,
            'merchant': row.merchant,
            'note': row.note,
            'tags': jsonDecode(row.tagsJson),
            'source': row.source,
            'status': row.status,
            'occurredAt': row.occurredAt.toUtc().toIso8601String(),
            'createdAt': row.createdAt.toUtc().toIso8601String(),
            'updatedAt': row.updatedAt.toUtc().toIso8601String(),
            'deletedAt': row.deletedAt?.toUtc().toIso8601String(),
            'syncStamp': row.syncStamp,
          },
        )
        .toList(growable: false);
  }
}
