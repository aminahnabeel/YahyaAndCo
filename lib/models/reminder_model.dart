class ReminderModel {
  final String reminderId;
  final int businessId;
  final String recordType;
  final int recordId;
  final int? accountId;
  final String? voucherNo;
  final String? paymentMethod;
  final String? voucherType;
  final String? accountName;
  final String? date;
  final int? transactionId;
  final int? journalId;
  final double amount;
  final double remainingAmount;
  final String? dueDate;
  final String paymentStatus;
  final String? description;
  final String sourceTable;
  final String? createdAt;
  final String updatedAt;

  const ReminderModel({
    required this.reminderId,
    required this.businessId,
    required this.recordType,
    required this.recordId,
    this.accountId,
    this.voucherNo,
    this.paymentMethod,
    this.voucherType,
    this.accountName,
    this.date,
    this.transactionId,
    this.journalId,
    required this.amount,
    required this.remainingAmount,
    this.dueDate,
    required this.paymentStatus,
    this.description,
    required this.sourceTable,
    this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'reminder_id': reminderId,
      'business_id': businessId,
      'record_type': recordType,
      'record_id': recordId,
      'account_id': accountId,
      'voucher_no': voucherNo,
      'payment_method': paymentMethod,
      'voucher_type': voucherType,
      'account_name': accountName,
      'date': date,
      'transaction_id': transactionId,
      'journal_id': journalId,
      'amount': amount,
      'remaining_amount': remainingAmount,
      'due_date': dueDate,
      'payment_status': paymentStatus,
      'description': description,
      'source_table': sourceTable,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      reminderId: map['reminder_id'] as String,
      businessId: (map['business_id'] as num).toInt(),
      recordType: map['record_type'] as String,
      recordId: (map['record_id'] as num).toInt(),
      accountId: (map['account_id'] as num?)?.toInt(),
      voucherNo: map['voucher_no'] as String?,
      paymentMethod: map['payment_method'] as String?,
      voucherType: map['voucher_type'] as String?,
      accountName: map['account_name'] as String?,
      date: map['date'] as String?,
      transactionId: (map['transaction_id'] as num?)?.toInt(),
      journalId: (map['journal_id'] as num?)?.toInt(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (map['remaining_amount'] as num?)?.toDouble() ?? 0,
      dueDate: map['due_date'] as String?,
      paymentStatus: map['payment_status'] as String? ?? 'Pending',
      description: map['description'] as String?,
      sourceTable: map['source_table'] as String,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'reminderId': reminderId,
      'businessId': businessId,
      'recordType': recordType,
      'recordId': recordId,
      'accountId': accountId,
      'voucherNo': voucherNo,
      'paymentMethod': paymentMethod,
      'voucherType': voucherType,
      'accountName': accountName,
      'date': date,
      'transactionId': transactionId,
      'journalId': journalId,
      'amount': amount,
      'remainingAmount': remainingAmount,
      'dueDate': dueDate,
      'paymentStatus': paymentStatus,
      'description': description,
      'sourceTable': sourceTable,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
