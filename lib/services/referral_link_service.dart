import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReferralLinkService {
  static const _pendingCodeKey = 'pending_referral_code';
  static const _installReferrerChannel = MethodChannel('hu_hs/install_referrer');
  static StreamSubscription<Uri>? _subscription;
  static Future<void>? _initialization;

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    final links = AppLinks();
    try {
      await _storeFromUri(await links.getInitialLink());
    } catch (_) {}
    try {
      final rawReferrer = await _installReferrerChannel.invokeMethod<String>(
        'getInstallReferrer',
      );
      await _storeFromInstallReferrer(rawReferrer);
    } catch (_) {}
    _subscription ??= links.uriLinkStream.listen((uri) {
      unawaited(_storeFromUri(uri));
    });
  }

  static Future<void> _storeFromInstallReferrer(String? rawReferrer) async {
    if (rawReferrer == null || rawReferrer.trim().isEmpty) return;
    final parameters = Uri(query: rawReferrer).queryParameters;
    final code = _validCode(parameters['referral_code']);
    if (code == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingCodeKey, code);
  }

  static Future<void> _storeFromUri(Uri? uri) async {
    final code = _codeFromUri(uri);
    if (code == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingCodeKey, code);
  }

  static String? _codeFromUri(Uri? uri) {
    if (uri == null || uri.host != 'hungarianhardstyle.hu') return null;
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments.first.toLowerCase() != 'invite') {
      return null;
    }
    return _validCode(segments[1]);
  }

  static String? _validCode(String? value) {
    final code = value?.trim().toUpperCase();
    return code != null && RegExp(r'^[A-Z0-9]{6,16}$').hasMatch(code)
        ? code
        : null;
  }

  static Future<String?> pendingCode() async {
    await _initialization;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_pendingCodeKey);
  }

  static Future<void> clearPendingCode() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingCodeKey);
  }
}
