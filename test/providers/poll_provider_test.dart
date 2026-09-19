import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/models/poll.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/providers/poll_provider.dart';
import 'package:hungarian_hardstyle_app/services/poll_service.dart';

/// Szamlalo szolgaltatas: nem megy a halozatra, de rögzíti, mit kértek tőle.
class _FakePollService extends PollService {
  _FakePollService(this.poll, {this.voted = false});

  final HuhsPoll? poll;
  int calls = 0;
  bool? lastForceRefresh;

  /// A kartyanak `bypassCache: true`-val KELL kérdeznie. A `forceRefresh`
  /// (HEAD + ETag) élesben a régi testet adta vissza, ezért a frissen
  /// kihirdetett nyertes csak tíz perccel később jelent meg.
  bool? lastBypassCache;

  /// A szerver valasza a „szavaztal mar?" keredesre.
  bool voted;
  int statusCalls = 0;
  int voteCalls = 0;

  /// Ha be van állítva, a státusz-kérés **nem fejeződik be**, amíg ezt meg nem
  /// oldjuk. Ezzel mérhető, hogy a felület nem VÁR a szerverre.
  Completer<bool>? statusGate;

  @override
  Future<HuhsPoll?> activePoll({
    bool forceRefresh = false,
    bool bypassCache = false,
  }) async {
    calls += 1;
    lastForceRefresh = forceRefresh;
    lastBypassCache = bypassCache;
    return poll;
  }

  @override
  Future<bool> hasVoted(int pollId) async {
    statusCalls += 1;
    final gate = statusGate;
    if (gate != null) return gate.future;
    return voted;
  }

  @override
  Future<bool> vote({required int pollId, required int optionIndex}) async {
    voteCalls += 1;
    final already = voted;
    voted = true;
    return already;
  }
}

const _poll = HuhsPoll(
  id: 12694,
  question: 'Tetszik az Applikació?',
  options: [
    HuhsPollOption(index: 0, label: 'Igen'),
    HuhsPollOption(index: 1, label: 'Nem'),
  ],
);

