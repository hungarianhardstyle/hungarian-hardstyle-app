import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'core/navigation/app_navigator.dart';
import 'providers/ads_provider.dart';
import 'services/push_notification_service.dart';
import 'services/referral_link_service.dart';
import 'services/label_purchase_service.dart';
import 'widgets/startup_gate.dart';
import 'widgets/session_watcher.dart';
import 'widgets/profile_access_gate.dart';
import 'screens/community/community_screen.dart';
import 'services/community_service.dart';
import 'screens/main_navigation.dart';
import 'core/firebase/firebase_callable.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the independent AdMob prerequisites immediately. Banners still
  // wait for consent and canRequestAds() before requesting an ad, but app
  // startup and consent/SDK initialization no longer block one another.
  unawaited(_initializeAdsInBackground());

  await initializeDateFormatting('hu_HU');
  await initializeFirebaseRuntime();
  await _initializeAppCheck();
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
    if (kDebugMode) {
      debugPrint('AdMob háttér-inicializálási hiba: ${error.runtimeType}');
    }
  }
}

Future<void> _initializePushNotifications() async {
  try {
    await PushNotificationService.initialize();
  } catch (_) {}
}

Future<void> _initializeAppCheck() async {
  try {
    if (kDebugMode) {
      // Debug builds use the debug provider so local/emulator testing works
      // without Firebase Console registration.
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
    }
    // Release builds deliberately do NOT activate App Check yet. Play Integrity
    // activation requires the app's SHA-256 to be registered in Firebase
    // Console → App Check, and enforcement must then be enabled gradually
    // (monitoring before enforcing). Activating too early would make every
    // callable fail, which previously broke content loading.
  } catch (_) {
    // App Check must never block startup or content loading.
  }
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
      builder: (_, child) => DecoratedBox(
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

      // ProfileAccessGate contains editable TextFields. It must remain below
      // the root Navigator so EditableText can access Navigator.overlay.
      home: _watchSession(const StartupGate()),
    );
  }

  Widget _watchSession(Widget child) {
    try {
      final service = CommunityService();
      return SessionWatcher(
        users: service.auth.userChanges().map(
          (user) => user?.isAnonymous == false ? user!.uid : null,
        ),
        refresh: service.refreshCurrentSession,
        onEnded: (deleted) {
          appNavigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const MainNavigation()),
            (_) => false,
          );
          if (deleted) {
            appScaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('A fiókodat törölték. Kijelentkeztettünk.'),
              ),
            );
          }
        },
        onVerified: () => appScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Az e-mail-címed megerősítve.')),
        ),
        child: StreamBuilder(
          stream: service.auth.userChanges(),
          initialData: service.auth.currentUser,
          builder: (_, state) {
            final user = state.data;
            if (user == null || user.isAnonymous) return child;
            return ProfileAccessGate(
              uid: user.uid,
              profile: service.firestore
                  .collection('community_profiles')
                  .doc(user.uid)
                  .snapshots(includeMetadataChanges: true)
                  .map(
                    (snapshot) => ProfileAccessState(
                      snapshot.data(),
                      fromCache: snapshot.metadata.isFromCache,
                    ),
                  ),
              completion: const CommunityProfileScreen(editing: true),
              onServerProfileMissing: () async {
                final result = await service.refreshCurrentSession();
                if (result['active'] == false) {
                  appNavigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const MainNavigation(),
                    ),
                    (_) => false,
                  );
                  if (result['deleted'] == true) {
                    appScaffoldMessengerKey.currentState?.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'A fiókodat törölték. Kijelentkeztettünk.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: child,
            );
          },
        ),
      );
    } catch (_) {
      // Startup/widget tests can run before Firebase is initialized.
      return child;
    }
  }
}
