import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../models/reminder_model.dart';
import 'firestore_service.dart';

class ReminderService {
  final DatabaseHelper _database = DatabaseHelper.instance;
  final FirestoreService _firestoreService = FirestoreService();

  Future<List<Map<String, dynamic>>> loadReminders(int businessId) async {
    await refreshReminders(businessId);
    final reminders = await _database.getRemindersByBusiness(businessId);
    return reminders.map(_toScreenMap).toList();
  }

  Future<void> refreshReminders(int businessId) async {
    final sourceRows = _deduplicateSourceRows(
      await _database.getReminderSourceRows(businessId),
    );
    final existing = await _database.getRemindersByBusiness(businessId);
    final activeIds = <String>{};

    for (final row in sourceRows) {
      final reminder = _fromSourceRow(row, businessId);
      activeIds.add(reminder.reminderId);
      await _database.upsertReminder(reminder);
    }

    for (final reminder in existing) {
      if (!activeIds.contains(reminder.reminderId)) {
        await _database.deleteReminder(reminder.reminderId, businessId);
      }
    }

    final business = await _getBusiness(businessId);
    final firestoreBusinessId = business?.firestoreId;
    if (firestoreBusinessId == null) return;

    for (final row in sourceRows) {
      final reminder = _fromSourceRow(row, businessId);
      try {
        await _firestoreService.upsertReminder(
          businessId: firestoreBusinessId,
          reminder: reminder,
        );
      } catch (_) {
        // SQLite remains the source for offline and failed-sync reads.
      }
    }

    for (final reminder in existing) {
      if (!activeIds.contains(reminder.reminderId)) {
        try {
          await _firestoreService.deleteReminder(
            businessId: firestoreBusinessId,
            reminderId: reminder.reminderId,
          );
        } catch (_) {
          // A failed cleanup must not break the local reminder screen.
        }
      }
    }
  }

