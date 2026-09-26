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
}
