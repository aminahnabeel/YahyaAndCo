import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../services/localization_service.dart';
import 'dashboard/dashboard_screen.dart';
import 'set_pin_screen.dart';
import '../theme.dart';

class EnterPinScreen extends StatefulWidget {
  final int businessId;

  const EnterPinScreen({super.key, required this.businessId});

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();
  bool _isLoading = false;
  final List<bool> _pinDots = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  void _updatePinDots() {
    setState(() {
      final pinLength = _pinController.text.length;
      for (int i = 0; i < 4; i++) {
        _pinDots[i] = i < pinLength;
      }
    });
  }

  Future<void> _verifyPin() async {
    final localization = LocalizationService.instance;

    if (_pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localization.t('please_enter_pin')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_pinController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localization.t('pin_too_short')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final business = await DatabaseHelper.instance.getBusinessById(widget.businessId);

      final storedPin = (business?.pin ?? '').trim();
      final enteredPin = _pinController.text.trim();

      if (business == null || storedPin != enteredPin) {
        throw Exception(localization.t('invalid_pin'));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.t('pin_verified_success')),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to home/dashboard after 1 second
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  businessId: widget.businessId,
                  businessName: business.name,
                ),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _forgotPin() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Reset PIN',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Do you want to set a new PIN for this business?',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF4B5563),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          final business = await DatabaseHelper.instance.getBusinessById(widget.businessId);
                          if (!mounted || business == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SetPinScreen(business: business),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                          shadowColor: AppColors.primary.withOpacity(0.25),
                        ).copyWith(
                          overlayColor: MaterialStateProperty.all(
                            Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Reset PIN',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
            title: Text(localization.t('enter_pin')),
            backgroundColor: AppColors.primary,
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    localization.t('enter_pin'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localization.t('enter_pin_to_login'),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),

                  // PIN Dots Display (visual progress)
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        4,
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _pinDots[index]
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Visible PIN Input Field
                  TextField(
                    controller: _pinController,
                    focusNode: _pinFocus,
                    enabled: !_isLoading,
                    onTap: () => _pinFocus.requestFocus(),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                    onChanged: (_) => _updatePinDots(),
                    decoration: InputDecoration(
                      hintText: localization.t('pin_hint'),
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        letterSpacing: 1,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
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
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyPin,
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
                          : Text(
                              localization.t('verify'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Forgot PIN Link
                  Center(
                    child: GestureDetector(
                      onTap: _forgotPin,
                      child: Text(
                        localization.t('forgot_pin'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: 0.2,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary.withOpacity(0.65),
                          decorationThickness: 1.6,
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
