import 'dart:async';

import 'package:flutter/material.dart';

import 'db/database_helper.dart';
import 'theme.dart';
import 'screens/logo_screen.dart';
import 'screens/otp_screen.dart';
import 'services/localization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(DatabaseHelper.instance.database);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ledger App',
      theme: AppTheme.theme,
      home: const LogoScreen(nextScreen: OTPScreen(), duration: Duration(seconds: 3)),
    );
  }
}

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 80, color: AppColors.primary),
                const SizedBox(height: 24),
                Text(
                  LocalizationService.instance.t('phone_verified'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  LocalizationService.instance.t('account_ready'),
                  style: TextStyle(fontSize: 16, color: AppColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
