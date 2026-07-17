import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'core/navigation/app_navigator.dart';
import 'providers/ads_provider.dart';
import 'services/push_notification_service.dart';
import 'widgets/startup_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('hu_HU');
  // Firebase must be ready before a community screen/provider is built.  The
  // previous fire-and-forget initialization raced the first Chat navigation.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Keep the rest of the app usable when a platform Firebase config is
    // missing; the affected community feature will report its own error.
  }
  if (enableTestAds) {
    // Ads are opt-in; a provider/configuration problem must never block startup.
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}
  }
  runApp(const ProviderScope(child: HungarianHardstyleApp()));
  unawaited(_initializePushNotifications());
}

Future<void> _initializePushNotifications() async {
  try {
    await PushNotificationService.initialize();
  } catch (_) {}
}

class HungarianHardstyleApp extends StatelessWidget {
  const HungarianHardstyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Hungarian Hardstyle',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.darkTheme,

      locale: const Locale('hu', 'HU'),

      supportedLocales: const [Locale('hu', 'HU')],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const StartupGate(),
    );
  }
}
