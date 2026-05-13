import 'dart:async';

import 'package:flutter/material.dart';

import '../appbar.dart';
import 'enter_phone_number.dart';
import '../services/localization_service.dart';
import '../theme.dart';
import '../widgets/custom_button.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  static const int _initialSeconds = 56;

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = _initialSeconds;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = _initialSeconds;
      _isResending = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining == 0) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining -= 1;
      });
    });
  }

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _handleDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      value = value.substring(value.length - 1);
    }

    _controllers[index].text = value;
    _controllers[index].selection = TextSelection.collapsed(offset: value.length);

    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  Widget _buildDigitBox(int index) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.14),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        cursorColor: Colors.white,
        onChanged: (value) => _handleDigitChanged(index, value),
      ),
    );
  }

  Future<void> _onResendOtp() async {
    if (_secondsRemaining > 0) {
      return;
    }

    setState(() => _isResending = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: CustomAppBar(
            titleKey: 'otp_title',
            showLanguageSelector: false,
            backAction: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const EnterPhoneNumberScreen()),
              );
            },
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 28,
                  left: -40,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: 130,
                  right: -48,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.03),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Padding(
                                padding: EdgeInsets.only(right: index == 5 ? 0 : 14),
                                child: _buildDigitBox(index),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 16, height: 1.2),
                            children: [
                              TextSpan(
                                text: '${LocalizationService.instance.t('didnt_get_code')} ',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: _formatSeconds(_secondsRemaining),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Center(
                        child: CustomButton(
                          text: LocalizationService.instance.t('resend_otp'),
                          onPressed: _onResendOtp,
                          isLoading: _isResending,
                          width: 220,
                          height: 54,
                          borderRadius: 6,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          enabled: _secondsRemaining == 0,
                        ),
                      ),
                      const Spacer(flex: 5),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}