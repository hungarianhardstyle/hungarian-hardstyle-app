import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prize.dart';
import '../services/prize_service.dart';

final prizeServiceProvider = Provider<PrizeService>((ref) => PrizeService());

/// A nyitott nyeremenyjatek vagy a frissen kihirdetett nyertes. Null, ha nincs.
///
/// Szandekosan **cache-kikerüléssel** kerdődik le, pontosan úgy, mint a
/// kerdőív: a jatek megnyilasa, zarasa es a sorsolas időponthoz kotott, ezert
/// egy mentett valasz (peldaul egy korabbi `null`) nem dönthet arrol, latszik-e
/// a kartya. A vegpont kicsi, a szerver pedig maga is cache-eli.
///
/// **`bypassCache`, nem `forceRefresh`:** az utobbi HEAD + ETag egyeztetessel
/// dönt, a WordPress cache-elt valasza viszont ugyanazt az ETag-ot adja vissza,
/// ezert a kliens a REGI testet szolgalta ki — pontosan ezert jelent meg a
/// kihirdetett nyertes csak tiz perccel kesobb a kártyán.
final activePrizeProvider = FutureProvider<HuhsPrize?>((ref) async {
  return ref.watch(prizeServiceProvider).activePrize(bypassCache: true);
});

/// Ez a bejelentkezett fiok jatszott-e mar ebben a jatekban.
///
/// Providerban van (nem a widget allapotaban), ezert minden képernyő-megnyitas,
/// frissites es jatek utan ujra a szerverhez megy — így nem tud beragadni a
/// „nem jatszottal" valasz. A jatekszabaly szerint egy fiok egyszer jatszik.
final prizePlayProvider = FutureProvider.family<HuhsPrizePlay, int>((
  ref,
  prizeId,
) async {
  if (prizeId < 1) {
    return const HuhsPrizePlay(played: false, correct: false);
  }
  return ref.watch(prizeServiceProvider).playStatus(prizeId);
});
