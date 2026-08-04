import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  factory FirestoreService() {
    return _instance;
  }

  FirestoreService._internal();

  // ==================== USERS COLLECTION ====================

  Future<void> createOrUpdateUser({
    required String firebaseUid,
    required String name,
    required String email,
    required int isVerified,
    required String createdAt,
  }) async {
    try {
      await _db.collection('users').doc(firebaseUid).set(
        {
          'firebase_uid': firebaseUid,
          'name': name,
          'email': email,
          'is_verified': isVerified,
          'created_at': createdAt,
          'updated_at': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error creating/updating user: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserByFirebaseUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // ==================== BUSINESSES COLLECTION ====================

  Future<String> createBusiness({
    required String firebaseUid,
    required String name,
    required String type,
    String? pin,
    required String createdAt,
  }) async {
    try {
      final docRef = await _db.collection('businesses').add(
        {
          'firebase_uid': firebaseUid,
          'name': name,
          'type': type,
          'pin': pin,
          'created_at': createdAt,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      return docRef.id;
    } catch (e) {
      print('Error creating business: $e');
      rethrow;
    }
  }

  Future<void> updateBusiness({
    required String businessId,
    required String name,
    required String type,
    String? pin,
  }) async {
    try {
      await _db.collection('businesses').doc(businessId).update({
        'name': name,
        'type': type,
        'pin': pin,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating business: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getBusinessesByUser(
      String firebaseUid) async {
    try {
      final snapshot = await _db
          .collection('businesses')
          .where('firebase_uid', isEqualTo: firebaseUid)
          .get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting businesses: $e');
      return [];
    }
  }

  Future<void> deleteBusiness(String businessId) async {
    try {
      await _db.collection('businesses').doc(businessId).delete();
    } catch (e) {
      print('Error deleting business: $e');
      rethrow;
    }
  }

  // ==================== ACCOUNTS COLLECTION ====================

  Future<String> createAccount({
    required String businessId,
    required String name,
    required String type,
    String? phone,
    String? address,
    required double openingBalance,
    required String createdAt,
  }) async {
    try {
      print('📝 Creating account in Firestore...');
      print('   Business ID: $businessId, Account: $name');
      
      final docRef = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('accounts')
          .add(
        {
          'name': name,
          'type': type,
          'phone': phone,
          'address': address,
          'opening_balance': openingBalance,
          'created_at': createdAt,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      
      print('✅ Account created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error creating account: $e');
      rethrow;
    }
  }

  Future<void> updateAccount({
    required String businessId,
    required String accountId,
    required String name,
    required String type,
    String? phone,
    String? address,
    required double openingBalance,
  }) async {
    try {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('accounts')
          .doc(accountId)
          .update({
        'name': name,
        'type': type,
        'phone': phone,
        'address': address,
        'opening_balance': openingBalance,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating account: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAccountsByBusiness(
      String businessId) async {
    try {
      final snapshot = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('accounts')
          .get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting accounts: $e');
      return [];
    }
  }

  Future<void> deleteAccount(
      String businessId, String accountId) async {
    try {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('accounts')
          .doc(accountId)
          .delete();
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }

  // ==================== TRANSACTIONS COLLECTION ====================

  Future<String> createTransaction({
    required String businessId,
    required int accountId,
    int? toAccountId,
    required double amount,
    required String type,
    required String note,
    required String paymentMethod,
    String? dueDate,
    required String paymentStatus,
    required double remainingAmount,
    String? imageUrl,
    required String date,
    required String createdAt,
  }) async {
    try {
      print('📝 Creating transaction in Firestore...');
      print('   Business ID: $businessId');
      print('   Amount: $amount, Type: $type');
      
      final docRef = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('transactions')
          .add(
        {
          'account_id': accountId,
          'to_account_id': toAccountId,
          'amount': amount,
          'type': type,
          'note': note,
          'payment_method': paymentMethod,
          'due_date': dueDate,
          'payment_status': paymentStatus,
          'remaining_amount': remainingAmount,
          'image_url': imageUrl,
          'date': date,
          'created_at': createdAt,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      
      print('✅ Transaction created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error creating transaction: $e');
      rethrow;
    }
  }

  Future<void> updateTransaction({
    required String businessId,
    required String transactionId,
    required double amount,
    required String type,
    required String note,
    required String paymentMethod,
    String? dueDate,
    required String paymentStatus,
    required double remainingAmount,
    String? imageUrl,
    required String date,
  }) async {
    try {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('transactions')
          .doc(transactionId)
          .update({
        'amount': amount,
        'type': type,
        'note': note,
        'payment_method': paymentMethod,
        'due_date': dueDate,
        'payment_status': paymentStatus,
        'remaining_amount': remainingAmount,
        'image_url': imageUrl,
        'date': date,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating transaction: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionsByBusiness(
      String businessId) async {
    try {
      final snapshot = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('transactions')
          .orderBy('created_at', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }

  Future<void> deleteTransaction(
      String businessId, String transactionId) async {
    try {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
    }
  }

  // ==================== JOURNAL ENTRIES COLLECTION ====================

  Future<String> createJournalEntry({
    required String businessId,
    int? transactionId,
    required String voucherNo,
    required String voucherType,
    required String description,
    String? dueDate,
    required String paymentStatus,
    required double remainingAmount,
    String? imageUrl,
    required String date,
    required String createdAt,
  }) async {
    try {
      print('📝 Creating journal entry in Firestore...');
      print('   Business ID: $businessId');
      print('   Voucher: $voucherNo ($voucherType)');
      
      final docRef = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('journal_entries')
          .add(
        {
          'transaction_id': transactionId,
          'voucher_no': voucherNo,
          'voucher_type': voucherType,
          'description': description,
          'due_date': dueDate,
          'payment_status': paymentStatus,
          'remaining_amount': remainingAmount,
          'image_url': imageUrl,
          'date': date,
          'created_at': createdAt,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      
      print('✅ Journal entry created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error creating journal entry: $e');
      rethrow;
    }
  }

  Future<void> updateJournalEntry({
    required String businessId,
    required String journalId,
    required String voucherNo,
    required String voucherType,
    required String description,
    String? dueDate,
    required String paymentStatus,
    required double remainingAmount,
    String? imageUrl,
    required String date,
  }) async {
    try {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('journal_entries')
          .doc(journalId)
          .update({
        'voucher_no': voucherNo,
        'voucher_type': voucherType,
        'description': description,
        'due_date': dueDate,
        'payment_status': paymentStatus,
        'remaining_amount': remainingAmount,
        'image_url': imageUrl,
        'date': date,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating journal entry: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getJournalEntriesByBusiness(
      String businessId) async {
    try {
      final snapshot = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('journal_entries')
          .orderBy('created_at', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting journal entries: $e');
      return [];
    }
  }

  Future<void> deleteJournalEntry(
      String businessId, String journalId) async {
    try {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('journal_entries')
          .doc(journalId)
          .delete();
    } catch (e) {
      print('Error deleting journal entry: $e');
      rethrow;
    }
  }

  // ==================== EXPENSE CATEGORIES COLLECTION ====================

  Future<String> createExpenseCategory({
    required String businessId,
    required String name,
  }) async {
    try {
      final docRef = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('expense_categories')
          .add(
        {
          'name': name,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
      return docRef.id;
    } catch (e) {
      print('Error creating expense category: $e');
      rethrow;
    }
  }

  Future<void> updateExpenseCategory({
    required String businessId,
    required String categoryId,
    required String name,
  }) async {
    try {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('expense_categories')
          .doc(categoryId)
          .update({
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating expense category: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getExpenseCategoriesByBusiness(
      String businessId) async {
    try {
      final snapshot = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('expense_categories')
          .get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting expense categories: $e');
      return [];
    }
  }

  Future<void> deleteExpenseCategory(
      String businessId, String categoryId) async {
    try {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('expense_categories')
          .doc(categoryId)
          .delete();
    } catch (e) {
      print('Error deleting expense category: $e');
      rethrow;
    }
  }

  // ==================== NOTES COLLECTION ====================

  Future<String> createNote({
    required String businessId,
    required String title,
    required String description,
    required String createdAt,
  }) async {
    try {
      final docRef = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('notes')
          .add(
        {
          'title': title,
          'description': description,
          'created_at': createdAt,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      return docRef.id;
    } catch (e) {
      print('Error creating note: $e');
      rethrow;
    }
  }

  Future<void> updateNote({
    required String businessId,
    required String noteId,
    required String title,
    required String description,
  }) async {
    try {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('notes')
          .doc(noteId)
          .update({
        'title': title,
        'description': description,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating note: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getNotesByBusiness(
      String businessId) async {
    try {
      final snapshot = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('notes')
          .orderBy('created_at', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting notes: $e');
      return [];
    }
  }

  Future<void> deleteNote(String businessId, String noteId) async {
    try {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('notes')
          .doc(noteId)
          .delete();
    } catch (e) {
      print('Error deleting note: $e');
      rethrow;
    }
  }

  // ==================== JOURNAL LINES SUBCOLLECTION ====================

  Future<void> addJournalLines({
    required String businessId,
    required String journalId,
    required List<Map<String, dynamic>> journalLines,
  }) async {
    try {
      final batch = _db.batch();
      
      for (final line in journalLines) {
        final docRef = _db
            .collection('businesses')
            .doc(businessId)
            .collection('journal_entries')
            .doc(journalId)
            .collection('journal_lines')
            .doc();
        
        batch.set(docRef, {
          'account_id': line['account_id'],
          'debit': line['debit'],
          'credit': line['credit'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      print('Error adding journal lines: $e');
      rethrow;
    }
  }

  Future<void> deleteJournalLines({
    required String businessId,
    required String journalId,
  }) async {
    try {
      final snapshot = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('journal_entries')
          .doc(journalId)
          .collection('journal_lines')
          .get();
      
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      print('Error deleting journal lines: $e');
      rethrow;
    }
  }

  // ==================== HELPER METHODS ====================

  String? getCurrentUserUid() {
    return _auth.currentUser?.uid;
  }

  bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }
}
