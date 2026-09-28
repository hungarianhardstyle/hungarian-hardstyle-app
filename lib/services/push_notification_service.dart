import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/tr.dart';
import '../core/navigation/app_navigator.dart';
import '../core/navigation/content_target.dart';
import '../core/navigation/in_app_browser.dart';
import '../models/event.dart';
import '../models/release.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/more/community_users_screen.dart';
import '../screens/news/news_detail_screen.dart';
import '../screens/releases/release_detail_screen.dart';
import '../screens/community/wordpress_admin_screen.dart';
import '../screens/community/private_messages_screen.dart';
import '../screens/community/community_screen.dart';
import '../widgets/app_text.dart';
import 'notification_permission_gate.dart';
import 'push_language.dart';
import 'wordpress_service.dart';

class PushNotificationService {
  static const _tokenKey = 'fcm_token';
  // A Play-telepítés és a korábbi tesztAPK-k között az FCM-token cserélődhet.
  // Verzióváltáskor egyszer kötelezően új token készül, így nem marad bent
  // olyan token, amelyre a Cloud Function már nem tud kézbesíteni.
  static const _tokenRefreshKey = 'fcm_token_refresh_v3';
  static bool _initializeStarted = false;
  static bool _registrationDone = false;
  static OverlayEntry? _foregroundEntry;
  static StreamSubscription<User?>? _authSubscription;
  static final Dio _api = Dio(
    BaseOptions(
      baseUrl: 'https://hungarianhardstyle.hu/wp-json/huhs/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static const _contentRefreshDelays = <Duration>[
    Duration.zero,
    Duration(seconds: 2),
    Duration(seconds: 5),
  ];

  static Future<HuhsEvent?> _findEventWithRetry(int id) async {
    for (final delay in _contentRefreshDelays) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      try {
        final events = await WordpressService().getEvents();
        for (final event in events) {
          if (event.id == id) return event;
        }
      } catch (_) {
        // A newly published item may not be visible to the API immediately.
      }
    }
    return null;
  }

