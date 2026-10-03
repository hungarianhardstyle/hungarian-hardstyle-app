// ÉLES láncmérés — az APP SAJÁT kódjával, a VALÓDI WordPress-végpont ellen.
//
// Miért él itt: a fájl neve szándékosan NEM `_test.dart`, ezért a szokásos
// `flutter test` kör (és így a CI) nem futtatja — ez a mérés hálózatfüggő,
// kézzel indítjuk:
//
//   flutter test test/live/twitch_card_live_check.dart
//
// Ez a fájl nem újraírja a logikát: pontosan azt hívja, amit az app hív.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/twitch_live.dart';

void main() {
  test('az app a valódi végpontról kapja a Twitch-kártya beállítását', () async {
    final cfg = await fetchTwitchCardFromWordPress();
    expect(cfg, isNotNull, reason: 'a végpont válaszoljon (HTTP 200 + JSON)');
    // ignore: avoid_print
    print('BEÁLLÍTÁS: enabled=${cfg!.enabled} showWhenOffline=${cfg.showWhenOffline} '
        'hasImage=${cfg.hasImage} image="${cfg.imageUrl}" header="${cfg.headerText}"');
    expect(cfg.enabled, isTrue, reason: 'a kártya engedélyezve legyen');
    expect(cfg.hasImage, isTrue, reason: 'legyen kép');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('nem élő adásnál is látszana a kártya', () async {
    final cfg = await fetchTwitchCardFromWordPress();
    final visible = twitchCardVisible(
      isLive: false,
      enabled: cfg?.enabled ?? true,
      showWhenOffline: cfg?.showWhenOffline ?? false,
      hasImage: cfg?.hasImage ?? false,
    );
    // ignore: avoid_print
    print('LÁTHATÓSÁG (nem élő adás): $visible');
    expect(visible, isTrue, reason: 'a beállítás szerint látszania kell');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a kártya képe letölthető az app HTTP-kliensével', () async {
    final cfg = await fetchTwitchCardFromWordPress();
    final url = cfg?.imageUrl;
    expect(url, isNotNull);
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url!));
      req.headers.set(HttpHeaders.userAgentHeader, 'Dart/3.13 (dart:io)');
      final res = await req.close();
      final bytes = await res.fold<int>(0, (sum, chunk) => sum + chunk.length);
      // ignore: avoid_print
      print('KÉP: HTTP ${res.statusCode} ${res.headers.contentType} $bytes bájt');
      expect(res.statusCode, 200);
      expect(bytes, greaterThan(1000));
    } finally {
      client.close(force: true);
    }
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('élő adásnál a MOZGÓ streamkép menne a kártyára (a beharangozó helyett)', () async {
    // A tulajdonos kérése (2026-10-03): *„ha elindul egy twitch stream, akkor a
    // beharangozó kép helyett mehetne a stream mozgóképe a főoldalon”*. Ez a kör
    // az **éles** Twitch-állapotot kérdezi le az app saját kódjával, és a
    // kártyára kerülő URL-t is kiírja — így akkor is mérhető, ha épp nem megy
    // adás (ilyenkor a beharangozó kép a helyes válasz).
    final cfg = await fetchTwitchCardFromWordPress();
    final live = await fetchTwitchLive();
    final url = twitchCardImageUrl(
      isLive: live.isLive,
      liveThumbnailUrl: live.thumbnailUrl,
      overrideImageUrl: cfg?.displayImageUrl ?? '',
      tick: 7,
    );
    // ignore: avoid_print
    print('ÉLŐ: isLive=${live.isLive} viewers=${live.viewers} title="${live.title}"');
    // ignore: avoid_print
    print('KÁRTYA-KÉP: $url');
    if (live.isLive) {
      expect(url, contains('previews-ttv'),
          reason: 'élő adásnál a mozgó előnézet kell');
      expect(url, contains('tick=7'), reason: 'frissítő paraméter nélkül befagyna');
    } else {
      // Adás nélkül a beállított beharangozó kép (vagy üres, ha nincs kép) — a
      // Twitch mozgó előnézete ilyenkor **nem** kerülhet a kártyára.
      expect(url.contains('previews-ttv'), isFalse,
          reason: 'adás nélkül nem a mozgó előnézet megy a kártyára');
      expect(url, cfg?.displayImageUrl ?? '',
          reason: 'adás nélkül pont a beállított kép kell');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
