import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'db/database_helper.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'splash_screen/logo_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // INITIALIZE NOTIFICATION SERVICE
  await NotificationService().initialize();

  // INITIALIZE DATABASE

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

      home: const LogoScreen(),
    );
  }
}
