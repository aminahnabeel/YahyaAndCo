import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../theme.dart';

class EnterPinScreen extends StatefulWidget {
  const EnterPinScreen({super.key});

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  List<bool> _pinDots = [false, false, false, false];

  @override
  void dispose() {
    _pinController.dispose();
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
      // TODO: Implement PIN verification logic with database
      // For now, just show success
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
          Navigator.of(context).pop();
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _forgotPin() {
    // TODO: Implement forgot PIN flow
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocalizationService.instance.t('forgot_pin_contact_support')),
        backgroundColor: Colors.orange,
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

                  // PIN Dots Display
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
                  const SizedBox(height: 48),

                  // Hidden PIN Input Field
                  TextField(
                    controller: _pinController,
                    enabled: !_isLoading,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onChanged: (_) => _updatePinDots(),
                    decoration: InputDecoration(
                      hintText: localization.t('enter_pin'),
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 0),
                    cursorColor: Colors.transparent,
                  ),
                  const SizedBox(height: 48),

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
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
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
