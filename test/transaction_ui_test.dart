import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floosy/app_providers.dart';
import 'package:floosy/core/app_localizations.dart';
import 'package:floosy/core/app_theme.dart';
import 'package:floosy/data/database/app_database.dart';
import 'package:floosy/data/repositories/finance_repository.dart';
import 'package:floosy/ui/home_shell.dart';

void main() {
  testWidgets('monthly donut opens category details and transaction editor', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftFinanceRepository(database);
    final id = await repository.createTransaction(
      CreateTransactionInput(
        kind: 'expense',
        amountMinor: 2500,
        currencyCode: 'EGP',
        accountId: 'account-cash',
        categoryId: 'category-food',
        merchant: 'Cafe',
        occurredAt: DateTime(2026, 3, 12, 18, 30),
      ),
    );

    await tester.pumpWidget(
      _testApp(database: database, home: const TransactionsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('March 2026'), findsOneWidget);
    expect(find.text('Expenses by category'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Food & Drinks'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Food & Drinks'));
    await tester.pumpAndSettle();

    expect(find.text('Food & Drinks'), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget);
    await tester.tap(find.text('Cafe'));
    await tester.pumpAndSettle();

    expect(find.text('Edit transaction'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '30.00');
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save changes'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    final updated = await (database.select(
      database.financeTransactions,
    )..where((row) => row.id.equals(id))).getSingle();
    expect(updated.amountMinor, 3000);

    await repository.updateTransaction(
      id,
      UpdateTransactionInput(
        kind: 'expense',
        amountMinor: updated.amountMinor,
        currencyCode: updated.currencyCode,
        accountId: updated.accountId,
        categoryId: 'category-shopping',
        merchant: updated.merchant,
        note: updated.note,
        occurredAt: updated.occurredAt,
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('Cafe'), findsNothing);
    expect(
      find.text('There are no transactions in this category for this month.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('dashboard total creates a visible balance adjustment', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      _testApp(
        database: database,
        home: OverviewScreen(onSelectTab: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('Edit total balance'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '123.45');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final adjustments = await (database.select(
      database.financeTransactions,
    )..where((row) => row.kind.equals('adjustment'))).get();
    expect(adjustments, hasLength(1));
    expect(adjustments.single.amountMinor, 12345);
    expect(find.text('Balance adjustment'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Widget _testApp({required AppDatabase database, required Widget home}) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(database)],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: Scaffold(body: home),
    ),
  );
}
