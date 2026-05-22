class TransactionModel {

  int? transactionId;

  int businessId;

  int accountId;

  double amount;

  String type;

  String note;

  String paymentMethod;

    String? dueDate;

    String paymentStatus;

    double remainingAmount;

  String? imageUrl;

  String date;

  String createdAt;

  TransactionModel({

    this.transactionId,

    required this.businessId,

    required this.accountId,

    required this.amount,

    required this.type,

    required this.note,

    required this.paymentMethod,

    this.dueDate,

    this.paymentStatus = 'Paid',

    this.remainingAmount = 0,

    this.imageUrl,

    required this.date,

    required this.createdAt,
  });

  Map<String, dynamic> toMap() {

    return {

      'transaction_id':
          transactionId,

      'business_id':
          businessId,

      'account_id':
          accountId,

      'amount':
          amount,

      'type':
          type,

      'note':
          note,

      'payment_method':
          paymentMethod,

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

  factory TransactionModel.fromMap(
    Map<String, dynamic> map,
  ) {

    return TransactionModel(

      transactionId:
          map['transaction_id'],

      businessId:
          map['business_id'],

      accountId:
          map['account_id'],

      amount:
          map['amount'],

      type:
          map['type'],

      note:
          map['note'],

      paymentMethod:
          map['payment_method'],

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