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
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 282,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.88),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(42),
                            bottomRight: Radius.circular(42),
                          ),
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 42, 24, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(height: 26),
                              Center(
                                child: Container(
                                  width: 132,
                                  height: 132,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.65),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Image.asset(
                                      'assets/1.jpg',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),
                              Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    LocalizationService.instance.t('enter_email'),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 34),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8FA),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE1E6ED),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.06),
                                      blurRadius: 18,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                                child: TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    icon: const Icon(
                                      Icons.alternate_email_rounded,
                                      color: AppColors.primary,
                                    ),
                                    hintText: LocalizationService.instance.t('email_hint'),
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                                  ),
                                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                                  cursorColor: AppColors.primary,
                                  cursorWidth: 2,
                                ),
                              ),
                              const SizedBox(height: 62),
                              Center(
                                child: CustomButton(
                                  text: LocalizationService.instance.t('verify_email'),
                                  onPressed: _onSendOTP,
                                  isLoading: _loading,
                                  width: 220,
                                  height: 56,
                                  borderRadius: 14,
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
