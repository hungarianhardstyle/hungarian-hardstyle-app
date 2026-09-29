import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_link_resolver.dart';
import 'content_link_route.dart';

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
    if (code != null) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_pendingCodeKey, code);
      return;
    }
    // **Tartalom-link** (381): a megosztott hír/esemény/kiadvány/DJ linket
    // feloldjuk (típus + azonosító), és eltesszük a felületnek — így az app a
    // megfelelő adatlapot nyitja meg, nem a főoldalt. A hálózat itt **best-effort**:
    // ha nem megy, nem történik semmi (a böngészőben a link úgyis olvasható).
    final route = contentLinkRouteFromUri(uri);
    if (route.kind == ContentLinkKind.unknown && !route.isNavigable) return;
    if (route.kind == ContentLinkKind.invite) return;
    final target = await resolveContentLink(route, _fetchJson);
    if (target == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _pendingContentKey,
      '${target.kind.name}:${target.id}',
    );
  }

  /// A feloldó végpont hívása (`dio`), hiba esetén `null`.
  static Future<Map<String, dynamic>?> _fetchJson(Uri uri) async {
    try {
      final response = await Dio().getUri<Map<String, dynamic>>(uri);
      return response.data;
    } catch (_) {
      return null;
    }
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

  /// A feloldott **tartalom-célpont** (`típus:azonosító`), amit a felület nyit meg.
  ///
  /// Ugyanaz a minta, mint a meghívó-kódnál: a szolgáltatás **eltárolja**, a
  /// felület pedig a saját idejében elviszi (és törli) — így a link akkor is
  /// megnyílik, ha az app épp most indult.
  static const String _pendingContentKey = 'pending_content_link_v1';

  static Future<String?> pendingContentTarget() async {
    await _initialization;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_pendingContentKey);
  }

  static Future<void> clearPendingContentTarget() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingContentKey);
  }
}
