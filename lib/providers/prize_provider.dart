import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prize.dart';
import '../services/prize_service.dart';
import '../services/vote_memory.dart';
import 'community_provider.dart';
import 'news_provider.dart';

final prizeServiceProvider = Provider<PrizeService>((ref) => PrizeService());

/// A nyitott nyeremenyjatek vagy a frissen kihirdetett nyertes. Null, ha nincs.
///
/// **A MEGJELENÍTÉSI ÚT**, pontosan úgy, mint a kérdoívnél: a mentett választ
/// azonnal kiszolgálja, és csak a háttérben egyeztet a WordPress-szel — a
/// főoldali sor így nem vár 0,4–2,0 másodpercet (mérve). A
/// `publicContentRefreshProvider` figyelése azért kell, hogy a sorsolás után
/// kihirdetett nyertes **magától** megjelenjen a kártyán, hálózati várakozás
/// nélkül.
///
/// A **kifejezett** frissítés útja [activePrizeRefreshProvider]: az továbbra is
/// megkerüli a mentett választ, mert a játék nyitása, zárása és a sorsolás
/// időponthoz kötött.
final activePrizeProvider = FutureProvider<HuhsPrize?>((ref) async {
  ref.watch(publicContentRefreshProvider);
  return ref.watch(prizeServiceProvider).activePrize();
});

/// A nyeremenyjatek **kifejezett** frissítésének útja: a mentett válasz nem
/// dönthet.
///
/// **`bypassCache`, nem `forceRefresh`:** az utóbbi HEAD + ETag egyeztetéssel
/// dönt, a WordPress cache-elt válasza viszont ugyanazt az ETag-ot adja vissza,
/// ezért a kliens a REGI testet szolgálta ki — pontosan ezért jelent meg a
/// kihirdetett nyertes csak tíz perccel később a kártyán. A friss válasz a közös
/// gyorsítótárba kerül, ezért a megjelenítési út utána hálózat nélkül a helyes
/// állapotot rajzolja.
final activePrizeRefreshProvider = FutureProvider<HuhsPrize?>((ref) async {
  final prize = await ref
      .watch(prizeServiceProvider)
      .activePrize(bypassCache: true);
  ref.invalidate(activePrizeProvider);
  return prize;
});

/// Ez a bejelentkezett fiok jatszott-e mar ebben a jatekban.
///
/// Providerban van (nem a widget allapotaban), ezert minden képernyő-megnyitas,
/// frissites es jatek utan ujra a szerverhez megy — így nem tud beragadni a
/// „nem jatszottal" valasz. A jatekszabaly szerint egy fiok egyszer jatszik.
///
/// **A tulajdonos jelzése:** *„Kvíznél elsőre kicsit sokára tölti be, hogy már
/// játszottam"*, majd később a nyereményjáték képernyőjére: *„100 év mire
/// betölt"*. A válasz három lépcsős út végén derül ki (app → Cloud Function →
/// WordPress), ezért a **legutóbbi ismert szerver-választ a telefon megjegyzi**
/// (`VoteMemory`) — **akkor is, ha az „még nem játszottál"**. A képernyő így
/// azonnal rajzol, a szerver válaszát pedig a háttérben ellenőrizzük; ha
/// eltér, a jelzés frissül és a felület átvált.
///
/// ⚠️ A mentett állapot **soha nem tipp**: kizárólag a `prizeVote` válasza
/// kerülhet bele, ezért a válaszlehetőségek megjelenítése továbbra sem
/// feltételezésen, hanem egy valódi szerver-válaszon alapul (legfeljebb
/// régebbin).
final prizePlayProvider = FutureProvider.family<HuhsPrizePlay, int>((
  ref,
  prizeId,
) async {
  if (prizeId < 1) {
    return const HuhsPrizePlay(played: false, correct: false);
  }
  final uid = ref.watch(currentUidProvider);
  // A háttérellenőrzés a képernyő bezárása UTÁN is befejeződhet; ilyenkor nem
  // szabad újraszámolni (a provider „loading" állapotban szűnne meg, ami hibát
  // dob a lezárásnál).
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final remembered = await VoteMemory.prizePlay(uid, prizeId);
  if (remembered != null) {
    unawaited(_revalidatePlay(ref, prizeId, uid, () => disposed, remembered));
    return remembered;
  }
  final play = await ref.watch(prizeServiceProvider).playStatus(prizeId);
  await VoteMemory.markPrizeChecked(uid, prizeId, play);
  return play;
});

/// A háttérellenőrzés: ha a szerver válasza **bármiben** eltér a mentettől
/// (játszott ↔ nem játszott, helyes ↔ nem, más választott index), akkor a
/// mentett állapot frissül, és a provider újraszámol — a felület így a helyes
/// állapotra vált.
Future<void> _revalidatePlay(
  Ref ref,
  int prizeId,
  String? uid,
  bool Function() isDisposed,
  HuhsPrizePlay remembered,
) async {
  try {
    final play = await ref.read(prizeServiceProvider).playStatus(prizeId);
    final same = play.played == remembered.played &&
        play.correct == remembered.correct &&
        play.answerIndex == remembered.answerIndex;
    if (same) return;
    await VoteMemory.markPrizeChecked(uid, prizeId, play);
    if (isDisposed()) return;
    ref.invalidateSelf();
  } catch (_) {
    // Hálózati hiba: a mentett állapot marad, a következő megnyitás újrapróbálja.
  }
}
