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
/// a felhasznalo visszater az appba (lasd `PollCard`).
final activePollProvider = FutureProvider<HuhsPoll?>((ref) async {
  return ref.watch(pollServiceProvider).activePoll(forceRefresh: true);
});
