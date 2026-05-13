import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'otp_screen.dart';
import '../services/localization_service.dart';
import '../theme.dart';
import '../widgets/custom_button.dart';

class EnterPhoneNumberScreen extends StatefulWidget {
  const EnterPhoneNumberScreen({super.key});

  @override
  State<EnterPhoneNumberScreen> createState() => _EnterPhoneNumberScreenState();
}

class _EnterPhoneNumberScreenState extends State<EnterPhoneNumberScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _loading = false;

  String _formatPhoneNumber(String value) {
    final digits = value.replaceAll(' ', '');
    if (digits.length <= 3) return digits;
    return '${digits.substring(0, 3)} ${digits.substring(3)}';
  }

  bool _isValidPakistaniMobile(String value) {
    return value.length == 10 && value.startsWith('3');
  }

  Future<void> _onSendOTP() async {
    final phone = _phoneController.text.replaceAll(' ', '');
    if (!_isValidPakistaniMobile(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocalizationService.instance.t('invalid_phone'))),
      );
      return;
    }

    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_otp', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const OTPScreen()),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, lang, _) {
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
                                child: Text(
                                  LocalizationService.instance.t('enter_phone'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade900,
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
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '+92',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 1,
                                      height: 28,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(10),
                                        ],
                                        onChanged: (value) {
                                          final digits = value.replaceAll(' ', '');
                                          final formatted = _formatPhoneNumber(digits);
                                          if (formatted != _phoneController.text) {
                                            _phoneController.value = TextEditingValue(
                                              text: formatted,
                                              selection: TextSelection.collapsed(offset: formatted.length),
                                            );
                                          }
                                        },
                                        decoration: InputDecoration(
                                          hintText: LocalizationService.instance.t('phone_hint'),
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
                                  ],
                                ),
                              ),
                              const SizedBox(height: 80),
                              Center(
                                child: Text(
                                  LocalizationService.instance.t('ready_otp'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.1,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: CustomButton(
                                  text: LocalizationService.instance.t('send_otp'),
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
