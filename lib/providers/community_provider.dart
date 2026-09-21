import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_post.dart';
import '../models/artist_claim_status.dart';
import '../services/community_service.dart';

final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService();
});

final communityAuthProvider = StreamProvider<User?>((ref) {
  return ref.watch(communityServiceProvider).auth.userChanges();
});

/// Az éppen bejelentkezett (nem névtelen) fiók UID-ja, vagy null.
///
/// **Szűk provider, és ez szándékos:** a helyi emlékezet kulcsa (`VoteMemory`)
/// ezt használja, és így tesztben Firebase nélkül felülírható. A „már
/// szavaztál / már játszottál" állapot azonnali kijelzéséhez kell, mert a
/// mentett jelzés csak a **saját** fiókra érvényes.
final currentUidProvider = Provider<String?>((ref) {
  final user = ref.watch(communityAuthProvider).valueOrNull;
  if (user == null || user.isAnonymous) return null;
  return user.uid;
});

final communityPostsProvider = StreamProvider<List<CommunityPost>>((ref) {
  return ref.watch(communityServiceProvider).watchPosts();
});

/// A DJ-adatlap claim-állapota: foglalt-e, az enyém-e, és claimelhetem-e.
///
/// A tulajdonos kérése: *„a claim akkor jelenjen CSAK meg ha valamelyik email
/// cím egyezik (booking vagy privát)"* — ezt a **szerver** dönti el
/// (`functions/artist-claim-plan.js`), mert a privát cím nem kerülhet a kliensre.
final artistClaimStatusProvider = FutureProvider.family<ArtistClaimStatus, int>((
  ref,
  artistId,
) {
  return ref.watch(communityServiceProvider).artistClaimStatus(artistId);
});

/// Igaz, ha a bejelentkezett fiok admin (a WordPress-admin vegpontokhoz).
///
/// **Miért provider es miert olvassa a profilt:** a `CommunityService.isAdmin`
/// egy szolgaltatas-peldany belso cache-ebol dolgozik, ami csak akkor tolt, ha
/// a profilkepernyo (vagy a `refreshCurrentSession`) mar lefutott. Egy frissen
/// megnyitott kepernyon ez a cache meg ures, es akkor az admin jogosultsagat
/// NEM latja — pontosan ez volt a hibajelzes: „nekem adminként nincs ott".
/// Ez a provider a `community_profiles/<uid>.accessRole` mezot figyeli, ezert
/// a szerepkor ott van, amint a dokumentum megvan, cache-feltoltestol
/// fuggetlenul.
///
/// A tulajdonos e-mail-cime ebbol a szempontbol kivetel: azt a szerver is
/// adminnak tekinti, akkor is, ha a profil `accessRole` mezoje meg nem allt be.
/// Ezert az e-mail-egyezes is beleszamit.
final currentUserIsAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(communityAuthProvider).valueOrNull;
  if (user == null || user.isAnonymous) return false;
  if (CommunityService.isOwnerEmail(user.email)) return true;
  final snapshot = await ref
      .watch(communityServiceProvider)
      .firestore
      .collection('community_profiles')
      .doc(user.uid)
      .get();
  return snapshot.data()?['accessRole'] == CommunityService.accessAdmin;
});
