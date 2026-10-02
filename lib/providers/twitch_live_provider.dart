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

/// A kártya **tulajdonosi felülírása** — kép és felirat **build nélkül**.
///
/// A kérés: *„legyen hozza cserelhető kép, képes kártya jelenjen meg a
/// fooldalon”*. Ezért a kártya a Firestore-ból olvassa a felülírást
/// (`app_settings/twitch`):
///
/// ```json
/// { "enabled": true, "imageUrl": "https://…/plakat.jpg", "headerText": "Élőben a stúdióból" }
/// ```
///
/// Ha nincs ilyen dokumentum (vagy üres), a kártya a Twitch **mozgó**
/// előnézetét használja — így mindig van kép, és a tulajdonos bármikor
/// kicserélheti anélkül, hogy új build kellene.
class TwitchCardOverride {
  const TwitchCardOverride({
    this.enabled = true,
    this.imageUrl = '',
    this.headerText = '',
  });

  final bool enabled;
  final String imageUrl;
  final String headerText;

  bool get hasImage => imageUrl.trim().isNotEmpty;
}

final twitchCardOverrideProvider =
    FutureProvider.autoDispose<TwitchCardOverride>((ref) async {
  try {
    if (Firebase.apps.isEmpty) return const TwitchCardOverride();
    final firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'hungarian-hardstyle',
    );
    final snapshot = await firestore.collection('app_settings').doc('twitch').get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    return TwitchCardOverride(
      enabled: data['enabled'] as bool? ?? true,
      imageUrl: (data['imageUrl'] as String? ?? '').trim(),
      headerText: (data['headerText'] as String? ?? '').trim(),
    );
  } catch (_) {
    // Firebase nélkül (teszt, telepítés előtt) a kártya alap-viselkedése marad.
    return const TwitchCardOverride();
  }
});
