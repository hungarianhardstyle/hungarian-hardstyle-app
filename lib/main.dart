import 'core/i18n/tr.dart';
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'core/navigation/app_navigator.dart';
import 'core/i18n/app_language.dart';
import 'providers/ads_provider.dart';
import 'providers/language_provider.dart';
import 'services/push_notification_service.dart';
import 'services/referral_link_service.dart';
import 'services/vote_memory.dart';
import 'services/label_purchase_service.dart';
import 'services/public_content_warmer.dart';
import 'services/music_audio_handler.dart';
import 'widgets/app_text.dart';
import 'widgets/startup_gate.dart';
import 'widgets/account_prefetch.dart';
import 'widgets/radio_player_bar.dart';
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
  // Az angol dátum-nevek is a `runApp` előtt bekerülnek, hogy a nyelvváltás
  // **azonnal** hasson (ne kelljen aszinkron újrainicializálás).
  await initializeDateFormatting('en_US');
  await preloadAppLanguage();
  await initializeFirebaseRuntime();
  await _initializeAppCheck();
  // A „már játszottál / már szavaztál" emlékezet **a `runApp` előtt** betöltődik
  // a memóriába, ezért a kvíz kártyája és a képernyő már az első képkockán a
  // helyes állapotot rajzolja (a tulajdonos jelzése: *„a kviz is írhatná, hogy
  // már játszottál … kell pár másodperc mire beáll"*).
  await VoteMemory.preload();
  // A háttér-lejátszó **a `runApp` előtt** indul, mert a lejátszó példány csak
  // utána jön létre (enélkül a megvásárolt zene nem szólna háttérben).
  await _initializeBackgroundAudio();
  runApp(const ProviderScope(child: HungarianHardstyleApp()));
  // The home screen needs the news and event lists first. Starting that request
  // here runs it behind the startup gate, so the content is already cached when
  // the splash ends — also on a first install. The service shares in-flight
  // requests with the home providers, so this downloads nothing twice.
  unawaited(PublicContentWarmer.warm());
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

/// A megvásárolt zenék háttér-lejátszása: rendszer-médiamunkamenet (zárképernyő,
/// értesítés, fejhallgató-gombok) + hangfókusz.
///
/// MIÉRT KÜLÖN FÜGGVÉNYBEN ÉS `try`-ban: hiba esetén **nem állhat meg az app** —
/// a lejátszó ilyenkor a képernyőn belül marad (tartalék), csak a zárképernyős
/// vezérlés nem lesz elérhető.
Future<void> _initializeBackgroundAudio() async {
  try {
    final handler = await AudioService.init<MusicAudioHandler>(
      builder: MusicAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'hu.hungarianhardstyle.app.music',
        androidNotificationChannelName: 'Zenelejátszás',
        androidNotificationOngoing: true,
        // Szünetnél elengedi az előtér-státuszt: ne maradjon ott egy álló
        // szolgáltatás (a zárképernyőn a szünet gomb továbbra is látszik).
        androidStopForegroundOnPause: true,
      ),
    );
    setSharedMusicAudioHandler(handler);
    // A zárképernyőről indított stop is adja vissza a hangot a rádiónak — ezért
    // itt kötjük be, nem a képernyőn (az közben meg is szűnhet).
    handler.onResumeRadio = () async {
      releasePreviewPlayingState.value = false;
      await resumeRadioPlayback();
    };

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // Fejhallgató kihúzása: a rendszer jelzi — ilyenkor illik szüneteltetni.
    session.becomingNoisyEventStream.listen((_) {
      if (handler.player.playing) unawaited(handler.pause());
    });
    // Hívás vagy más zene-app: a fókusz elvesztésekor szünet. **Csak hívás
    // után** folytatjuk magunktól (`pause` típus), mert egy másik zene-apptól
    // nem vehetjük vissza a fókuszt — ugyanaz a szabály, mint a rádiónál.
    var pausedByInterruption = false;
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.duck) {
          unawaited(handler.player.setVolume(0.4));
          return;
        }
        pausedByInterruption = handler.player.playing;
        if (pausedByInterruption) unawaited(handler.pause());
        return;
      }
      if (event.type == AudioInterruptionType.duck) {
        unawaited(handler.player.setVolume(1.0));
        return;
      }
      if (pausedByInterruption && event.type == AudioInterruptionType.pause) {
        pausedByInterruption = false;
        unawaited(handler.play());
      } else {
        pausedByInterruption = false;
      }
    });
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Háttér-lejátszó indítási hiba: ${error.runtimeType}');
    }
  }
}