  static Future<HuhsRelease?> _findReleaseWithRetry(int id) async {
    for (final delay in _contentRefreshDelays) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      try {
        final releases = await WordpressService().getReleases();
        for (final release in releases) {
          if (release.id == id) return release;
        }
      } catch (_) {
        // A newly published item may not be visible to the API immediately.
      }
    }
    return null;
  }

  static Future<void> initialize() async {
    if (_initializeStarted) return;
    _initializeStarted = true;

    // ⚠️ 2026-09-28 — AZ OS-ABLAK **NEM ITT** JELENIK MEG (mért probléma: eddig
    // induláskor, minden felhasználói művelet előtt kértük az engedélyt, ezért
    // sokan elutasították, és Android 13+ utánna már nem is kérdez).
    // Induláskor csak **lekérdezzük** az állapotot (`getNotificationSettings()`
    // nem vált ki ablakot). Ha az engedély megvan, pontosan a **régi** útvonal
    // fut le (token + figyelők) — a meglévő felhasználók értesítései
    // változatlanok. Ha nincs, a kérés az első értelmes műveletre vár
    // (`notification_permission_gate.dart`).
    if (!await isPermissionGranted()) return;
    await _completeRegistration();
  }

  /// Az OS-engedély állapota **kérés nélkül**.
  ///
  /// A `getNotificationSettings()` nem mutat semmit, ezért ez biztonságosan
  /// hívható induláskor és a kapuból is.
  static Future<bool> isPermissionGranted() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return notificationPermissionIsGranted(settings.authorizationStatus);
  }

  /// Az OS-ablak **megjelenítése**, majd siker esetén a token-útvonal.
  ///
  /// Ezt **csak** a kapu hívja (`NotificationPermissionGate`), az első értelmes
  /// felhasználói művelet után. Visszaadja, hogy megkaptuk-e az engedélyt.
  static Future<bool> requestPermissionNow() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (!notificationPermissionIsGranted(settings.authorizationStatus)) {
      return false;
    }
    await _completeRegistration();
    return true;
  }

  /// Az engedéllyel járó útvonal lefuttatása, ha még nem futott (**idempotens**).
  ///
  /// Erre azért kell külön belépés, hogy egy később megadott engedélynél se
  /// vesszen el a token (a `requestPermissionNow()` ugyanezt hívja).
  static Future<void> ensureRegistered() async {
    if (_registrationDone) return;
    if (!await isPermissionGranted()) return;
    await _completeRegistration();
  }

  /// A token- és figyelő-útvonal (a régi `initialize()` törzse, változatlan
  /// sorrendben) — egyszer fut, és csak **meglévő** engedéllyel.
  static Future<void> _completeRegistration() async {
    if (_registrationDone) return;
    _registrationDone = true;

    final messaging = FirebaseMessaging.instance;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_tokenRefreshKey) != true) {
      try {
        await messaging.deleteToken();
      } catch (_) {}
      await preferences.remove(_tokenKey);
      await preferences.setBool(_tokenRefreshKey, true);
    }
    await _storeToken(await messaging.getToken());
    _authSubscription ??= FirebaseAuth.instance.idTokenChanges().listen((_) {
      unawaited(_refreshAndStoreToken());
    });
    await _syncStoredToken();
    messaging.onTokenRefresh.listen(_storeToken);
    FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleOpenedMessage(initialMessage);
    }
  }

  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    final type =
        (message.data['type'] ?? message.data['targetType'])
            ?.toString()
            .trim() ??
        '';
    final senderId =
        (message.data['senderId'] ?? message.data['from'])?.toString().trim() ??
        '';
    final targetUserId =
        (message.data['targetId'] ?? senderId)?.toString().trim() ?? '';
    final id = int.tryParse(
      (message.data['id'] ??
                  message.data['postId'] ??
                  message.data['articleId'] ??
                  message.data['eventId'] ??
                  message.data['targetId'])
              ?.toString() ??
          '',
    );
    final url =
        (message.data['url'] ?? message.data['link'])?.toString().trim() ?? '';
    if (url.isEmpty &&
        senderId.isEmpty &&
        targetUserId.isEmpty &&
        (id == null ||
            (type != 'news' &&
                type != 'event' &&
                type != 'release' &&
                type != 'achievement_points' &&
                type != 'submission'))) {
      return;
    }

    final context = await _waitForNavigationContext();
    if (context == null || !context.mounted) return;

    try {
      if ((type == 'connection_request' || type == 'connection_accepted') &&
          targetUserId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPublicProfileScreen(userId: targetUserId),
          ),
        );
        return;
      }

      if (type == 'meetup_interest' && senderId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPublicProfileScreen(userId: senderId),
          ),
        );
        return;
      }

      if (type == 'private_message' &&
          senderId.isNotEmpty &&
          message.data['conversationId']?.toString().trim().isNotEmpty ==
              true) {
        final senderName =
            message.notification?.title
                ?.replaceFirst(RegExp(r' üzenetet küldött$'), '')
                .trim() ??
            'HUHS user';
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PrivateConversationScreen(
              otherUserId: senderId,
              otherUserName: senderName.isEmpty ? 'HUHS user' : senderName,
            ),
          ),
        );
        return;
      }

      if (type == 'submission') {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const WordPressAdminScreen()),
        );
        return;
      }

      // ⚠️ 2026-09-27: a **születési dátum** kérése (a meglévő tagoknak szóló
      // emlékeztető, `sendBirthDateNotices`). A célpont-feloldás **közös**
      // (`openContentTarget`) — ugyanaz, amit az értesítés-központ hív, ezért a
      // két út nem tud széthúzni.
      if (type == 'birth_date' && targetUserId.isNotEmpty) {
        await openContentTarget(
          Navigator.of(context),
          targetType: 'birth_date',
          targetId: targetUserId,
        );
        return;
      }

      // „@mindenki" PUSH (2026-09-26): a Chat képernyőt nyitja, és **arra az
      // üzenetre** görget, amelyikről szól — ugyanaz az út, mint a bejövő
      // listabeli értesítésnél (`LiveFeedScreen(focusPostId: …)`). Az azonosító
      // itt NEM szám (Firestore-azonosító), ezért külön ág kell.
      if (type == 'chat_everyone' || type == 'chat_mention') {
        final postId =
            (message.data['postId'] ?? message.data['targetId'])
                ?.toString()
                .trim() ??
            '';
        if (postId.isEmpty) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LiveFeedScreen(focusPostId: postId),
          ),
        );
        return;
      }

      if (type == 'achievement_points' && targetUserId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPublicProfileScreen(userId: targetUserId),
          ),
        );
        return;
      }

      if ((type == 'news' || type == 'article_comment') && id != null) {
        final post = await WordpressService().getPost(id);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => NewsDetailScreen(post: post)),
        );
        return;
      }

      if ((type == 'event' || type == 'event_rating_request') && id != null) {
        final selectedEvent = await _findEventWithRetry(id);
        if (selectedEvent != null && context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EventDetailScreen(event: selectedEvent),
            ),
          );
          return;
        }
      }

      if (type == 'release' && id != null) {
        final selectedRelease = await _findReleaseWithRetry(id);
        if (selectedRelease != null && context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReleaseDetailScreen(release: selectedRelease),
            ),
          );
          return;
        }
      }
    } catch (_) {
      // Fall back to the link when the native record is unavailable.
    }

    if (context.mounted && url.isNotEmpty) {
      await openInAppBrowser(context, url, title: message.notification?.title);
    }
  }

  static Future<BuildContext?> _waitForNavigationContext() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final context = appNavigatorKey.currentContext;
      if (context != null && context.mounted) return context;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }

  static Future<void> _showForegroundMessage(RemoteMessage message) async {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _foregroundEntry?.remove();
    final dataTitle = message.data['title']?.toString().trim() ?? '';
    final dataBody = message.data['body']?.toString().trim() ?? '';
    final title = message.notification?.title?.trim().isNotEmpty == true
        ? message.notification!.title!.trim()
        : (dataTitle.isEmpty ? 'Új értesítés' : dataTitle);
    final body = (message.notification?.body?.trim().isNotEmpty == true
        ? message.notification!.body!.trim()
        : dataBody);
    final canOpen = _hasOpenTarget(message);
    final entry = OverlayEntry(
      builder: (_) => _ForegroundPushBanner(
        title: title,
        body: body,
        canOpen: canOpen,
        onOpen: () {
          _dismissForegroundEntry();
          if (canOpen) unawaited(_handleOpenedMessage(message));
        },
        onDismiss: _dismissForegroundEntry,
      ),
    );
    _foregroundEntry = entry;
    overlay.insert(entry);
  }

  static void _dismissForegroundEntry() {
    _foregroundEntry?.remove();
    _foregroundEntry = null;
  }

  static bool _hasOpenTarget(RemoteMessage message) {
    final type =
        (message.data['type'] ?? message.data['targetType'])
            ?.toString()
            .trim() ??
        '';
    final senderId =
        (message.data['senderId'] ?? message.data['from'])?.toString().trim() ??
        '';
    final id = int.tryParse(
      (message.data['id'] ??
                  message.data['postId'] ??
                  message.data['articleId'] ??
                  message.data['eventId'] ??
                  message.data['targetId'])
              ?.toString() ??
          '',
    );
    final url =
        (message.data['url'] ?? message.data['link'])?.toString().trim() ?? '';
    // A „@mindenki" push célpontja egy **Chat-üzenet** (nem szám azonosító):
    // enélkül a fölértesítés nem lenne koppintható.
    final chatPostId =
        (message.data['postId'] ?? message.data['targetId'])
            ?.toString()
            .trim() ??
        '';
    return type == 'submission' ||
        // A születési dátum kérése (2026-09-27) ugyanígy koppintható.
        (type == 'birth_date' &&
            (message.data['targetId'] ?? message.data['senderId'])
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true) ||
        ((type == 'chat_everyone' || type == 'chat_mention') &&
            chatPostId.isNotEmpty) ||
        (type == 'connection_request' && senderId.isNotEmpty) ||
        (type == 'meetup_interest' && senderId.isNotEmpty) ||
        (type == 'private_message' &&
            senderId.isNotEmpty &&
            message.data['conversationId']?.toString().trim().isNotEmpty ==
                true) ||
        ((type == 'news' || type == 'event' || type == 'release') &&
            id != null) ||
        url.isNotEmpty;
  }

  static Future<void> _storeToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final previousToken = preferences.getString(_tokenKey);
    await preferences.setString(_tokenKey, token);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous && Firebase.apps.isNotEmpty) {
      try {
        final privateRef = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'hungarian-hardstyle',
        ).collection('private_user_data').doc(user.uid);
        if (previousToken != null &&
            previousToken.isNotEmpty &&
            previousToken != token) {
          try {
            await privateRef.update({
              'fcmTokens': FieldValue.arrayRemove([previousToken]),
            });
          } catch (_) {
            // A missing legacy profile must not prevent the new token save.
          }
        }
        await privateRef.set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            'HUHS FCM profile token sync failed: ${error.runtimeType}',
          );
        }
      }
    }
    try {
      await _api.post(
        '/push/register',
        data: {
          'token': token,
          'platform': defaultTargetPlatform.name,
          // ⚠️ A plugin 2.14.6 a token-rekordban tárolt nyelven küldi az
          // **esemény-emlékeztetőt** — enélkül az angol felületű tag is magyar
          // emlékeztetőt kapna. Hiányzó/ismeretlen értékre a szerver magyar,
          // ezért más kliensek viselkedése nem változik (`push_language.dart`).
          pushLanguageField: await resolvePushLanguage(
            preferences: preferences,
          ),
        },
      );
    } catch (_) {
      // Push registration must never block app startup or content loading.
    }
  }

  static Future<void> _syncStoredToken() async {
    final preferences = await SharedPreferences.getInstance();
    await _storeToken(preferences.getString(_tokenKey));
  }

  static Future<void> _refreshAndStoreToken() async {
    try {
      await _storeToken(await FirebaseMessaging.instance.getToken());
    } catch (error) {
      if (kDebugMode) {
        debugPrint('HUHS FCM token refresh failed: ${error.runtimeType}');
      }
      await _syncStoredToken();
    }
  }

  /// **Csak a követett tartalom** szinkronja a plugin felé (381).
  ///
  /// MIÉRT külön: a kedvencelés a `FavoritesNotifier`-ben történik, ahol a
  /// beállítás-kapcsolók (news/events/…) **nem** ismertek — a teljes
  /// `updatePreferences` hívása ezért felülírná azokat. A plugin viszont a
  /// **hiányzó** kulcsnál a korábbi értéket tartja meg, ezért elég csak ezt a
  /// kettőt elküldeni; így a kedvencelés azonnal érvényesül a push-célzásban.
  ///
  /// ⚠️ Üres listát **nem** küldünk (az felülírná a tárolt kedvenceket).
  static Future<void> syncFollowedTargets({
    required List<int> artists,
    required List<int> organizers,
  }) async {
    if (artists.isEmpty && organizers.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) return;
    try {
      await _api.post(
        '/push/preferences',
        data: {
          'token': token,
          if (artists.isNotEmpty) 'artists': artists,
          if (organizers.isNotEmpty) 'organizers': organizers,
        },
      );
    } catch (_) {
      // A kedvencelés helyben érvényes marad; a következő mentés újrapróbálja.
    }
  }

  static Future<void> updatePreferences({
    required bool enabled,
    required bool news,
    required bool events,
    required bool releases,
    required bool reminders,
    required bool achievements,
    required bool digest,
    // ⚠️ KÖVETETT TARTALOM (381): a kedvelt DJ-k/szervezők azonosítói. Ezekből
    // lesz a **személyes** célzás a pluginban (2.14.9) — aki követi a tartalom
    // szereplőjét, az biztos megkapja az értesítést.
    //
    // ⚠️ FONTOS: üres lista esetén a kulcsot **NEM küldjük el**, mert a plugin a
    // hiányzó kulcsnál a KORÁBBI értéket tartja meg — egy üres lista viszont
    // felülírná (és elvesznének a kedvencek egy sima beállítás-mentésnél).
    List<int> artists = const <int>[],
    List<int> organizers = const <int>[],
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous && Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'hungarian-hardstyle',
        ).collection('private_user_data').doc(user.uid).set({
          'notificationPreferences': {
            'enabled': enabled,
            'achievements': achievements,
            // ⚠️ A `digest` a **szerveroldali** heti összefoglaló kapuja
            // (`sendWeeklyDigest` → `digestAllowed`). A `merge: true` miatt a
            // hiányzó kulcs nem töröl semmit, csak nem írja felül — ezért kell
            // minden mentésnél küldeni.
            'digest': digest,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // The WordPress preference sync below remains available to older clients.
      }
    }
    try {
      await _api.post(
        '/push/preferences',
        data: {
          'token': token,
          'enabled': enabled,
          'news': news,
          'events': events,
          'releases': releases,
          'reminders': reminders,
          'achievements': achievements,
          // A plugin a saját token-rekordjában is eltárolja (az ismeretlen kulcsot
          // figyelmen kívül hagyja, ezért régi plugin-verzión sem törik el).
          'digest': digest,
          // A követett tartalom (381): csak akkor megy, ha van mit küldeni.
          if (artists.isNotEmpty) 'artists': artists,
          if (organizers.isNotEmpty) 'organizers': organizers,
          pushLanguageField: await resolvePushLanguage(
            preferences: preferences,
          ),
        },
      );
    } catch (_) {
      // Preference sync must never block the settings screen.
    }
  }
}

class _ForegroundPushBanner extends StatefulWidget {
  const _ForegroundPushBanner({
    required this.title,
    required this.body,
    required this.canOpen,
    required this.onOpen,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final bool canOpen;
  final VoidCallback? onOpen;
  final VoidCallback onDismiss;

  @override
  State<_ForegroundPushBanner> createState() => _ForegroundPushBannerState();
}

class _ForegroundPushBannerState extends State<_ForegroundPushBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 7), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 142;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: Dismissible(
        key: const ValueKey('huhs-foreground-push'),
        direction: DismissDirection.vertical,
        onDismissed: (_) => widget.onDismiss(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpen ?? widget.onDismiss,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF21191A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF8F2D31)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 12),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFFFF3D43),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                        if (widget.canOpen) ...[
                          const SizedBox(height: 8),
                          const AppText(
                            'Koppints a megnyitáshoz',
                            style: TextStyle(
                              color: Color(0xFFFF555A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr(context, 'Bezárás'),
                    onPressed: widget.onDismiss,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
