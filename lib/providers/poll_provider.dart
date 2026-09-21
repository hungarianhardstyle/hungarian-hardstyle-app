import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poll.dart';
import '../services/poll_service.dart';
import '../services/vote_memory.dart';
import 'community_provider.dart';
import 'news_provider.dart';

final pollServiceProvider = Provider<PollService>((ref) => PollService());

/// A nyitott kerdőív. Null, ha épp nincs (a szerver csak nyitott kerdőívet ad).
///
/// **A MEGJELENÍTÉSI ÚT.** A mentett választ azonnal kiszolgálja, és csak a
/// háttérben egyeztet a WordPress-szel (`WordpressHeadCache`), ezért a főoldali
/// sor nem vár 0,4–2,0 másodpercet (mérve), és nem marad üresen a betöltés
/// alatt. A `publicContentRefreshProvider` figyelése azért kell, hogy a
/// háttérben beérkező **friss** válasz (nyitás/zárás, kihirdetett nyertes)
/// magától megjelenjen a kártyán — hálózati várakozás nélkül, mert ekkor már a
/// friss test van a gyorsítótárban.
///
/// A **kifejezett** frissítés (lehúzás, frissítés ikon, app-visszatérés) útja
/// [activePollRefreshProvider]: az továbbra is megkerüli a mentett választ,
/// mert a kérdoív nyitása/zárása időponthoz kötött.
final activePollProvider = FutureProvider<HuhsPoll?>((ref) async {
  ref.watch(publicContentRefreshProvider);
  return ref.watch(pollServiceProvider).activePoll();
});

/// A kérdoív **kifejezett** frissítésének útja: a mentett válasz nem dönthet.
///
/// A két út szándékosan külön kérdés: a megjelenítésnek az a dolga, hogy
/// **azonnal** legyen mit rajzolni, a frissítésnek pedig az, hogy a lehető
/// legpontosabb állapotot adja. A `forceRefresh` (HEAD + ETag) erre nem elég: a
/// WordPress cache-elt válasza ugyanazt az ETag-ot adja vissza, ezért a kliens a
/// REGI testet szolgálta ki — a frissen kihirdetett nyertes csak tíz perccel
/// később jelent meg. Ezért itt `bypassCache` kell.
///
/// A friss válasz a közös gyorsítótárba kerül, ezért a megjelenítési út utána
/// (a provider újraszámolásával) **hálózat nélkül** a helyes állapotot rajzolja.
final activePollRefreshProvider = FutureProvider<HuhsPoll?>((ref) async {
  final poll = await ref
      .watch(pollServiceProvider)
      .activePoll(bypassCache: true);
  ref.invalidate(activePollProvider);
  return poll;
});

/// Igaz, ha ez a bejelentkezett fiok mar szavazott a megadott kerdőívben.
///
/// **Providerban van, nem a widget allapotaban.** A korabbi kartya egy
/// `Future`-t tartott a `State`-ben, ezert a valasz a kepenny megnyilasaig
/// élt: ha a felhasznalo a kepenny nyitasa ELOTT szavazott (a weblapon), az
/// app meg a regi „mar szavaztal" allapotot mutatta, és nem engedett
/// szavazni. Providerként a valasz ugyanazokra az esemenyekre frissul, mint
/// maga a kerdőív (lefele huzas, frissites ikon, app visszateres, a képernyő
/// megnyitasa), ezert nem tud beragadni.
///
/// **A tulajdonos jelzése:** *„Kérdőívnél elsőre picit sokára tölti be, hogy már
/// kitöltöttem"*. A válasz csak egy három lépcsős út végén derül ki
/// (app → Cloud Function → WordPress), ezért a **legutóbbi ismert állapotot a
/// telefon megjegyzi** (`VoteMemory`): ha eszerint már szavaztál, az **azonnal**
/// látszik, és a szerver válaszát a háttérben ellenőrizzük. Ha a szerver azt
/// mondja, mégsem szavaztál, a jelzést töröljük és a felület visszavált a
/// szavazólapra — így soha nem marad el egy szavazat.
///
/// A szavazat vegso egyedisege tovabbra is a szerveren van (a WordPress
/// `add_post_meta(..., true)` egyedi sora), ezert egy elavult „nem szavaztal"
/// valasz sem ad masodik érvényes szavazatot: a szerver `alreadyVoted`-del
/// valaszol.
final hasVotedProvider = FutureProvider.family<bool, int>((ref, pollId) async {
  if (pollId < 1) return false;
  final uid = ref.watch(currentUidProvider);
  // A háttérellenőrzés a képernyő bezárása UTÁN is befejeződhet; ilyenkor nem
  // szabad újraszámolni (a provider „loading" állapotban szűnne meg, ami hibát
  // dob a lezárásnál).
  var disposed = false;
  ref.onDispose(() => disposed = true);
  if (await VoteMemory.isPollVoted(uid, pollId)) {
    // Azonnal a „már szavaztál" állapot, és közben ellenőrizzük a szervert.
    unawaited(_revalidateVoted(ref, pollId, uid, () => disposed));
    return true;
  }
  final voted = await ref.watch(pollServiceProvider).hasVoted(pollId);
  if (voted) await VoteMemory.markPollVoted(uid, pollId);
  return voted;
});

/// A háttérellenőrzés: ha a szerver szerint mégsem szavaztál, a mentett jelzést
/// töröljük és a providert újraszámoljuk (ekkor jön a szavazólap).
Future<void> _revalidateVoted(
  Ref ref,
  int pollId,
  String? uid,
  bool Function() isDisposed,
) async {
  try {
    final voted = await ref.read(pollServiceProvider).hasVoted(pollId);
    if (voted) return;
    await VoteMemory.clearPollVoted(uid, pollId);
    if (isDisposed()) return;
    ref.invalidateSelf();
  } catch (_) {
    // Hálózati hiba: a mentett állapot marad, a következő megnyitás újrapróbálja.
  }
}
