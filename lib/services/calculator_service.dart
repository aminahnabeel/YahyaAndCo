import '../db/database_helper.dart';
import '../models/calculator_history_model.dart';

class CalculatorService {

  // =========================
  // SAVE CALCULATION
  // =========================

  Future saveCalculation(
    CalculatorHistoryModel history,
  ) async {

    await DatabaseHelper
        .instance
        .insertCalculatorHistory(
      history,
    );
  }

  // =========================
  // GET HISTORY
  // =========================

  Future<List<CalculatorHistoryModel>>
      getHistory() async {

    return await DatabaseHelper
        .instance
        .getCalculatorHistory();
  }

  // =========================
  // CLEAR HISTORY
  // =========================

  Future clearHistory() async {

    await DatabaseHelper
        .instance
        .clearCalculatorHistory();
  }
}