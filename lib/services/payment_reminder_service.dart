import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'accounting_service.dart';

class PaymentReminderService {
  PaymentReminderService._();

  static final PaymentReminderService instance = PaymentReminderService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> syncDueReminders(int businessId) async {
    await initialize();

    final accountingService = AccountingService();
    final dueToday = await accountingService.getDueToday(businessId);
    final overdue = await accountingService.getOverdueTransactions(businessId);
    final overdueJournals = await accountingService.getOverdueJournals(businessId);

    await _showGroupNotification(
      id: 1001,
      title: 'Due Today Reminders',
      body: '${dueToday.length} payment(s) are due today.',
    );

    await _showGroupNotification(
      id: 1002,
      title: 'Overdue Payment Reminders',
      body: '${overdue.length + overdueJournals.length} overdue payment(s) found.',
    );
  }

  Future<void> _showGroupNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'payment_reminders',
      'Payment Reminders',
      channelDescription: 'Due and overdue payment reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: android);
    await _plugin.show(id, title, body, details);
  }
}
