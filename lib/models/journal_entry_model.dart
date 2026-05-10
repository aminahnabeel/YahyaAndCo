class JournalEntryModel {

  int? journalId;

  int businessId;

  int transactionId;

  String description;

  String date;

  JournalEntryModel({

    this.journalId,

    required this.businessId,

    required this.transactionId,

    required this.description,

    required this.date,
  });

  Map<String, dynamic> toMap() {

    return {

      'journal_id': journalId,

      'business_id': businessId,

      'transaction_id':
          transactionId,

      'description':
          description,

      'date': date,
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

      description:
          map['description'],

      date:
          map['date'],
    );
  }
}