import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/twitch_live.dart';

/// Az élő Twitch-állapot a főoldali kártyához.
///
/// ⚠️ MIÉRT 3 PERC: a kártya csak akkor jelenik meg, ha **megy** a stream; a
/// Twitch-oldali nézés 3 percen belül nem változik érdemben, viszont egy sűrűbb
/// kör felesleges hálózat és akkumulátor lenne. (A stream indulásáról szóló
/// **push** külön, szerveroldali kör — az nem erre vár.)
final twitchLiveProvider = FutureProvider.autoDispose<TwitchLiveStatus>((ref) async {
  ref.keepAlive();
  final timer = Timer.periodic(const Duration(minutes: 3), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return fetchTwitchLive();
});

/// A kártya **tulajdonosi beállítása** — a WordPress-adminból, build nélkül.
///
/// A kérés: *„legyen hozza cserelhető kép, képes kártya jelenjen meg a
/// fooldalon”*. A beállítás a plugin adminjában él (HUHS Mobile → Twitch
/// beharangozó), és a **nyilvános végpontján** keresztül érkezik:
///
/// ```json
/// { "enabled": true, "imageUrl": "https://…/plakat.jpg", "headerText": "Élőben a stúdióból",
///   "showWhenOffline": true }
/// ```
///
/// Ha a végpont nem érhető el, a **Firestore-beli másolat** jön (ezt a
/// szerveroldali figyelő kör szinkronizálja) — így egy átmeneti hiba nem viszi
/// el a beállítást.
///
/// ⚠️ MIÉRT FRISSÜL 3 PERCENKÉNT (mért hiba, 2026-10-02): a tulajdonos
/// beállította a képet a plugin adminjában, és *„egyáltalán nem látta az iPhone
/// appban”*. Az ok **app-oldali** volt: a beállítást csak egyszer, a képernyő
/// betöltésekor olvastuk, frissítés nélkül — egy nyitva lévő app így soha nem
/// vette észre a változást. Mostantól ugyanaz a 3 perces kör frissíti, mint az
/// élő állapotot.
///
/// ⚠️ **ÉLŐ ADÁS NÉLKÜL:** a kártya alapból csak akkor látszik, ha megy a
/// stream — a tulajdonos viszont **kifejezetten kérheti** (`showWhenOffline`),
/// hogy a saját képével akkor is ott legyen. Ehhez **kép is kell**, különben nem
/// lenne mit mutatni. A döntés egy helyen, tisztán él: `twitchCardVisible(...)`
/// a `services/twitch_live.dart`-ban.
final twitchCardOverrideProvider = FutureProvider.autoDispose<TwitchCardConfig>((ref) async {
  ref.keepAlive();
  final timer = Timer.periodic(const Duration(minutes: 3), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return fetchTwitchCardConfig(firestoreLoader: loadTwitchCardFromFirestore);
});

/// A Firestore-beli másolat (a szerveroldali szinkron írja) — **tartalék út**.
///
/// `null`, ha nincs Firebase (teszt, telepítés előtt) vagy nem olvasható:
/// ilyenkor a hívó a plugin értékénél marad, illetve az alapértékre esik vissza.
Future<TwitchCardConfig?> loadTwitchCardFromFirestore() async {
  try {
    if (Firebase.apps.isEmpty) return null;
    final firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'hungarian-hardstyle',
    );
    final snapshot = await firestore.collection('app_settings').doc('twitch').get();
    if (!snapshot.exists) return null;
    return parseTwitchCardConfig(snapshot.data());
  } catch (error) {
    // ⚠️ Nem nyeljük el némán: a hívó a plugin értékével folytatja, és a napló
    // megmondja, hogy a tartalék út sem élt.
    debugPrintTwitchCardFallbackFailed(error);
    return null;
  }
}
