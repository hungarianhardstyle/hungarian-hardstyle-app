import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poll.dart';
import '../services/poll_service.dart';

final pollServiceProvider = Provider<PollService>((ref) => PollService());

/// A nyitott kerdőív. Null, ha épp nincs (a szerver csak nyitott kerdőívet ad).
///
/// Szandekosan **cache-kikerüléssel** kerdődik le: a kerdőív megnyilasa és
/// zarasa időponthoz kotott, ezert egy mentett valasz (peldaul egy korabbi
/// `null`) nem dönthet arról, latszik-e a kartya. A vegpont kicsi (~250 bajt),
/// a szerver pedig maga is 45 masodpercig cache-eli, tehat ez olcso.
///
/// Ezen felul a kartya ujrakerdez, amikor a főoldalt frissitik, illetve amikor
/// a felhasznalo visszater az appba (lasd `PollEntryButton`).
final activePollProvider = FutureProvider<HuhsPoll?>((ref) async {
  return ref.watch(pollServiceProvider).activePoll(forceRefresh: true);
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
/// A szavazat vegso egyedisege tovabbra is a szerveren van (a WordPress
/// `add_post_meta(..., true)` egyedi sora), ezert egy elavult „nem szavaztal"
/// valasz sem ad masodik érvényes szavazatot: a szerver `alreadyVoted`-del
/// valaszol.
final hasVotedProvider = FutureProvider.family<bool, int>((ref, pollId) async {
  if (pollId < 1) return false;
  return ref.watch(pollServiceProvider).hasVoted(pollId);
});
