import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../models/note_model.dart';
import 'firestore_service.dart';
import 'sync_service.dart';

class NoteService {
  final FirestoreService _firestoreService = FirestoreService();
  final SyncService _syncService = SyncService();

  // =========================
  // CREATE NOTE
  // =========================

  Future<int> createNote(NoteModel note) async {
    // Fetch business to get Firestore ID
    final businesses = await DatabaseHelper.instance.getBusinesses();
    BusinessModel? business;
    try {
      business = businesses.firstWhere((b) => b.businessId == note.businessId);
    } catch (e) {
      business = null;
    }

    return await _syncService.syncOperation<int>(
      sqliteOperation: () async {
        return await DatabaseHelper.instance.insertNote(note);
      },
      firestoreOperation: () async {
        if (business != null && business.firestoreId != null) {
          print('🔥 Creating note in Firestore: businesses/${business.firestoreId}/notes/');
          await _firestoreService.createNote(
            businessId: business.firestoreId!, // ✅ Use Firestore ID
            title: note.title,
            description: note.description,
            createdAt: note.createdAt,
          );
        }
      },
      operationName: 'Create Note',
    );
  }

  // =========================
  // GET NOTES
  // =========================

  Future<List<NoteModel>> getNotes(int businessId) async {
    return await DatabaseHelper.instance.getNotes(businessId);
  }
}