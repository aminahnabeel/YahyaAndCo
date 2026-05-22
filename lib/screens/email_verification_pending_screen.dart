import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/localization_service.dart';
import '../services/user_service.dart';
import '../theme.dart';
import 'startup_gate.dart';

class EmailVerificationPendingScreen extends StatefulWidget {
  const EmailVerificationPendingScreen({super.key});

  @override
  State<EmailVerificationPendingScreen> createState() => _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState extends State<EmailVerificationPendingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerification());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resendVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await user.sendEmailVerification();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocalizationService.instance.t('verification_sent'))),
    );
  }

  Future<void> _checkVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;
    if (refreshedUser == null || !refreshedUser.emailVerified) return;

    final email = refreshedUser.email ?? '';
    final existingUser = await UserService().getUserByFirebaseUid(refreshedUser.uid);
    final localUser = UserModel(
      firebaseUid: refreshedUser.uid,
      name: refreshedUser.displayName ?? email.split('@').first,
      email: email,
      password: existingUser?.password,
      isVerified: 1,
      createdAt: existingUser?.createdAt ?? DateTime.now().toIso8601String(),
    );

    if (existingUser == null) {
      await UserService().createUser(localUser);
    } else {
      localUser.userId = existingUser.userId;
      await UserService().updateUser(localUser);
    }

    _timer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const StartupGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, _, __) {
        final localization = LocalizationService.instance;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                      child: const Icon(Icons.mark_email_read_outlined, size: 54, color: AppColors.primary),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      localization.t('verification_sent'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _resendVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(localization.t('resend_verification')),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 20),
                    Text(
                      localization.t('verifying_email'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
