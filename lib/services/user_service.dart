import '../db/database_helper.dart';
import '../models/user_model.dart';

class UserService {
  // =========================
  // CREATE USER
  // =========================

  Future<int> createUser(UserModel user) async {
    return await DatabaseHelper.instance.insertUser(user);
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
    return await DatabaseHelper.instance.getUserByFirebaseUid(uid);
  }

  // =========================
  // UPDATE USER
  // =========================

  Future updateUser(UserModel user) async {
    await DatabaseHelper.instance.updateUser(user);
  }
}
