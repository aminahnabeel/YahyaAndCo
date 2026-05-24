import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/business_model.dart';
import 'business_details.dart';
import 'dashboard/dashboard_screen.dart';
import 'enter_pin_screen.dart';
import 'auth_screen.dart';
import 'email_verification_pending_screen.dart';

class StartupGate extends StatelessWidget {
  const StartupGate({super.key});

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
          return const AuthScreen();
        }

        if (!user.emailVerified) {
          return const EmailVerificationPendingScreen();
        }

        return FutureBuilder<BusinessModel?>(
          future: DatabaseHelper.instance.getLatestBusiness(),
          builder: (context, businessSnapshot) {
            if (businessSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final business = businessSnapshot.data;
            if (business == null || business.businessId == null) {
              return const BusinessDetailsScreen();
            }

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