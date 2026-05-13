import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'email_verification.dart';
import '../services/localization_service.dart';
import '../theme.dart';
import '../widgets/custom_button.dart';

class EnterEmailScreen extends StatefulWidget {
  const EnterEmailScreen({super.key});

  @override
  State<EnterEmailScreen> createState() => _EnterEmailScreenState();
}

class _EnterEmailScreenState extends State<EnterEmailScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _loading = false;

  String _passwordForEmail(String email) {
    final normalized = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final seed = normalized.isEmpty ? 'user' : normalized;
    return 'Yahya#${seed}2026';
  }

  bool _isValidEmail(String value) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(value);
  }

  Future<void> _onSendOTP() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocalizationService.instance.t('invalid_email'))),
      );
      return;
    }

    setState(() => _loading = true);
    final password = _passwordForEmail(email);

    try {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      await FirebaseAuth.instance.currentUser?.sendEmailVerification();

      // Store email in SharedPreferences for later verification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_otp', true);
      await prefs.setString('verified_email', email);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const OTPScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? LocalizationService.instance.t('verification_error'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocalizationService.instance.t('verification_error'))),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, _, _) {
        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(height: 40),
                              Center(
                                child: Image.asset(
                                  'assets/1.jpg',
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 40),
                              Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    LocalizationService.instance.t('enter_email'),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 80),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                                child: TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: LocalizationService.instance.t('email_hint'),
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                    letterSpacing: 0.3,
                                  ),
                                  cursorColor: AppColors.primary,
                                  cursorWidth: 2,
                                ),
                              ),
                              const SizedBox(height: 100),
                              Center(
                                child: CustomButton(
                                  text: LocalizationService.instance.t('verify_email'),
                                  onPressed: _onSendOTP,
                                  isLoading: _loading,
                                  width: 180,
                                  height: 54,
                                  borderRadius: 6,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  backgroundColor: AppColors.primary,
                                  textColor: Colors.white,
                                  elevation: 4,
                                  loadingColor: Colors.white,
                                  letterSpacing: 0.4,
                                  enabled: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 12,
                      child: ValueListenableBuilder<String>(
                        valueListenable: LocalizationService.instance.language,
                        builder: (context, currentLanguage, _) {
                          return PopupMenuButton<String>(
                            initialValue: currentLanguage,
                            onSelected: (value) {
                              LocalizationService.instance.setLanguage(value);
                            },
                            color: AppColors.primary,
                            elevation: 8,
                            offset: const Offset(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'en',
                                textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                child: Row(
                                  children: [
                                    const Icon(Icons.public, size: 16, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      LocalizationService.instance.t('english'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'roman',
                                textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                child: Row(
                                  children: [
                                    const Icon(Icons.public, size: 16, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      LocalizationService.instance.t('roman'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.92)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.18),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.public, size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    currentLanguage == 'en'
                                        ? LocalizationService.instance.t('english_short')
                                        : LocalizationService.instance.t('roman_short'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );

      },
    );
  }
}
