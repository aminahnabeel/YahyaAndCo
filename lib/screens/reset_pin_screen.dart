import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/business_model.dart';
import '../services/business_service.dart';
import '../services/localization_service.dart';
import '../theme.dart';
import 'enter_pin_screen.dart';

class ResetPinScreen extends StatefulWidget {
  final BusinessModel business;

  const ResetPinScreen({super.key, required this.business});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  final _currentPinController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _businessService = BusinessService();
  final _pinFocus = FocusNode();
  final _confirmPinFocus = FocusNode();
  bool _isLoading = false;
  bool _showCurrentPin = false;
  bool _showPin = false;
  bool _showConfirmPin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _currentPinController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _pinFocus.dispose();
    _confirmPinFocus.dispose();
    super.dispose();
  }

  Future<void> _resetPin() async {
    final localization = LocalizationService.instance;
    final enteredPassword = _currentPinController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (enteredPassword.isEmpty ||
        user == null ||
        user.email == null ||
        user.email!.isEmpty) {
      _showError('Password incorrect');
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: enteredPassword,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException {
      _showError('Password incorrect');
      return;
    } catch (_) {
      _showError('Password incorrect');
      return;
    }

    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      _showError(localization.t('please_enter_pin'));
      return;
    }
    if (pin.length != 4) {
      _showError(localization.t('pin_too_short'));
      return;
    }
    if (_confirmPinController.text.isEmpty) {
      _showError(localization.t('please_enter_pin'));
      return;
    }
    if (pin != _confirmPinController.text.trim()) {
      _showError(localization.t('pins_dont_match'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      widget.business.pin = pin;
      await _businessService.updateBusiness(widget.business);
      final businessId = widget.business.businessId!;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.t('pin_set_success')),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => EnterPinScreen(businessId: businessId),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  InputDecoration _decoration({required String hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _visibilityButton(bool visible, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: Icon(
          visible ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey.shade600,
        ),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, lang, _) {
        final localization = LocalizationService.instance;
        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            title: const Text('Reset PIN'),
            backgroundColor: AppColors.primary,
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set a new PIN for this business',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.15,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _fieldLabel('Login Password'),
                  TextField(
                    controller: _currentPinController,
                    enabled: !_isLoading,
                    obscureText: !_showCurrentPin,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: _decoration(
                      hintText: 'Enter your login password',
                      suffixIcon: _visibilityButton(
                        _showCurrentPin,
                        () =>
                            setState(() => _showCurrentPin = !_showCurrentPin),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _fieldLabel('New PIN'),
                  TextField(
                    controller: _pinController,
                    focusNode: _pinFocus,
                    enabled: !_isLoading,
                    obscureText: !_showPin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.start,
                    decoration:
                        _decoration(
                          hintText: 'Enter PIN',
                          suffixIcon: _visibilityButton(
                            _showPin,
                            () => setState(() => _showPin = !_showPin),
                          ),
                        ).copyWith(
                          prefixIcon: const Icon(Icons.lock_outline),
                          counterText: '',
                        ),
                  ),
                  const SizedBox(height: 32),
                  _fieldLabel(localization.t('confirm_pin')),
                  TextField(
                    controller: _confirmPinController,
                    focusNode: _confirmPinFocus,
                    enabled: !_isLoading,
                    obscureText: !_showConfirmPin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.start,
                    decoration: _decoration(
                      hintText: localization.t('confirm_pin_hint'),
                      suffixIcon: _visibilityButton(
                        _showConfirmPin,
                        () =>
                            setState(() => _showConfirmPin = !_showConfirmPin),
                      ),
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _resetPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
