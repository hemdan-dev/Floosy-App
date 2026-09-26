import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floosy/data/database/app_database.dart';
import 'package:floosy/services/google_drive_sync_service.dart';

void main() {
  test('first baseline import replaces seeds and is recorded once', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const accountId = 'legacy-account';
    const categoryId = 'legacy-category';
    const stamp = '0-0-migration';
    final now = DateTime.utc(2025).toIso8601String();
    await LegacyBaselineImporter(database).import({
      'sourceFingerprint': 'fingerprint',
      'accounts': [
        {
          'id': accountId,
          'name': 'Cash',
          'type': 'cash',
          'currencyCode': 'EGP',
          'initialBalanceMinor': 10000,
          'includeInNetWorth': true,
          'createdAt': now,
          'updatedAt': now,
          'syncStamp': stamp,
        },
      ],
      'categories': [
        {
          'id': categoryId,
          'legacyId': categoryId,
          'name': 'Legacy food',
          'kind': 'both',
          'createdAt': now,
          'updatedAt': now,
          'syncStamp': stamp,
        },
      ],
      'transactions': [
        {
          'id': 'legacy-record',
          'legacyId': 'legacy-record',
          'kind': 'expense',
          'amountMinor': 2500,
          'currencyCode': 'EGP',
          'accountId': accountId,
          'categoryId': categoryId,
          'tags': <String>[],
          'source': 'legacy',
          'status': 'posted',
          'occurredAt': now,
          'createdAt': now,
          'updatedAt': now,
          'syncStamp': stamp,
        },
      ],
      'report': {'records': 1},
    });

    final accounts = await database.watchAccounts().first;
    final categories = await database.watchCategories().first;
    expect(accounts.map((item) => item.id), [accountId]);
    expect(categories.map((item) => item.id), [categoryId]);
    expect(await database.balanceForAccount(accountId), 7500);
    expect(await database.select(database.migrationRuns).get(), hasLength(1));
  });
}
