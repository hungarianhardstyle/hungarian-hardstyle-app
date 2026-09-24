import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/community_provider.dart';

/// Bejelentkezés után **előtölti** a fiókhoz kötött, gyakran használt adatokat.
///
/// A tulajdonos jelzése: *„sok adat lassan tölt be"* — a claim-állapot és a
/// „claimelt DJ-adatlapjaim" lista pedig **első** megnyitáskor még a szerverre
/// vár (mentés híján). Ez a widget a háttérben, a **bejelentkezés után egyszer**
/// melegíti ezeket, ezért a felhasználó már a **mentett** választ látja, amikor
/// tényleg megnyitja az adatlapot vagy a profilját.
///
/// **Szigorú szabályok:**
/// 1. csak **olvasás** — semmit nem módosít és nem küld be;
/// 2. a hibák **elnyelődnek** (az előtöltés sosem akadályozhatja a használatot);
/// 3. fiókonként **egyszer** fut (a UID a kulcs), és legfeljebb [maxArtists]
///    adatlapot melegít, ezért egy sok adatlapot birtokló fiók sem indít
///    hívássorozatot.
/// 4. az előtöltés **a mentést tölti** (a providereken keresztül), ezért a
///    felület ugyanazt kapja, mintha magától töltötte volna be.
class AccountPrefetch extends ConsumerStatefulWidget {
  const AccountPrefetch({super.key, required this.child, this.maxArtists = 5});

  final Widget child;

  /// Ennyi „saját" DJ-adatlapot melegít be (a többi magától tölt).
  final int maxArtists;

  @override
  ConsumerState<AccountPrefetch> createState() => _AccountPrefetchState();
}

class _AccountPrefetchState extends ConsumerState<AccountPrefetch> {
  String? _warmedUid;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    if (uid != null && uid != _warmedUid) {
      _warmedUid = uid;
      // A first frame UTÁN indulunk, hogy az indulás ne lassuljon tőle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_warm(uid));
      });
    }
    return widget.child;
  }

  Future<void> _warm(String uid) async {
    try {
      // 1. A saját claimelt DJ-adatlapjaim (a profil „DJ-adatlap" szekciója).
      final ids = await ref.read(claimedArtistsOfUserProvider(uid).future);
      // 2. Az ezekhez tartozó claim-állapotok (a saját adatlapjaim fejléce).
      for (final id in ids.take(widget.maxArtists)) {
        await ref.read(artistClaimStatusProvider(id).future);
      }
      // 3. A saját profil (a „Profil" képernyő a szolgáltatás memóriabeli
      //    gyorsítótárából azonnal rajzol, amint az adat megvan).
      await ref.read(communityServiceProvider).getPublicProfile(uid);
    } catch (_) {
      // Best-effort: a képernyők maguktól is betöltenek, csak lassabban.
    }
  }
}
