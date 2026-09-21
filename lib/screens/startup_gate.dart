import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../services/restore_service.dart';
import 'auth_screen.dart';
import 'business_details.dart';
import 'business_switch_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'email_verification_pending_screen.dart';
import 'enter_pin_screen.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  Future<List<BusinessModel>>? _businessesFuture;
  String? _businessesUserId;
  int? _preferredBusinessId;

  Future<bool> _restoreWithRetry() async {
    final restoreService = RestoreService();

    for (var attempt = 1; attempt <= 3; attempt++) {
      final restored = await restoreService.restoreUserDataOnLogin(
        restoreOperationalData: false,
      );
      if (restored) {
        return true;
      }

      if (attempt < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }

    return false;
  }

  Future<List<BusinessModel>> _loadBusinessesAfterLogin() async {
    final localBusinesses = await DatabaseHelper.instance.getBusinesses();
    print('StartupGate: local businesses count = ${localBusinesses.length}');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('StartupGate: no current Firebase user');
      return const [];
    }

    print('StartupGate: user UID = ${user.uid}; purging stale local business data');
    await DatabaseHelper.instance.purgeOtherUsersLocalData(user.uid);

    print('StartupGate: user UID = ${user.uid}; attempting Firestore restore');
    final restoreFuture = _restoreWithRetry();
    await Future.wait<void>([
      restoreFuture,
      Future<void>.delayed(const Duration(seconds: 4)),
    ]);
    final restored = await restoreFuture;
    if (!restored) {
      print('StartupGate: Firestore restore returned false');
      return const [];
    }

    final restoredBusinesses = await DatabaseHelper.instance.getBusinesses();
    print(
      'StartupGate: restored businesses count = ${restoredBusinesses.length}',
    );
    if (restoredBusinesses.length == 1 &&
        restoredBusinesses.first.firestoreId != null) {
      await RestoreService().restoreUserDataOnLogin(
        businessFirestoreId: restoredBusinesses.first.firestoreId,
      );
    }
    final preferences = await SharedPreferences.getInstance();
    _preferredBusinessId = preferences.getInt('active_business_id_${user.uid}');
    return restoredBusinesses;
  }

  Future<List<BusinessModel>> _getBusinessesFuture(String userId) {
    if (_businessesUserId != userId) {
      _businessesUserId = userId;
      _businessesFuture = _loadBusinessesAfterLogin();
    }
    return _businessesFuture ??= _loadBusinessesAfterLogin();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          _businessesFuture = null;
          _businessesUserId = null;
          _preferredBusinessId = null;
          return const AuthScreen();
        }

        if (!user.emailVerified) {
          return const EmailVerificationPendingScreen();
        }

        return FutureBuilder<List<BusinessModel>>(
          future: _getBusinessesFuture(user.uid),
          builder: (context, businessSnapshot) {
            if (businessSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (businessSnapshot.hasError) {
              return const BusinessDetailsScreen();
            }

            final businesses = businessSnapshot.data ?? const <BusinessModel>[];
            if (businesses.isEmpty) {
              return const BusinessDetailsScreen();
            }

            final activeBusiness = businesses.length > 1 &&
                    _preferredBusinessId != null
                ? businesses.cast<BusinessModel?>().firstWhere(
                    (business) =>
                        business?.businessId == _preferredBusinessId,
                    orElse: () => null,
                  )
                : null;
            if (businesses.length > 1 && activeBusiness == null) {
              return BusinessSwitchScreen(currentBusinessId: -1);
            }

            final business = activeBusiness ?? businesses.first;
            if (business.pin != null && business.pin!.isNotEmpty) {
              return EnterPinScreen(businessId: business.businessId!);
            }

            return DashboardScreen(
              businessId: business.businessId!,
              businessName: business.name,
            );
          },
        );
      },
    );
  }
}
