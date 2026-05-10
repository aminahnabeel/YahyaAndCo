class CalculatorHistoryModel {

  int? historyId;

  String expression;

  String result;

  String createdAt;

  CalculatorHistoryModel({

    this.historyId,

    required this.expression,

    required this.result,

    required this.createdAt,
  });

  Map<String, dynamic> toMap() {

    return {

      'history_id': historyId,

      'expression': expression,

      'result': result,

      'created_at': createdAt,
    };
  }

  factory CalculatorHistoryModel.fromMap(
    Map<String, dynamic> map,
  ) {

    return CalculatorHistoryModel(

      historyId:
          map['history_id'],

      expression:
          map['expression'],

      result:
          map['result'],

      createdAt:
          map['created_at'],
    );
  }
}