import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'db/database_helper.dart';
import 'theme.dart';
import 'screens/business_details.dart';
import 'screens/set_pin_screen.dart';
import 'services/localization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      home: const BusinessDetailsScreen(),
      routes: {'/business-details': (context) => const BusinessDetailsScreen()},
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
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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
