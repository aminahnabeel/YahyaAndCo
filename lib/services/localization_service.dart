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
      'email_verification':
          'Check your inbox folder for the verification email.',
      'verify_email': 'Verify Email',
      'verification_sent':
          'Email verification link sent. Please check your inbox or spam folder.',
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
      'business_details': 'Business Details',
      'enter_business_info': 'Enter the business name and type',
      'business_name': 'Business Name',
      'business_type': 'Business Type',
      'select_type': 'Select a business type',
      'next': 'Next',
      'retail': 'Retail',
      'service': 'Service',
      'manufacturing': 'Manufacturing',
      'wholesale': 'Wholesale',
      'distribution': 'Distribution',
      'import_export': 'Import/Export',
      'other': 'Other',
      'please_enter_business_name': 'Please enter a business name',
      'please_select_business_type': 'Please select a business type',
      'business_created_success': 'Business created successfully!',
    },
    'roman': {
      'title': 'Yahya&Co',
      'enter_email': 'Baraye mehrbani apna email address darj karen',
      'email_hint': 'Email Address',
      'invalid_email': 'Baraye mehrbani sahih email address darj karen',
      'email_verification':
          'Verification email dekhne ke liye apna inbox folder check karen.',
      'verify_email': 'Email verify karen',
      'verification_sent':
          'Verification email bhej di gayi hai. Apna inbox ya spam folder check karen.',
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
      'invalid_phone':
          'Baraye mehrbani sahih 10 digit wala mobile number darj karen',
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
      'business_details': 'Karobaar Ki Tafseelaat',
      'enter_business_info': 'Karobaar ka naam aur qism darj karen',
      'business_name': 'Karobaar Ka Naam',
      'business_type': 'Karobaar Ki Qism',
      'select_type': 'Karobaar ki qism select karen',
      'next': 'Agle Qdam',
      'retail': 'Chhoti Dukaan',
      'service': 'Khidmat',
      'manufacturing': 'Tayyari',
      'wholesale': 'Thok Farosh',
      'distribution': 'Takseem',
      'import_export': 'Daraamad/Baramad',
      'other': 'Kuch Aur',
      'please_enter_business_name':
          'Baraye mehrbani karobaar ka naam darj karen',
      'please_select_business_type':
          'Baraye mehrbani karobaar ki qism select karen',
      'business_created_success': 'Karobaar kamyabi se bana diya gya!',
    },
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
