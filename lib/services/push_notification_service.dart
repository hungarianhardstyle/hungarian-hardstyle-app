import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigation/app_navigator.dart';
import '../core/navigation/in_app_browser.dart';
import '../models/event.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/news/news_detail_screen.dart';
import 'wordpress_service.dart';

class PushNotificationService {
  static const _tokenKey = 'fcm_token';
  static final Dio _api = Dio(
    BaseOptions(
      baseUrl: 'https://hungarianhardstyle.hu/wp-json/huhs/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    await _storeToken(await messaging.getToken());
    messaging.onTokenRefresh.listen(_storeToken);
    FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleOpenedMessage(initialMessage);
    }
  }

  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    final type = message.data['type']?.toString().trim() ?? '';
    final id = int.tryParse(message.data['id']?.toString() ?? '');
    final url = message.data['url']?.toString().trim() ?? '';
    if (url.isEmpty && (id == null || (type != 'news' && type != 'event'))) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    try {
      if (type == 'news' && id != null) {
        final post = await WordpressService().getPost(id);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => NewsDetailScreen(post: post)),
        );
        return;
      }

      if (type == 'event' && id != null) {
        final events = await WordpressService().getEvents();
        HuhsEvent? event;
        for (final candidate in events) {
          if (candidate.id == id) {
            event = candidate;
            break;
          }
        }
        final selectedEvent = event;
        if (selectedEvent != null && context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EventDetailScreen(event: selectedEvent),
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

  static Future<void> _showForegroundMessage(RemoteMessage message) async {
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final title = message.notification?.title?.trim() ?? 'Új értesítés';
    final body = message.notification?.body?.trim() ?? '';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? title : '$title\n$body'),
        action: SnackBarAction(
          label: 'Megnyitás',
          onPressed: () => _handleOpenedMessage(message),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  static Future<void> _storeToken(String? token) async {
    if (token == null || token.isEmpty) return;
    if (kDebugMode) debugPrint('HUHS FCM registration token: $token');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
    try {
      await _api.post(
        '/push/register',
        data: {'token': token, 'platform': defaultTargetPlatform.name},
      );
    } catch (_) {
      // Push registration must never block app startup or content loading.
    }
  }

  static Future<void> updatePreferences({
    required bool enabled,
    required bool news,
    required bool events,
    required bool reminders,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) return;
    try {
      await _api.post(
        '/push/preferences',
        data: {
          'token': token,
          'enabled': enabled,
          'news': news,
          'events': events,
          'reminders': reminders,
        },
      );
    } catch (_) {
      // Preference sync must never block the settings screen.
    }
  }
}
