import '../db/database_helper.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';

class JournalService {

  // =========================
  // CREATE JOURNAL ENTRY
  // =========================

  Future<int> createJournalEntry(
    JournalEntryModel journal,
  ) async {

    return await DatabaseHelper
        .instance
        .insertJournalEntry(
      journal,
    );
  }

  // =========================
  // CREATE JOURNAL LINE
  // =========================

  Future<int> createJournalLine(
    JournalLineModel line,
  ) async {

    return await DatabaseHelper
        .instance
        .insertJournalLine(
      line,
    );
  }

  // =========================
  // GET JOURNAL ENTRIES
  // =========================

  Future<List<JournalEntryModel>>
      getJournalEntries(
    int businessId,
  ) async {

    return await DatabaseHelper
        .instance
        .getJournalEntries(
      businessId,
    );
  }

  // =========================
  // GET JOURNAL LINES
  // =========================

  Future<List<JournalLineModel>>
      getJournalLines(
    int journalId,
  ) async {

    return await DatabaseHelper
        .instance
        .getJournalLines(
      journalId,
    );
  }
}