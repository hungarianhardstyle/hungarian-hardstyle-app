import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_notification.dart';
import 'notification_service.dart';

/// Az **app-ikon jelvényének** karbantartása: az olvasatlan értesítések száma.
///
/// A tulajdonos kérése: *„Az app ikon jelezze mennyi notifyd meg pushod van,
/// olvasatlan, egybe számolva"*.
///
/// MIÉRT EZ A SZÁM: az app értesítés-listája (`notifications`) az a hely, ahová
/// **minden** saját értesítés bekerül — a push-sal járó értesítések is (a
/// szerver ugyanabban a tranzakcióban írja a listát és küldi a push-t). Ezért az
/// **olvasatlan** bejegyzések száma pontosan a „notify + push egybe számolva"
/// érték. (A WordPress-plugin által küldött hír-push is bekerül ide, mert a
/// tartalom-figyelő ugyanarra a listára ír.)
///
/// NÉGY SZÁNDÉKOS SZABÁLY:
///  1. **Csak változáskor** hívjuk a jelvény-API-t (a stream minden képnél
///     elsülne, az pedig fölösleges launcher-hívás lenne);
///  2. **0-nál is** frissítünk (ez tünteti el a jelvényt) — nem hagyjuk ott a
///     régi számot;
///  3. egy **hiba nem állítja meg** a figyelést, és nem dob a felületre: a
///     jelvény nem kritikus funkció;
///  4. a launcher, amelyik nem támogatja a számot (pl. a stock Android),
///     egyszerűen nem mutatja — ez nem hiba, ezért nem is jelezzük a usernek.
class AppBadgeSync {
  AppBadgeSync({
    NotificationService? notifications,
    Future<void> Function(int count)? setBadge,
    bool autoStart = true,
  }) : _injected = notifications,
       _setBadge = setBadge ?? AppBadgePlus.updateBadge {
    if (autoStart) start();
  }

  final NotificationService? _injected;
  final Future<void> Function(int count) _setBadge;

  StreamSubscription<List<AppNotification>>? _subscription;
  int? _lastApplied;
  bool _disposed = false;

  /// Az utoljára kiküldött jelvényszám (teszthez és diagnosztikához).
  int? get lastApplied => _lastApplied;

  void start() {
    if (_subscription != null) return;
    // Firebase nélkül (pl. widget-teszt) nincs értesítés, és a
    // `NotificationService` létrehozása **dobna** — ezért előbb megállunk.
    // Ugyanaz a minta, mint az `achievementRankSyncProvider`-nél.
    if (_injected == null && Firebase.apps.isEmpty) return;
    final notifications = _injected ?? NotificationService();
    _subscription = notifications
        .watchNotifications(limit: 100)
        .listen(_apply, onError: (_) {
          // Hálózati/olvasási hiba: a jelvény marad, amilyen volt.
        });
  }

  Future<void> _apply(List<AppNotification> items) async {
    final unread = items
        .where((item) => !item.isRead && !item.isArchived)
        .length;
    if (_disposed || unread == _lastApplied) return;
    _lastApplied = unread;
    try {
      await _setBadge(unread);
    } catch (_) {
      // A jelvény nem kritikus: a hiba nem juthat el a felhasználóig.
    }
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
  }
}
