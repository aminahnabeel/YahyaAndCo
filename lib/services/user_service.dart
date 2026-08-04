import '../db/database_helper.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'sync_service.dart';

class UserService {
  final FirestoreService _firestoreService = FirestoreService();
  final SyncService _syncService = SyncService();

  // =========================
  // CREATE USER
  // =========================

  Future<int> createUser(UserModel user) async {
    return await _syncService.syncOperation<int>(
      sqliteOperation: () async {
        return await DatabaseHelper.instance.insertUser(user);
      },
      firestoreOperation: () async {
        await _firestoreService.createOrUpdateUser(
          firebaseUid: user.firebaseUid,
          name: user.name,
          email: user.email,
          isVerified: user.isVerified,
          createdAt: user.createdAt,
        );
      },
      operationName: 'Create User',
    );
  }

  // =========================
  // GET USER BY EMAIL
  // =========================

  Future<UserModel?> getUserByEmail(String email) async {
    return await DatabaseHelper.instance.getUserByEmail(email);
  }

  // =========================
  // GET USER BY FIREBASE UID
  // =========================

  Future<UserModel?> getUserByFirebaseUid(String uid) async {
    return await _syncService.syncReadOperation<UserModel?>(
      sqliteRead: () async {
        return await DatabaseHelper.instance.getUserByFirebaseUid(uid);
      },
      firestoreRead: () async {
        final data = await _firestoreService.getUserByFirebaseUid(uid);
        if (data == null) return null;
        return UserModel(
          firebaseUid: data['firebase_uid'],
          name: data['name'],
          email: data['email'],
          isVerified: data['is_verified'],
          createdAt: data['created_at'],
        );
      },
      operationName: 'Get User By Firebase UID',
    );
  }

  // =========================
  // UPDATE USER
  // =========================

  Future updateUser(UserModel user) async {
    return await _syncService.syncOperation<void>(
      sqliteOperation: () async {
        await DatabaseHelper.instance.updateUser(user);
      },
      firestoreOperation: () async {
        await _firestoreService.createOrUpdateUser(
          firebaseUid: user.firebaseUid,
          name: user.name,
          email: user.email,
          isVerified: user.isVerified,
          createdAt: user.createdAt,
        );
      },
      operationName: 'Update User',
    );
  }
}
