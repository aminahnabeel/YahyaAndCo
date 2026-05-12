import 'package:flutter/foundation.dart';

class LocalizationService {
  LocalizationService._private();

  static final LocalizationService instance = LocalizationService._private();

  final ValueNotifier<String> language = ValueNotifier<String>('en');

  static const supported = ['en', 'roman'];

  final Map<String, Map<String, String>> _t = {
    'en': {
      'title': 'Ledger App',
      'enter_phone': 'Please enter your phone number',
      'phone_hint': 'Phone Number',
      'send_otp': 'Send OTP',
      'ready_otp': 'Ready to get OTP?',
      'invalid_phone': 'Please enter a valid 10-digit mobile number',
      'select_language': 'Language',
      'english': 'English',
      'roman': 'Roman Urdu',
      'english_short': 'EN',
      'roman_short': 'UR',
      'phone_verified': 'Phone Verified!',
      'account_ready': 'Your account is ready',
    },
    'roman': {
      'title': 'Ledger App',
      'enter_phone': 'Aapna phone number darj karen',
      'phone_hint': 'Phone Number',
      'send_otp': 'OTP Bhejain',
      'ready_otp': 'OTP lenay ke liye tayyar hain?',
      'invalid_phone': 'Baraye mehrbani sahih 10 digit wala mobile number darj karen',
      'select_language': 'Zuban',
      'english': 'English',
      'roman': 'Roman Urdu',
      'english_short': 'EN',
      'roman_short': 'UR',
      'phone_verified': 'Phone Verified!',
      'account_ready': 'Aapka account tayyar ho gya',
    }
  };

  String t(String key) {
    final lang = language.value;
    return _t[lang]?[key] ?? key;
  }

  void setLanguage(String lang) {
    if (!supported.contains(lang)) return;
    language.value = lang;
  }
}
