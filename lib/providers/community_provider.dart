import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_post.dart';
import '../models/artist_claim_status.dart';
import '../services/async_cache_store.dart';
import '../services/community_service.dart';
import 'cache_provider.dart';

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
///
/// **⚠️ CACHE-FIRST + HÁTTÉRFRISSÍTÉS (a tulajdonos jelzése, 2026-09-24):**
/// *„sok adat lassan tölt be, pl az hogy a dj adatlap az »enyém«"*. A döntés
/// eddig **minden** adatlap-megnyitásnál egy callable körút volt (boot + a
/// szerveroldali privát e-mail-ellenőrzés: mérve ~1,4 s), ezért az „ez az enyém /
/// átvehető" sor másfél-két másodpercig **nem** látszott. Mostantól a **mentett
/// válasz azonnal kimegy**, a szerver pedig a háttérben egyeztet — és csak akkor
/// rajzolunk újra, ha a döntés **tényleg változott**.
///
/// A mentési kulcs a **UID-ot is tartalmazza**: más fiók bejelentkezése nem
/// örökölheti az előző fiók claim-állapotát.
final artistClaimStatusProvider =
    FutureProvider.family<ArtistClaimStatus, int>((ref, artistId) async {
      // Fiókváltásnál újraszámol (a kulcsban is benne van a UID).
      ref.watch(currentUidProvider);
      final uid = ref.read(currentUidProvider);
      var disposed = false;
      ref.onDispose(() => disposed = true);
      return readThroughCache<ArtistClaimStatus>(
        cacheKey: artistClaimCacheKey(uid, artistId),
        store: ref.read(asyncCacheStoreProvider),
        fetch: () =>
            ref.read(communityServiceProvider).artistClaimStatus(artistId),
        encode: (value) => value.toJson(),
        decode: (payload) => ArtistClaimStatus.fromJson(
          payload is Map ? Map<String, dynamic>.from(payload) : null,
        ),
        refresh: () {
          if (!disposed) ref.invalidateSelf();
        },
        isCancelled: () => disposed,
        ttl: const Duration(minutes: 10),
      );
    });

/// A claim-állapot mentési kulcsa (a **fiók** is benne van, lásd fent).
String artistClaimCacheKey(String? uid, int artistId) {
  final user = (uid ?? '').trim();
  return 'huhs.cache.artistClaim.${user.isEmpty ? 'guest' : user}.$artistId.v1';
}

/// A más felhasználók **claimelt DJ-adatlapjai** (a nyilvános profil szekciója).
///
/// ⚠️ Ez eddig egy `FutureBuilder` volt: minden profil-megnyitásnál **új**
/// callable körút, a szekció pedig csak a válasz után jelent meg. Mostantól
/// cache-first: a kártyák azonnal ott vannak, a szerver a háttérben egyeztet.
final claimedArtistsOfUserProvider = FutureProvider.family<List<int>, String>((
  ref,
  userId,
) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  return readThroughCache<List<int>>(
    cacheKey: claimedArtistsCacheKey(userId),
    store: ref.read(asyncCacheStoreProvider),
    fetch: () =>
        ref.read(communityServiceProvider).claimedArtistsOfUser(userId),
    encode: (value) => value,
    decode: (payload) => payload is List
        ? payload.whereType<num>().map((id) => id.toInt()).toList()
        : const <int>[],
    refresh: () {
      if (!disposed) ref.invalidateSelf();
    },
    isCancelled: () => disposed,
    ttl: const Duration(minutes: 10),
  );
});

/// A claimelt DJ-adatlapok mentési kulcsa (a **profil** UID-ja szerint).
String claimedArtistsCacheKey(String userId) =>
    'huhs.cache.claimedArtists.${userId.trim()}.v1';

/// Az imént végrehajtott **átvétel / átvétel-visszavonás** azonnali megjegyzése.
///
/// **MIÉRT KELL:** a `ref.invalidate(...)` önmagában a **mentett** választ
/// olvasná vissza, ezért a sor egy pillanatra a **régi** állapotot mutatná. Ha a
/// mentést előbb a **tudott új** állapotra írjuk, az újrarajzolás rögtön helyes,
/// a szerver pedig a háttérben megerősíti (és ha kell, javítja).
Future<void> rememberArtistClaimStatus({
  required String? uid,
  required int artistId,
  required ArtistClaimStatus status,
  AsyncCacheStore? store,
}) async {
  final cache = store ?? AsyncCacheStore.shared;
  await cache.write(artistClaimCacheKey(uid, artistId), status.toJson());
  // A „claimelt DJ-adatlapjaim" lista is megváltozott: a mentését eldobjuk.
  final user = (uid ?? '').trim();
  if (user.isNotEmpty) await cache.remove(claimedArtistsCacheKey(user));
}

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
