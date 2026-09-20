import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file/open_file.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'accounting_service.dart';

class AppNotificationManager {
  AppNotificationManager._();

  static final AppNotificationManager instance = AppNotificationManager._();
  static const _reminderSlotCount = 8;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: iOS);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    final filePath = response.payload;
    if (filePath != null && filePath.isNotEmpty) {
      OpenFile.open(filePath);
    }
  }

  Future<void> showDownloadNotification({
    required String filePath,
    required String fileName,
  }) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pdf_download_channel',
        'PDF Downloads',
        channelDescription: 'Notifications for PDF downloads',
        importance: Importance.max,
        priority: Priority.high,
        showProgress: false,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      filePath.hashCode,
      'PDF Downloaded Successfully',
      fileName,
      details,
      payload: filePath,
    );
  }

  Future<void> showSaveSuccessNotification({
    required String voucherNo,
    required double amount,
    required String accountName,
  }) async {
    await initialize();
    final body =
        'Voucher: $voucherNo\n'
        'Amount: Rs ${amount.toStringAsFixed(2)}\n'
        'Account: $accountName';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'save_success',
        'Saved Entries',
        channelDescription: 'Notifications for successfully saved entries',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: 'Entry Saved Successfully',
          summaryText: 'Saved successfully',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      _stableId('success:$voucherNo'),
      'Entry Saved Successfully',
      body,
      details,
    );
  }

  Future<void> syncDueReminders(int businessId) async {
    await initialize();
    final accountingService = AccountingService();
    final dueToday = await accountingService.getDueToday(businessId);
    final overdue = await accountingService.getOverdueTransactions(businessId);
    final overdueJournals = await accountingService.getOverdueJournals(businessId);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'payment_reminders',
        'Payment Reminders',
        channelDescription: 'Due and overdue payment reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      1001,
      'Due Today Reminders',
      '${dueToday.length} payment(s) are due today.',
      details,
    );
    await _plugin.show(
      1002,
      'Overdue Payment Reminders',
      '${overdue.length + overdueJournals.length} overdue payment(s) found.',
      details,
    );
  }

  Future<void> schedulePaymentReminders({
    required String recordType,
    required int recordId,
    required String voucherNo,
    required double amount,
    required String accountName,
    required String? dueDate,
    required String paymentStatus,
  }) async {
    await initialize();
    await cancelPaymentReminders(recordType: recordType, recordId: recordId);

    // --- DEBUG LOG ---
    print('🔔 [Reminder] schedulePaymentReminders called');
    print('   recordType=$recordType  recordId=$recordId  voucherNo=$voucherNo');
    print('   dueDate=$dueDate  paymentStatus=$paymentStatus');

    if (dueDate == null || dueDate.trim().isEmpty) {
      print('   ⏭ Skipped: dueDate is null/empty');
      return;
    }
    if (paymentStatus.toLowerCase() != 'pending') {
      print('   ⏭ Skipped: paymentStatus="$paymentStatus" (not pending)');
      return;
    }

    // -----------------------------------------------------------------
    // FIX 1 – Parse only the date portion so a full ISO string like
    // "2026-09-20T00:00:00.000" does NOT shift the date by UTC-offset.
    // -----------------------------------------------------------------
    final datePart = dueDate.trim().split('T').first; // → "2026-09-20"
    final parsed = DateTime.tryParse(datePart);
    if (parsed == null) {
      print('   ⏭ Skipped: cannot parse dueDate datePart="$datePart"');
      return;
    }
    final dueYear  = parsed.year;
    final dueMonth = parsed.month;
    final dueDay   = parsed.day;

    // -----------------------------------------------------------------
    // FIX 2 – Get the Karachi tz.Location directly (already initialised
    // in initialize()) so we can build TZDateTime without any conversion.
    // -----------------------------------------------------------------
    late final tz.Location karachi;
    try {
      karachi = tz.getLocation('Asia/Karachi');
    } catch (_) {
      print('   ❌ Could not get Asia/Karachi location – aborting scheduling');
      return;
    }

    print(
      '   📅 Due date: $dueYear-$dueMonth-$dueDay  tz=${karachi.name}',
    );

    // -----------------------------------------------------------------
    // FIX 3 – Build TZDateTime directly in Asia/Karachi timezone using
    // tz.TZDateTime(location, y, m, d, h) constructor.
    //
    // Do NOT use tz.TZDateTime.from(plainDartDateTime, karachi) — that
    // constructor converts the plain DateTime (which Dart treats as UTC
    // when created by DateTime.parse) to the target zone, adding a
    // +5-hour shift and producing the wrong wall-clock time.
    //
    // tz.TZDateTime(location, y, m, d, h) places the alarm at exactly
    // the stated wall-clock time in the given timezone — no conversion.
    //
    // Slot layout (8 slots, matches _reminderSlotCount = 8):
    //   0 → day-before 13:00 PKT
    //   1 → day-before 17:00 PKT
    //   2 → day-before 21:00 PKT
    //   3 → due day    00:00 PKT
    //   4 → due day    04:00 PKT
    //   5 → due day    08:00 PKT
    //   6 → due day    09:30 PKT
    //   7 → due day    12:00 PKT
    // -----------------------------------------------------------------
    final reminderTimes = <tz.TZDateTime>[
      tz.TZDateTime(karachi, dueYear, dueMonth, dueDay - 1, 13),
      
      tz.TZDateTime(karachi, dueYear, dueMonth, dueDay - 1, 16),
      
      tz.TZDateTime(karachi, dueYear, dueMonth, dueDay,      13),
      tz.TZDateTime(karachi, dueYear, dueMonth, dueDay,      16),
      
    ];

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final canScheduleExact =
        await androidPlugin?.canScheduleExactNotifications() ?? false;
    final scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    print(
      '   ⚙️  exactAlarm=$canScheduleExact  mode=${scheduleMode.name}',
    );

    final now = tz.TZDateTime.now(karachi);

    for (var index = 0; index < reminderTimes.length; index++) {
      final scheduled = reminderTimes[index];
      final notifId  = _reminderId(recordType, recordId, index);

      if (!scheduled.isAfter(now)) {
        print(
          '   ⏭ Slot $index skipped (past): ${scheduled.toIso8601String()}',
        );
        continue;
      }

      final body =
          'Account: $accountName\nVoucher: $voucherNo\nAmount: Rs ${amount.toStringAsFixed(2)}\nDue date: $dueDate';
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_payment_reminders',
          'Scheduled Payment Reminders',
          channelDescription: 'Notifications for pending payment due dates',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: 'Payment due',
            summaryText: 'Payment details',
          ),
          enableVibration: true,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      try {
        await _plugin.zonedSchedule(
          notifId,
          'Payment due',
          body,
          scheduled,
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        print(
          '   ✅ Slot $index scheduled: notifId=$notifId  at=${scheduled.toIso8601String()}',
        );
      } catch (e) {
        print('   ❌ Slot $index FAILED: notifId=$notifId  error=$e');
      }
    }
  }

  DateTime? _localDueDate(String dueDate) {
    final datePart = dueDate.trim().split('T').first;
    final parsed = DateTime.tryParse(datePart);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> cancelPaymentReminders({
    required String recordType,
    required int recordId,
  }) async {
    await initialize();
    for (var index = 0; index < _reminderSlotCount; index++) {
      await _plugin.cancel(_reminderId(recordType, recordId, index));
    }
  }

  Future<void> cancelAllNotifications() async {
    await initialize();
    await _plugin.cancelAll();
  }

  int _reminderId(String recordType, int recordId, int slot) =>
      _stableId('reminder:$recordType:$recordId:$slot');

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}