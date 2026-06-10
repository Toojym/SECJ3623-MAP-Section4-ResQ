import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

/// Background FCM handler must be registered here at top-level.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Lock to portrait for mobile-first design
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize push notification service
  await NotificationService.instance.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ms'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ms'),
      startLocale: const Locale('ms'),
      child: const SigapApp(),
    ),
  );
}