ProviderContainer _containerWith(_FakePollService fake, {String? uid = 'teszt-uid'}) {
  final container = ProviderContainer(
    overrides: [
      pollServiceProvider.overrideWithValue(fake),
      // A „már szavaztál" helyi emlékezet kulcsához kell a UID. Szűk provider,
      // ezért Firebase nélkül felülírható.
      currentUidProvider.overrideWithValue(uid),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('a nyitott kerdőívet a szolgaltatastol keri le', () async {
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    final value = await container.read(activePollProvider.future);

    expect(value?.id, 12694);
    expect(value?.question, 'Tetszik az Applikació?');
    expect(fake.calls, 1);
  });

  test('a lekerdezes MEGKERULI a cache-t', () async {
    // Ez a lényeg: a kerdőív megnyilasa/zarasa időponthoz kotott, ezert egy
    // mentett valasz (peldaul egy korabbi `null`) nem dönthet a kartyarol.
    //
    // **`bypassCache`, nem `forceRefresh`.** Az utobbi HEAD + ETag
    // egyeztetessel dönt, a WordPress cache-elt valasza viszont ugyanazt az
    // ETag-ot adja vissza — ezért élesben a régi testet szolgálta ki, és a
    // frissen kihirdetett nyertes csak tíz perccel később jelent meg.
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    await container.read(activePollProvider.future);

    expect(fake.lastBypassCache, isTrue);
  });

  test('frissites utan ujra lekerdez (nyitas/zaras követhető)', () async {
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    await container.read(activePollProvider.future);
    container.invalidate(activePollProvider);
    await container.read(activePollProvider.future);

    expect(fake.calls, 2);
  });

  test('zarult kerdőívnel (null) nincs megjelenitendo adat', () async {
    final fake = _FakePollService(null);
    final container = _containerWith(fake);

    expect(await container.read(activePollProvider.future), isNull);
  });

  test('a szavazott allapot a szerverrol jon, nem a widget allapotabol', () async {
    final fake = _FakePollService(_poll, voted: true);
    final container = _containerWith(fake);

    expect(await container.read(hasVotedProvider(12694).future), isTrue);
    expect(fake.statusCalls, 1);
  });

  test('ujranyitas utan a szavazott allapot UJRA lekerdezodik', () async {
    // A tulajdonos esete: a weblapon szavazott, az app viszont a regi
    // „nem szavaztal" valaszt mutatta, ezert meg egyszer engedett szavazni.
    // A valasz ezert providerben van, ami a képernyő megnyitasakor kerdez.
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    expect(await container.read(hasVotedProvider(12694).future), isFalse);

    // Kozben a weblapon (vagy egy korabbi munkamenetben) megszuletik a szavazat.
    fake.voted = true;
    container.invalidate(hasVotedProvider(12694));

    expect(await container.read(hasVotedProvider(12694).future), isTrue);
    expect(fake.statusCalls, 2);
  });

  test('szavazas utan a szavazott allapot frissul', () async {
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    expect(await container.read(hasVotedProvider(12694).future), isFalse);

    final alreadyVoted = await container
        .read(pollServiceProvider)
        .vote(pollId: 12694, optionIndex: 1);
    expect(alreadyVoted, isFalse);
    container.invalidate(hasVotedProvider(12694));

    expect(await container.read(hasVotedProvider(12694).future), isTrue);
    expect(fake.voteCalls, 1);
  });

  test('a masodik szavazas a szerver jelzeset adja vissza', () async {
    // A vegso vedelem a szerveren van (WordPress `add_post_meta(..., true)`),
    // ezert a masodik proba `alreadyVoted`-del ter vissza, nem szavaz újra.
    final fake = _FakePollService(_poll, voted: true);
    final container = _containerWith(fake);

    final alreadyVoted = await container
        .read(pollServiceProvider)
        .vote(pollId: 12694, optionIndex: 0);

    expect(alreadyVoted, isTrue);
    expect(fake.voteCalls, 1);
  });

  test('ervenytelen kerdőív-azonosito nem indit halozati kerest', () async {
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    expect(await container.read(hasVotedProvider(0).future), isFalse);
    expect(fake.statusCalls, 0);
  });

  /* ---------------------------------------------------------------- */
  /* Azonnali „már szavaztál" állapot (a tulajdonos jelzése)          */
  /* ---------------------------------------------------------------- */

  /// A mentett jelzést ugyanúgy írjuk, ahogy az app is teszi.
  Future<void> seedVoted(String uid, int pollId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('huhs.voted.poll.$uid.$pollId', true);
  }

  test(
    'mentett szavazatnál a válasz AZONNAL jön, a szerver megkérdezése nélkül',
    () async {
      // A tulajdonos jelzése: *„Kérdőívnél elsőre picit sokára tölti be, hogy már
      // kitöltöttem"*. A válasz három lépcsős úton derül ki (app → Cloud Function
      // → WordPress), ezért a legutóbbi ismert állapot a telefonról jön.
      //
      // A bizonyítás: a szerver kérése **soha nem fejeződik be** (statusGate),
      // a provider mégis azonnal válaszol. Ha a mentett jelzés nem működne, ez a
      // teszt örökre elakadna (a timeout buktatja).
      await seedVoted('teszt-uid', 12694);
      final fake = _FakePollService(_poll, voted: true)
        ..statusGate = Completer<bool>();
      final container = _containerWith(fake);

      final value = await container
          .read(hasVotedProvider(12694).future)
          .timeout(const Duration(seconds: 2));

      expect(value, isTrue);
      expect(
        fake.statusCalls,
        lessThanOrEqualTo(1),
        reason: 'a háttérellenőrzés legfeljebb egyszer indul',
      );
    },
  );

  test('a mentett jelzés csak a SAJÁT fiókra érvényes', () async {
    await seedVoted('mas-felhasznalo', 12694);
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake, uid: 'teszt-uid');

    expect(await container.read(hasVotedProvider(12694).future), isFalse);
    expect(fake.statusCalls, 1, reason: 'más fiók jelzése nem használható fel');
  });

  test('a háttérellenőrzés törli a mentett jelzést, ha a szerver nem szavazott', () async {
    // Ha a szerver szerint mégsem szavazott, a jelzés nem maradhat meg: egy
    // elavult „már szavaztál" elrejtené a szavazólapot.
    await seedVoted('teszt-uid', 12694);
    final fake = _FakePollService(_poll, voted: false);
    final container = _containerWith(fake);

    expect(await container.read(hasVotedProvider(12694).future), isTrue);

    // A háttérellenőrzés lefut és megkérdezi a szervert.
    for (var i = 0; i < 10 && fake.statusCalls == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(fake.statusCalls, 1, reason: 'a háttérellenőrzés megkérdezi a szervert');

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('huhs.voted.poll.teszt-uid.12694'),
      isNull,
      reason: 'a téves mentett jelzést törölni kell',
    );

    // Újraszámolás után a szavazólap jön (nem „már szavaztál").
    container.invalidate(hasVotedProvider(12694));
    expect(await container.read(hasVotedProvider(12694).future), isFalse);
  });

  test('vendég (UID nélkül) nem használ mentett jelzést', () async {
    await seedVoted('teszt-uid', 12694);
    final fake = _FakePollService(_poll, voted: false);
    final container = _containerWith(fake, uid: null);

    expect(await container.read(hasVotedProvider(12694).future), isFalse);
    expect(fake.statusCalls, 1);
  });
}
