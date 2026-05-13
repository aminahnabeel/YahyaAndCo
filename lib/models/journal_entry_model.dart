class JournalEntryModel {

  int? journalId;

  int businessId;

  int? transactionId;

  String voucherNo;

  String voucherType;

  String description;

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

      imageUrl:
          map['image_url'],

      date:
          map['date'],

      createdAt:
          map['created_at'],
    );
  }
}