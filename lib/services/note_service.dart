import '../db/database_helper.dart';
import '../models/note_model.dart';

class NoteService {

  // =========================
  // CREATE NOTE
  // =========================

  Future<int> createNote(
    NoteModel note,
  ) async {

    return await DatabaseHelper
        .instance
        .insertNote(
      note,
    );
  }

  // =========================
  // GET NOTES
  // =========================

  Future<List<NoteModel>>
      getNotes(
    int businessId,
  ) async {

    return await DatabaseHelper
        .instance
        .getNotes(
      businessId,
    );
  }
}