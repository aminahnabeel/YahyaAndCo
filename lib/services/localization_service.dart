import 'package:flutter/foundation.dart';

class LocalizationService {
  LocalizationService._private();

  static final LocalizationService instance = LocalizationService._private();

  final ValueNotifier<String> language = ValueNotifier<String>('en');

  static const supported = ['en', 'roman'];

  final Map<String, Map<String, String>> _t = {
    'en': {
      'title': 'Yahya&Co',
      'enter_email': 'Please enter your email address',
      'email_hint': 'Email Address',
      'invalid_email': 'Please enter a valid email address',
      'email_verification': 'Check your inbox folder for the verification email.',
      'verify_email': 'Verify Email',
      'verification_sent': 'Email verification link sent. Please check your inbox or spam folder.',
      'verifying_email': 'Verifying your email...',
      'verification_error': 'Error sending verification email',
      'otp_title': 'Enter the 6-digit Code',
      'otp_hint': 'Verification Code',
      'invalid_code': 'Please enter the 6-digit verification code',
      'verify_code': 'Verify Code',
      'enter_phone': 'Please enter your phone number',
      'phone_hint': 'Phone Number',
      'send_otp': 'Send OTP',
      'ready_otp': 'Ready to get OTP?',
      'invalid_phone': 'Please enter a valid 10-digit mobile number',
      'didnt_get_code': "Didn't get the code?",
      'resend_otp': 'Resend OTP',
      'verifying': 'Verifying...',
      'select_language': 'Language',
      'english': 'English',
      'roman': 'Roman Urdu',
      'english_short': 'EN',
      'roman_short': 'UR',
      'phone_verified': 'Phone Verified!',
      'account_ready': 'Your account is ready',
    },
    'roman': {
      'title': 'Yahya&Co',
      'enter_email': 'Baraye mehrbani apna email address darj karen',
      'email_hint': 'Email Address',
      'invalid_email': 'Baraye mehrbani sahih email address darj karen',
      'email_verification': 'Verification email dekhne ke liye apna inbox folder check karen.',
      'verify_email': 'Email verify karen',
      'verification_sent': 'Verification email bhej di gayi hai. Apna inbox ya spam folder check karen.',
      'verifying_email': 'Aapki email verify ho rahi hai...',
      'verification_error': 'Verification email bhejne mein error',
      'otp_title': '6-digit code darj karen',
      'otp_hint': 'Verification Code',
      'invalid_code': 'Baraye mehrbani 6-digit verification code darj karen',
      'verify_code': 'Code verify karen',
      'enter_phone': 'Aapna phone number darj karen',
      'phone_hint': 'Phone Number',
      'send_otp': 'OTP Bhejain',
      'ready_otp': 'OTP lenay ke liye tayyar hain?',
      'invalid_phone': 'Baraye mehrbani sahih 10 digit wala mobile number darj karen',
      'didnt_get_code': 'Code nahi mila?',
      'resend_otp': 'OTP dobara bhejen',
      'verifying': 'Verify ho raha hai...',
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
