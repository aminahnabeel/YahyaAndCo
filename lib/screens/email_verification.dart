import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/localization_service.dart';
import '../theme.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  late Timer _verificationTimer;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  void _startVerificationCheck() {
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkEmailVerification();
    });
  }

  Future<void> _checkEmailVerification() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Reload user to get latest authentication status
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        if (user != null && user.emailVerified) {
          // persist user info locally so app can login offline later
          try {
            final email = user.email ?? '';

            // derive deterministic password same as EnterEmailScreen
            final normalized = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            final seed = normalized.isEmpty ? 'user' : normalized;
              final password = 'Yahya#${seed}2026';

            // create local user model
            final localUser = UserModel(
              firebaseUid: user.uid,
              name: email.split('@').first,
              email: email,
              password: password,
              isVerified: 1,
              createdAt: DateTime.now().toIso8601String(),
            );

            await UserService().createUser(localUser);

            // store email/password in SharedPreferences for quick offline auth
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('offline_email', email);
            await prefs.setString('offline_password', password);
          } catch (e) {
            // ignore persistence errors
          }

          _verificationTimer.cancel();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              '/business-details',
            );
          }
        }
      }
    } catch (e) {
      // Continue checking even if there's an error
    }
  }

  @override
  void dispose() {
    _verificationTimer.cancel();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, _, _) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          size: 54,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 56),
                      Text(
                        LocalizationService.instance.t('verification_sent'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        LocalizationService.instance.t('verifying_email'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