  List<Map<String, dynamic>> _deduplicateSourceRows(
    List<Map<String, dynamic>> rows,
  ) {
    final uniqueRows = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final recordType = (row['record_type'] ?? '').toString().toLowerCase();
      final recordId = row['record_id']?.toString() ?? '';
      final voucherNo = (row['voucher_no'] ?? '').toString().trim();
      final key = recordId.isNotEmpty
          ? '$recordType:$recordId'
          : '$recordType:$voucherNo';
      uniqueRows.putIfAbsent(key, () => row);
    }
    return uniqueRows.values.toList();
  }

  Future<void> markAsPaid({
    required String sourceTable,
    required int recordId,
  }) async {
    final db = await _database.database;
    final table = sourceTable == 'transactions'
        ? 'transactions'
        : 'journal_entry';
    final idColumn = table == 'transactions' ? 'transaction_id' : 'journal_id';
    final rows = await db.query(
      table,
      columns: ['business_id', 'transaction_id'],
      where: '$idColumn = ?',
      whereArgs: [recordId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final businessId = (rows.first['business_id'] as num).toInt();
    await db.update(
      table,
      {'payment_status': 'Paid', 'remaining_amount': 0},
      where: '$idColumn = ?',
      whereArgs: [recordId],
    );

    if (table == 'transactions') {
      await db.update(
        'journal_entry',
        {'payment_status': 'Paid', 'remaining_amount': 0},
        where: 'transaction_id = ?',
        whereArgs: [recordId],
      );
    } else {
      final transactionId = (rows.first['transaction_id'] as num?)?.toInt();
      if (transactionId != null) {
        await db.update(
          'transactions',
          {'payment_status': 'Paid', 'remaining_amount': 0},
          where: 'transaction_id = ?',
          whereArgs: [transactionId],
        );
      }
    }

    final business = await _getBusiness(businessId);
    final firestoreBusinessId = business?.firestoreId;
    if (firestoreBusinessId != null && _firestoreService.isUserLoggedIn()) {
      if (table == 'transactions') {
        final firestoreTransactionId = await _database
            .getTransactionFirestoreId(recordId);
        if (firestoreTransactionId != null) {
          await _firestoreService.updateTransactionPaymentStatus(
            businessId: firestoreBusinessId,
            transactionId: firestoreTransactionId,
            paymentStatus: 'Paid',
            remainingAmount: 0,
          );
        }

        final linkedJournal = await _database.getJournalEntryByTransactionId(
          recordId,
        );
        if (linkedJournal?.journalId != null) {
          final firestoreJournalId = await _database.getJournalFirestoreId(
            linkedJournal!.journalId!,
          );
          if (firestoreJournalId != null) {
            await _firestoreService.updateJournalPaymentStatus(
              businessId: firestoreBusinessId,
              journalId: firestoreJournalId,
              paymentStatus: 'Paid',
              remainingAmount: 0,
            );
          }
        }
      } else {
        final firestoreJournalId = await _database.getJournalFirestoreId(
          recordId,
        );
        if (firestoreJournalId != null) {
          await _firestoreService.updateJournalPaymentStatus(
            businessId: firestoreBusinessId,
            journalId: firestoreJournalId,
            paymentStatus: 'Paid',
            remainingAmount: 0,
          );
        }

        final transactionId = (rows.first['transaction_id'] as num?)?.toInt();
        if (transactionId != null) {
          final firestoreTransactionId = await _database
              .getTransactionFirestoreId(transactionId);
          if (firestoreTransactionId != null) {
            await _firestoreService.updateTransactionPaymentStatus(
              businessId: firestoreBusinessId,
              transactionId: firestoreTransactionId,
              paymentStatus: 'Paid',
              remainingAmount: 0,
            );
          }
        }
      }
    }

    await refreshReminders(businessId);
  }

  ReminderModel _fromSourceRow(Map<String, dynamic> row, int businessId) {
    final recordType = row['record_type'].toString();
    final recordId = (row['record_id'] as num).toInt();
    final remaining = (row['remaining_amount'] as num?)?.toDouble() ?? 0;
    final dueDate = row['due_date']?.toString();
    final status = remaining <= 0
        ? 'Paid'
        : _isOverdue(dueDate)
        ? 'Overdue'
        : 'Pending';
    final updatedAt = DateTime.now().toIso8601String();

    return ReminderModel(
      reminderId: '$businessId-${recordType.toLowerCase()}-$recordId',
      businessId: businessId,
      recordType: recordType,
      recordId: recordId,
      accountId: (row['account_id'] as num?)?.toInt(),
      voucherNo: row['voucher_no']?.toString(),
      paymentMethod: row['payment_method']?.toString(),
      voucherType: row['voucher_type']?.toString(),
      accountName: row['account_name']?.toString(),
      date: row['date']?.toString(),
      transactionId: (row['transaction_id'] as num?)?.toInt(),
      journalId: (row['journal_id'] as num?)?.toInt(),
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: remaining,
      dueDate: dueDate,
      paymentStatus: status,
      description: row['description']?.toString(),
      sourceTable: row['source_table'].toString(),
      createdAt: row['created_at']?.toString(),
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> _toScreenMap(ReminderModel reminder) {
    return {
      'record_type': reminder.recordType,
      'record_id': reminder.recordId,
      'transaction_id': reminder.transactionId,
      'journal_id': reminder.journalId,
      'account_id': reminder.accountId,
      'voucher_no': reminder.voucherNo,
      'amount': reminder.amount,
      'remaining_amount': reminder.remainingAmount,
      'due_date': reminder.dueDate,
      'payment_status': reminder.paymentStatus,
      'payment_method': reminder.paymentMethod,
      'voucher_type': reminder.voucherType,
      'description': reminder.description,
      'account_name': reminder.accountName,
      'date': reminder.date,
      'created_at': reminder.createdAt,
      'source_table': reminder.sourceTable,
    };
  }

  bool _isOverdue(String? dueDate) {
    final parsed = dueDate == null ? null : DateTime.tryParse(dueDate);
    if (parsed == null) return false;
    final today = DateTime.now();
    return parsed.isBefore(DateTime(today.year, today.month, today.day));
  }

  Future<BusinessModel?> _getBusiness(int businessId) async {
    final businesses = await _database.getBusinesses();
    for (final business in businesses) {
      if (business.businessId == businessId) return business;
    }
    return null;
  }
}