/// Az iOS App Check-szolgáltató **külön zászlóval** választható.
///
/// MIÉRT KELL (mérve, 2026-09-22, a telefon naplójából): az `activate()` iOS-en
/// alapból `AppleProvider.deviceCheck`-et használ (ez az enum alapértéke), és a
/// szerver elutasítja, mert ehhez az apphoz **nincs regisztrálva szolgáltató**:
///
///     AppCheck failed: '...The server responded with an error:
///      - URL: .../apps/1:1030187737487:ios:...:exchangeDeviceCheckToken
///
/// A regisztrációhoz viszont **Apple Developer fiók kell**: az App Check API
/// szerint a DeviceCheck konfighoz `keyId` ÉS `privateKey` (`.p8`) kötelező,
/// azaz fizetős tagság. Az **egyetlen út, ami Apple-fiók nélkül is működik, a
/// `debug` szolgáltató** — pontosan úgy, ahogy Androidon debugban már megy.
///
/// ⚠️ A zászlót **csak a sideloadolt teszt-build** kapja meg (a GitHub Actions
/// adja át `--dart-define`-nal). Az éles iOS build (Codemagic → TestFlight)
/// **nem** kapja meg, ott App Attest (illetve DeviceCheck) a helyes út — azzal
/// együtt, hogy a szolgáltatót regisztrálni kell a Firebase Console-ban.
///
/// ⚠️ **Az Android útja érintetlen:** a `androidProvider` kifejezése bitre
/// ugyanaz maradt (`kDebugMode ? debug : playIntegrity`).
const _appCheckDebugIos = bool.fromEnvironment(
  'HUHS_APP_CHECK_DEBUG_IOS',
  defaultValue: false,
);

/// Az iOS-en használt App Check-szolgáltató.
AppleAppCheckProvider get _appleAppCheckProvider =>
    (kDebugMode || _appCheckDebugIos)
    ? const AppleDebugProvider()
    : const AppleAppAttestWithDeviceCheckFallbackProvider();

Future<void> _initializeAppCheck() async {
  try {
    // Debug builds use the debug provider (no console registration needed).
    // Release builds use Play Integrity: its config is registered for this app
    // and the Play Integrity API is enabled. Backend enforcement is still OFF
    // (enforceAppCheck: false), so attaching tokens here cannot block content
    // loading. Enforcement can be enabled later, after this build ships.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      // iOS: lásd a fenti `_appleAppCheckProvider` magyarázatát.
      providerApple: _appleAppCheckProvider,
    );
  } catch (_) {
    // App Check must never block startup or content loading.
  }
}

class HungarianHardstyleApp extends ConsumerWidget {
  const HungarianHardstyleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A nyelv itt figyelt: ettől a `MaterialApp` locale-t vált, a feliratok
    // pedig a `tr(context, …)` Localizations-függősége miatt rajzolódnak újra.
    final language = ref.watch(languageProvider);
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      title: tr(context, 'Hungarian Hardstyle'),
      debugShowCheckedModeBanner: false,

      theme: AppTheme.darkTheme,
      builder: (_, child) => DecoratedBox(
        decoration: AppTheme.backgroundDecoration,
        child: child ?? const SizedBox.shrink(),
      ),

      locale: appLanguageLocale(language),

      supportedLocales: const [
        Locale('hu', 'HU'),
        Locale('en', 'US'),
      ],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ProfileAccessGate contains editable TextFields. It must remain below
      // the root Navigator so EditableText can access Navigator.overlay.
      // Az `AccountPrefetch` a **bejelentkezés után egyszer** melegíti a
      // fiókhoz kötött adatokat (claim-állapot, saját DJ-adatlapok), ezért az
      // első megnyitás is a mentett válaszból indul.
      home: _watchSession(
        AccountPrefetch(child: const StartupGate()),
      ),
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
                content: AppText('A fiókodat törölték. Kijelentkeztettünk.'),
              ),
            );
          }
        },
        onVerified: () => appScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: AppText('Az e-mail-címed megerősítve.')),
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
                        content: AppText(
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
