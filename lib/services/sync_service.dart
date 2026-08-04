import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firestore_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  final FirestoreService _firestoreService = FirestoreService();
  final Connectivity _connectivity = Connectivity();

  bool _isConnected = false;
  Timer? _syncTimer;

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    print('🔄 Initializing SyncService...');
    
    // Check initial connectivity
    await _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      if (isConnected && !_isConnected) {
        print('✅ Internet connected - Starting sync...');
        _isConnected = true;
        _startPeriodicSync();
      } else if (!isConnected && _isConnected) {
        print('❌ Internet disconnected - Stopping sync...');
        _isConnected = false;
        _stopPeriodicSync();
      }
    });

    // Start periodic sync if connected
    if (_isConnected) {
      _startPeriodicSync();
    }

    print('✅ SyncService initialized');
  }

  // ==================== REINITIALIZE (Call this after user login) ====================

  Future<void> reinitializeAfterLogin() async {
    print('🔄 Reinitializing SyncService after login...');
    await _checkConnectivity();
    
    if (_isConnected) {
      _startPeriodicSync();
      print('✅ SyncService reinitialized - Sync enabled');
    } else {
      print('⚠️  Offline - Sync disabled');
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isConnected = result != ConnectivityResult.none;
  }

  // ==================== SYNC CONTROL ====================

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    // Sync every 30 seconds
    _syncTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      performFullSync();
    });
  }

  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // ==================== FULL SYNC ====================

  Future<void> performFullSync() async {
    if (!_isConnected || !_firestoreService.isUserLoggedIn()) {
      return;
    }

    try {
      print('🔄 Starting full sync...');
      
      // Sync happens when individual operations are performed
      // This is a placeholder for any batch sync operations
      
      print('✅ Full sync completed');
    } catch (e) {
      print('❌ Sync error: $e');
    }
  }

  // ==================== SYNC WITH ERROR HANDLING ====================

  Future<T> syncOperation<T>({
    required Future<T> Function() sqliteOperation,
    required Future<void> Function() firestoreOperation,
    required String operationName,
  }) async {
    try {
      print('🔄 [$operationName] Starting sync operation...');
      print('   Connected: $_isConnected, LoggedIn: ${_firestoreService.isUserLoggedIn()}');
      
      // 1. Perform SQLite operation first (ensures local data)
      final result = await sqliteOperation();
      print('✅ [$operationName] SQLite operation successful');

      // 2. If connected, sync with Firestore
      if (_isConnected && _firestoreService.isUserLoggedIn()) {
        try {
          await firestoreOperation();
          print('✅ [$operationName] Synced to Firestore');
        } catch (e) {
          print('⚠️  [$operationName] Firestore sync failed: $e');
          // Data is still saved locally in SQLite
        }
      } else {
        print('⚠️  [$operationName] Offline mode - saved to SQLite only');
      }

      return result;
    } catch (e) {
      print('❌ [$operationName] Operation failed: $e');
      rethrow;
    }
  }

  Future<T> syncReadOperation<T>({
    required Future<T> Function() sqliteRead,
    required Future<T> Function() firestoreRead,
    required String operationName,
  }) async {
    try {
      // If connected and logged in, try Firestore first
      if (_isConnected && _firestoreService.isUserLoggedIn()) {
        try {
          return await firestoreRead();
        } catch (e) {
          print('⚠️  Firestore read failed, falling back to SQLite: $e');
          return await sqliteRead();
        }
      } else {
        // Offline mode - use SQLite
        return await sqliteRead();
      }
    } catch (e) {
      print('❌ $operationName failed: $e');
      rethrow;
    }
  }

  // ==================== CLEANUP ====================

  void dispose() {
    _stopPeriodicSync();
  }

  // ==================== GETTERS ====================

  bool get isConnected => _isConnected;
  bool get isLoggedIn => _firestoreService.isUserLoggedIn();
}
