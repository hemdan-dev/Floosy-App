import 'package:flutter_test/flutter_test.dart';

import 'package:floosy/data/database/app_database.dart';
import 'package:floosy/ui/transaction_history_models.dart';

void main() {
  test('groups transactions by descending local month and day', () {
    final rows = [
      _transaction('jan-old', DateTime(2026, 1, 2, 8)),
      _transaction('feb', DateTime(2026, 2, 1, 9)),
      _transaction('jan-new', DateTime(2026, 1, 2, 12)),
      _transaction('jan-day', DateTime(2026, 1, 3, 7)),
    ];

    final months = groupTransactionsByMonthAndDay(rows);

    expect(months.map((group) => group.month.month), [2, 1]);
    expect(months[1].days.map((group) => group.day.day), [3, 2]);
    expect(months[1].days[1].transactions.map((row) => row.id), [
      'jan-new',
      'jan-old',
    ]);
  });

  test('category summaries only include posted expenses', () {
    final food = _category('food', 'Food', 0xFFFF0000);
    final rows = [
      _transaction(
        'food-expense',
        DateTime(2026, 3, 1),
        amountMinor: 1000,
        categoryId: 'food',
      ),
      _transaction(
        'unknown-expense',
        DateTime(2026, 3, 2),
        amountMinor: 500,
        categoryId: 'deleted-category',
      ),
      _transaction(
        'adjustment',
        DateTime(2026, 3, 3),
        kind: 'adjustment',
        amountMinor: 9000,
      ),
      _transaction(
        'income',
        DateTime(2026, 3, 4),
        kind: 'income',
        amountMinor: 2000,
      ),
      _transaction(
        'pending-expense',
        DateTime(2026, 3, 5),
        amountMinor: 300,
        status: 'pending',
      ),
    ];

    final summaries = summarizeExpensesByCategory(rows, [
      food,
    ], uncategorizedName: 'Uncategorized');

    expect(summaries, hasLength(2));
    expect(summaries[0].name, 'Food');
    expect(summaries[0].totalMinor, 1000);
    expect(summaries[1].categoryId, isNull);
    expect(summaries[1].name, 'Uncategorized');
    expect(summaries[1].totalMinor, 500);

    final uncategorized = transactionsForExpenseCategoryMonth(
      rows,
      [food],
      month: DateTime(2026, 3),
      categoryId: null,
    );
    expect(uncategorized.map((row) => row.id), ['unknown-expense']);
  });
}

FinanceTransaction _transaction(
  String id,
  DateTime occurredAt, {
  String kind = 'expense',
  int amountMinor = 100,
  String? categoryId,
  String status = 'posted',
}) {
  final timestamp = occurredAt.toUtc();
  return FinanceTransaction(
    id: id,
    kind: kind,
    amountMinor: amountMinor,
    currencyCode: 'EGP',
    accountId: 'account-cash',
    categoryId: categoryId,
    tagsJson: '[]',
    source: 'manual',
    status: status,
    exchangeRateToBase: 1,
    occurredAt: timestamp,
    createdAt: timestamp,
    updatedAt: timestamp,
    syncStamp: '0-0-test',
  );
}

Category _category(String id, String name, int colorValue) {
  final timestamp = DateTime.utc(2026);
  return Category(
    id: id,
    name: name,
    kind: 'expense',
    colorValue: colorValue,
    iconName: 'category',
    isSystem: false,
    createdAt: timestamp,
    updatedAt: timestamp,
    syncStamp: '0-0-test',
  );
}
