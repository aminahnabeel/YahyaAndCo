import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  Future<List<BusinessModel>> _loadBusinessesAfterLogin() async {
    final localBusinesses = await DatabaseHelper.instance.getBusinesses();
    print('StartupGate: local businesses count = ${localBusinesses.length}');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('StartupGate: no current Firebase user');
      return const [];
    }

    print('StartupGate: user UID = ${user.uid}; attempting Firestore restore');
    final restoreService = RestoreService();
    final restoreFuture = restoreService.restoreUserDataOnLogin();
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
    return restoredBusinesses;
  }

  Future<List<BusinessModel>> _getBusinessesFuture(String userId) {
    if (_businessesUserId != userId) {
      _businessesUserId = userId;
      _businessesFuture = _loadBusinessesAfterLogin();
    }
    return _businessesFuture ??= _loadBusinessesAfterLogin();
  }

  void _retryBusinessLoad() {
    setState(() {
      _businessesFuture = _loadBusinessesAfterLogin();
    });
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
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Loading your data...'),
                      TextButton(
                        onPressed: _retryBusinessLoad,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final businesses = businessSnapshot.data ?? const <BusinessModel>[];
            if (businesses.isEmpty) {
              return const BusinessDetailsScreen();
            }

            if (businesses.length > 1) {
              return BusinessSwitchScreen(currentBusinessId: -1);
            }

            final business = businesses.first;
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
