import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'db/database_helper.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'splash_screen/logo_screen.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'helpers/firebase_debug_helper.dart';
import 'screens/enter_email.dart';

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _pendingPasswordResetLink;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _listenForPasswordResetCompletion();
    }
  }

  Future<void> _listenForPasswordResetCompletion() async {
    final appLinks = AppLinks();
    final initialLink = await appLinks.getInitialLink();
    _pendingPasswordResetLink = initialLink;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePasswordResetLink(_pendingPasswordResetLink);
      _pendingPasswordResetLink = null;
    });
    _linkSubscription = appLinks.uriLinkStream.listen(_handlePasswordResetLink);
  }

  void _handlePasswordResetLink(Uri? uri) {
    if (uri == null || uri.path != '/password-reset-complete') return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _pendingPasswordResetLink = uri;
      return;
    }
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const EnterEmailScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,

      title: 'Ledger App',

      theme: AppTheme.theme,

      home: const LogoScreen(),
    );
  }
}
