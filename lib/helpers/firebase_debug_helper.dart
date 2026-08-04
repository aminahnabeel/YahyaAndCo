import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/sync_service.dart';

class FirebaseDebugHelper {
  static Future<void> printFirebaseStatus() async {
    print('\n========== 🔍 FIREBASE DEBUG INFO ==========');
    
    // Check Auth
    final user = FirebaseAuth.instance.currentUser;
    print('✅ Firebase Auth:');
    print('   - User Logged In: ${user != null}');
    if (user != null) {
      print('   - UID: ${user.uid}');
      print('   - Email: ${user.email}');
      print('   - Verified: ${user.emailVerified}');
    }
    
    // Check Services
    final firestoreService = FirestoreService();
    final syncService = SyncService();
    
    print('✅ Firestore Service:');
    print('   - User Logged In: ${firestoreService.isUserLoggedIn()}');
    print('   - User UID: ${firestoreService.getCurrentUserUid()}');
    
    print('✅ Sync Service:');
    print('   - Connected: ${syncService.isConnected}');
    print('   - Logged In: ${syncService.isLoggedIn}');
    
    print('==========================================\n');
  }
}
