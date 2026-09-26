import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/money.dart';
import '../data/database/app_database.dart';

class NotificationService {
  NotificationService(this.db);

  final AppDatabase db;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> rescheduleInstallments() async {
    final plans = await db.watchInstallments().first;
    if (plans.isEmpty) return;
    await initialize();
    for (final plan in plans) {
      await scheduleInstallment(plan);
    }
  }

  Future<void> scheduleInstallment(InstallmentPlan plan) async {
    await initialize();
    final reminder = plan.nextDueAt.toLocal().subtract(
      Duration(days: plan.reminderDays),
    );
    if (reminder.isBefore(DateTime.now())) return;
    await _notifications.zonedSchedule(
      plan.id.hashCode & 0x7FFFFFFF,
      'Installment due soon',
      '${plan.name}: ${Money(plan.paymentMinor, plan.currencyCode).format()}',
      tz.TZDateTime.from(reminder, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'installments',
          'Installment reminders',
          channelDescription: 'Upcoming installment payment reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'installment:${plan.id}',
    );
  }
}
