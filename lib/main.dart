import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'core/navigation/app_navigator.dart';
import 'providers/ads_provider.dart';
import 'services/push_notification_service.dart';
import 'services/referral_link_service.dart';
import 'services/label_purchase_service.dart';
import 'widgets/startup_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the independent AdMob prerequisites immediately. Banners still
  // wait for consent and canRequestAds() before requesting an ad, but app
  // startup and consent/SDK initialization no longer block one another.
  unawaited(_initializeAdsInBackground());

  await initializeDateFormatting('hu_HU');
  // Firebase must be ready before a community screen/provider is built.  The
  // previous fire-and-forget initialization raced the first Chat navigation.
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase inicializálási hiba: $error');
    // Keep the rest of the app usable when a platform Firebase config is
    // missing; the affected community feature will report its own error.
  }
  runApp(const ProviderScope(child: HungarianHardstyleApp()));
  LabelPurchaseService.shared.listen();
  unawaited(_initializePushNotifications());
  unawaited(ReferralLinkService.initialize());
}

Future<void> _initializeAdsInBackground() async {
  try {
    await bootstrapAds();
  } catch (error) {
    // Consent/configuration problems must not prevent the app from starting;
    // the banner keeps its controlled retry path for a later attempt.
    debugPrint('AdMob háttér-inicializálási hiba: $error');
  }
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
      scaffoldMessengerKey: appScaffoldMessengerKey,
      title: 'Hungarian Hardstyle',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.darkTheme,
      builder: (context, child) => DecoratedBox(
        decoration: AppTheme.backgroundDecoration,
        child: child ?? const SizedBox.shrink(),
      ),

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
