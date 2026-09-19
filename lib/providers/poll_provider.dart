import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poll.dart';
import '../services/poll_service.dart';
import '../services/vote_memory.dart';
import 'community_provider.dart';

final pollServiceProvider = Provider<PollService>((ref) => PollService());

/// A nyitott kerdőív. Null, ha épp nincs (a szerver csak nyitott kerdőívet ad).
///
/// Szandekosan **cache-kikerüléssel** kerdődik le: a kerdőív megnyilasa és
/// zarasa időponthoz kotott, ezert egy mentett valasz (peldaul egy korabbi
/// `null`) nem dönthet arról, latszik-e a kartya. A vegpont kicsi (~250 bajt),
/// a szerver pedig maga is 45 masodpercig cache-eli, tehat ez olcso.
///
/// **`bypassCache`, nem `forceRefresh`:** az utobbi HEAD + ETag egyeztetessel
/// dönt, a WordPress cache-elt valasza viszont ugyanazt az ETag-ot adja vissza,
/// ezert a kliens a REGI testet szolgalta ki — emiatt jelent meg egy frissen
/// kihirdetett nyertes csak tiz perccel kesobb. A `bypassCache` egyenesen
/// megkerüli a mentett rekordot.
///
/// Ezen felul a kartya ujrakerdez, amikor a főoldalt frissitik, illetve amikor
/// a felhasznalo visszater az appba (lasd `PollEntryButton`).
final activePollProvider = FutureProvider<HuhsPoll?>((ref) async {
  return ref.watch(pollServiceProvider).activePoll(bypassCache: true);
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
