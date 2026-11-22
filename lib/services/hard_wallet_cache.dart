import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hard_wallet_plan.dart';

/// A HARD-tárca utolsó ismert állapota fiókonként, hogy a tárca-oldal és a menü
/// azonnal mutasson valamit, amíg a szerver (hideg indításnál ~2 s) válaszol.
/// Csak megjelenítési gyorsítótár: a döntést mindig a szerver adja.
class HardWalletStatusCache {
  const HardWalletStatusCache._();

  static String _key(String uid) => 'hard_wallet_status_$uid';

  static Future<HardWalletStatus?> read(String uid) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key(uid));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? HardWalletStatus.fromMap(decoded.cast<Object?, Object?>())
          : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String uid, HardWalletStatus status) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key(uid),
        jsonEncode(status.toMap()),
      );
    } catch (_) {}
  }
}
