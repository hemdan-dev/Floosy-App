import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../core/money.dart';
import '../data/database/app_database.dart';

class WidgetService {
  WidgetService(this.db);

  final AppDatabase db;

  Future<void> refresh() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId('group.net.floosy.app');
    }
    final summary = await db.dashboardSnapshot();
    final currency = summary['currency']! as String;
    await HomeWidget.saveWidgetData(
      'balance',
      Money(summary['balanceMinor']! as int, currency).format(),
    );
    await HomeWidget.saveWidgetData(
      'spent',
      Money(summary['expenseMinor']! as int, currency).format(),
    );
    await HomeWidget.saveWidgetData(
      'income',
      Money(summary['incomeMinor']! as int, currency).format(),
    );
    await HomeWidget.updateWidget(
      androidName: 'FloosyWidgetProvider',
      iOSName: 'FloosyWidget',
    );
  }
}
