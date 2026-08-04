import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'db/database_helper.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'splash_screen/logo_screen.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'helpers/firebase_debug_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // INITIALIZE NOTIFICATION SERVICE
  await NotificationService().initialize();

  // INITIALIZE DATABASE
  unawaited(DatabaseHelper.instance.database);

  // INITIALIZE SYNC SERVICE
  await SyncService().initialize();

  // DEBUG: Print Firebase status
  await FirebaseDebugHelper.printFirebaseStatus();

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
