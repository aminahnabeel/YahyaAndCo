class JournalLineModel {

  int? lineId;

  int journalId;

  int accountId;

  double debit;

  double credit;

  JournalLineModel({

    this.lineId,

    required this.journalId,

    required this.accountId,

    required this.debit,

    required this.credit,
  });

  Map<String, dynamic> toMap() {

    return {

      'line_id': lineId,

      'journal_id': journalId,

      'account_id': accountId,

      'debit': debit,

      'credit': credit,
    };
  }

  factory JournalLineModel.fromMap(
    Map<String, dynamic> map,
  ) {

    return JournalLineModel(

      lineId:
          map['line_id'],

      journalId:
          map['journal_id'],

      accountId:
          map['account_id'],

      debit:
          map['debit'],

      credit:
          map['credit'],
    );
  }
}