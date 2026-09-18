import '../core/firebase/firebase_callable.dart';
import '../models/poll.dart';
import 'wordpress_service.dart';

/// Kozvelemenykutatas - Kerdőív szolgaltatas.
///
/// A szavazast a `pollVote` Firebase callable rögzíti, mert csak az tudja
/// hitelesen megmondani, ki a bejelentkezett felhasznalo. A callable a Firebase
/// UID-t **nem** adja tovább tarbolasként: a WordPress csak egy sotolt
/// ujjlenyomatot kap, így nev, e-mail és UID nelkul is kiszurheto a duplikacio.
class PollService {
  PollService({WordpressService? wordpress})
    : _wordpress = wordpress ?? WordpressService();

  final WordpressService _wordpress;

  /// A nyitott kerdőív, vagy null. A szerver csak nyitott kerdőívet ad vissza.
  ///
  /// `bypassCache: true` eseten a mentett valasz nem dont: a kerdőív
  /// megnyilasa/zarasa időponthoz kotott, ezert a cache nem rejtheti el.
  Future<HuhsPoll?> activePoll({
    bool forceRefresh = false,
    bool bypassCache = false,
  }) async {
    final payload = await _wordpress.getActivePoll(
      forceRefresh: forceRefresh,
      bypassCache: bypassCache,
    );
    return HuhsPoll.fromJson(payload);
  }

  /// Igaz, ha ez a fiok mar szavazott ebben a kerdőívben.
  Future<bool> hasVoted(int pollId) async {
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'pollVote',
      parameters: <String, dynamic>{'pollId': pollId},
    );
    return result.data['voted'] == true;
  }

  /// Szavazat rogzitese. Visszaadja, hogy ez a fiok mar korabban szavazott-e.
  ///
  /// A szerver oldali egyediseg az igazi vedelem; ez a visszajelzes csak a
  /// feluletnek kell.
  Future<bool> vote({required int pollId, required int optionIndex}) async {
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'pollVote',
      parameters: <String, dynamic>{
        'pollId': pollId,
        'optionIndex': optionIndex,
      },
    );
    return result.data['alreadyVoted'] == true;
  }
}
