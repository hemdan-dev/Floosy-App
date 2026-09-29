import '../data/database/app_database.dart';

const uncategorizedExpenseColor = 0xFF9E9E9E;

class TransactionDayGroup {
  const TransactionDayGroup({required this.day, required this.transactions});

  final DateTime day;
  final List<FinanceTransaction> transactions;
}

class TransactionMonthGroup {
  const TransactionMonthGroup({
    required this.month,
    required this.transactions,
    required this.days,
  });

  final DateTime month;
  final List<FinanceTransaction> transactions;
  final List<TransactionDayGroup> days;
}

class ExpenseCategorySummary {
  const ExpenseCategorySummary({
    required this.categoryId,
    required this.name,
    required this.colorValue,
    required this.totalMinor,
    required this.transactionCount,
  });

  final String? categoryId;
  final String name;
  final int colorValue;
  final int totalMinor;
  final int transactionCount;
}

List<TransactionMonthGroup> groupTransactionsByMonthAndDay(
  Iterable<FinanceTransaction> transactions,
) {
  final sorted = transactions.toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  final months = <int, List<FinanceTransaction>>{};
  for (final transaction in sorted) {
    final local = transaction.occurredAt.toLocal();
    final key = local.year * 100 + local.month;
    months.putIfAbsent(key, () => []).add(transaction);
  }

  return months.entries
      .map((entry) {
        final year = entry.key ~/ 100;
        final monthNumber = entry.key % 100;
        final days = <int, List<FinanceTransaction>>{};
        for (final transaction in entry.value) {
          final local = transaction.occurredAt.toLocal();
          final dayKey = local.year * 10000 + local.month * 100 + local.day;
          days.putIfAbsent(dayKey, () => []).add(transaction);
        }
        return TransactionMonthGroup(
          month: DateTime(year, monthNumber),
          transactions: List.unmodifiable(entry.value),
          days: days.entries
              .map(
                (dayEntry) => TransactionDayGroup(
                  day: DateTime(
                    dayEntry.key ~/ 10000,
                    (dayEntry.key % 10000) ~/ 100,
                    dayEntry.key % 100,
                  ),
                  transactions: List.unmodifiable(dayEntry.value),
                ),
              )
              .toList(growable: false),
        );
      })
      .toList(growable: false);
}

bool transactionIsInMonth(FinanceTransaction transaction, DateTime month) {
  final local = transaction.occurredAt.toLocal();
  return local.year == month.year && local.month == month.month;
}

List<ExpenseCategorySummary> summarizeExpensesByCategory(
  Iterable<FinanceTransaction> transactions,
  Iterable<Category> categories, {
  required String uncategorizedName,
}) {
  final categoryById = {
    for (final category in categories) category.id: category,
  };
  final totals = <String?, int>{};
  final counts = <String?, int>{};
  for (final transaction in transactions) {
    if (transaction.kind != 'expense' || transaction.status != 'posted') {
      continue;
    }
    final categoryId = categoryById.containsKey(transaction.categoryId)
        ? transaction.categoryId
        : null;
    totals.update(
      categoryId,
      (value) => value + transaction.amountMinor,
      ifAbsent: () => transaction.amountMinor,
    );
    counts.update(categoryId, (value) => value + 1, ifAbsent: () => 1);
  }

  final summaries = totals.entries.map((entry) {
    final category = entry.key == null ? null : categoryById[entry.key];
    return ExpenseCategorySummary(
      categoryId: entry.key,
      name: category?.name ?? uncategorizedName,
      colorValue: category?.colorValue ?? uncategorizedExpenseColor,
      totalMinor: entry.value,
      transactionCount: counts[entry.key] ?? 0,
    );
  }).toList()..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
  return List.unmodifiable(summaries);
}

List<FinanceTransaction> transactionsForExpenseCategoryMonth(
  Iterable<FinanceTransaction> transactions,
  Iterable<Category> categories, {
  required DateTime month,
  required String? categoryId,
}) {
  final knownCategoryIds = categories.map((item) => item.id).toSet();
  return transactions.where((transaction) {
    if (transaction.kind != 'expense' || transaction.status != 'posted') {
      return false;
    }
    if (!transactionIsInMonth(transaction, month)) return false;
    if (categoryId != null) return transaction.categoryId == categoryId;
    return transaction.categoryId == null ||
        !knownCategoryIds.contains(transaction.categoryId);
  }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
}
