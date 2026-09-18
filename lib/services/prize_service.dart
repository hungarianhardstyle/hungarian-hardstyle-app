import '../core/firebase/firebase_callable.dart';
import '../models/prize.dart';
import 'wordpress_service.dart';

/// Nyeremenyjatek — szolgaltatas.
///
/// A jatekot a `prizeVote` Firebase callable rögzíti, mert csak az tudja
/// hitelesen megmondani, ki a bejelentkezett felhasznalo. A WordPress csak egy
/// sotolt ujjlenyomatot tart nyilvan a jatekosrol (nev nelkul is kiszurheto a
/// duplikacio), es **soha** nem tarol e-mail-cimet: a nyertes cimet a sorsolas
/// uten a Firebase Auth-bol kerdezi le a szerver.
///
/// A helyes valaszt a kliens nem ismeri: a jatekos csak a valasztott indexet
/// kuldheti el, a helyessegrol a szerver dönt.
class PrizeService {
  PrizeService({WordpressService? wordpress})
    : _wordpress = wordpress ?? WordpressService();

  final WordpressService _wordpress;

  /// A nyitott jatek vagy a frissen kihirdetett nyertes, egyebkent null.
  ///
  /// `bypassCache: true` eseten a mentett valasz nem dont: a jatek nyitasa,
  /// zarasa es a sorsolas időponthoz kotott, ezert a cache nem rejtheti el.
  ///
  /// **Ezt a jelzot a `forceRefresh` nem tudja helyettesiteni.** Az csak HEAD +
  /// ETag egyeztetessel dolgozik, a WordPress cache-elt valasza viszont ugyanazt
  /// az ETag-ot adja vissza — ezert egy kihirdetett nyertes tiz percig nem
  /// jelent meg a kártyán, hiaba volt meg a szerveren.
  Future<HuhsPrize?> activePrize({
    bool forceRefresh = false,
    bool bypassCache = false,
  }) async {
    final payload = await _wordpress.getActivePrize(
      forceRefresh: forceRefresh,
      bypassCache: bypassCache,
    );
    return HuhsPrize.fromJson(payload);
  }

  /// Ez a fiok jatszott-e mar, es helyes volt-e a valasza.
  Future<HuhsPrizePlay> playStatus(int prizeId) async {
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'prizeVote',
      parameters: <String, dynamic>{'prizeId': prizeId},
    );
    return HuhsPrizePlay.fromJson(result.data);
  }

  /// Egy valasz rogzitese. A helyessegrol a SZERVER dönt.
  ///
  /// Ha a fiok mar jatszott, a szerver nem valtoztat a taron: visszaadja a
  /// korabbi eredmenyt (`alreadyPlayed`), tehat rontas utan nincs javitas.
  Future<HuhsPrizePlay> play({
    required int prizeId,
    required int answerIndex,
  }) async {
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'prizeVote',
      parameters: <String, dynamic>{
        'prizeId': prizeId,
        'answerIndex': answerIndex,
      },
    );
    return HuhsPrizePlay.fromEntryResult(result.data);
  }
}
