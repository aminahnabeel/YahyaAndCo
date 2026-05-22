class JournalEntryModel {

  int? journalId;

  int businessId;

  int? transactionId;

  String voucherNo;

  String voucherType;

  String description;

    String? dueDate;

    String paymentStatus;

    double remainingAmount;

  String? imageUrl;

  String date;

  String createdAt;

  JournalEntryModel({

    this.journalId,

    required this.businessId,

    this.transactionId,

    required this.voucherNo,

    required this.voucherType,

    required this.description,

    this.dueDate,

    this.paymentStatus = 'Paid',

    this.remainingAmount = 0,

    this.imageUrl,

    required this.date,

    required this.createdAt,
  });

  Map<String, dynamic> toMap() {

    return {

      'journal_id': journalId,

      'business_id':
          businessId,

      'transaction_id':
          transactionId,

      'voucher_no':
          voucherNo,

      'voucher_type':
          voucherType,

      'description':
          description,

      'due_date': dueDate,

      'payment_status': paymentStatus,

      'remaining_amount': remainingAmount,

      'image_url':
          imageUrl,

      'date':
          date,

      'created_at':
          createdAt,
    };
  }

  factory JournalEntryModel.fromMap(
    Map<String, dynamic> map,
  ) {

    return JournalEntryModel(

      journalId:
          map['journal_id'],

      businessId:
          map['business_id'],

      transactionId:
          map['transaction_id'],

      voucherNo:
          map['voucher_no'],

      voucherType:
          map['voucher_type'],

      description:
          map['description'],

      dueDate:
          map['due_date'],

      paymentStatus:
          map['payment_status'] ?? 'Paid',

      remainingAmount:
          (map['remaining_amount'] as num?)?.toDouble() ?? 0,

      imageUrl:
          map['image_url'],

      date:
          map['date'],

      createdAt:
          map['created_at'],
    );
  }
}