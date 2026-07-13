import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotificationService {
  static const _tokenKey = 'fcm_token';

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
  }

  static Future<void> _storeToken(String? token) async {
    if (token == null || token.isEmpty) return;
    if (kDebugMode) debugPrint('HUHS FCM registration token: $token');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }
}
