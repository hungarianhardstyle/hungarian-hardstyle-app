import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/models/prize.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/providers/prize_provider.dart';
import 'package:hungarian_hardstyle_app/services/prize_service.dart';
import 'package:hungarian_hardstyle_app/services/vote_memory.dart';
/// A nyeremenyjatek PROVIDEREI: a jatek es a sajat jatszott-allapot a
/// szerverrol jon.
///
/// **Ket kulon ut:** a **megjelenitesi** ut (`activePrizeProvider`) a mentett
/// valaszt adja azonnal (a WordPress mérve 0,4–2,0 s), a **kifejezett
/// frissites** utja (`activePrizeRefreshProvider`) viszont megkeruli a cache-t,
/// mert a jatek nyitasa, zarasa es a sorsolas időponthoz kotott — pontosan ezt
/// a hibat kellett a kerdőívnél egyszer javítani.
class _FakePrizeService extends PrizeService {
  _FakePrizeService({
    this.prize,
    this.status = const HuhsPrizePlay(played: false, correct: false),
  });

  HuhsPrize? prize;
  HuhsPrizePlay status;
  int activeCalls = 0;
  int statusCalls = 0;
  int playCalls = 0;
  bool? lastForceRefresh;

  /// A **kifejezett frissítés** útjának `bypassCache: true`-val KELL kérdeznie:
  /// a `forceRefresh` (HEAD + ETag) élesben a régi testet adta vissza.
  bool? lastBypassCache;
  int? lastPrizeId;

  /// Ha be van állítva, a státusz-kérés **nem fejeződik be**, amíg ezt meg nem
  /// oldjuk. Ezzel mérhető, hogy a felület nem VÁR a szerverre.
  Completer<HuhsPrizePlay>? statusGate;

  @override
  Future<HuhsPrize?> activePrize({
    bool forceRefresh = false,
    bool bypassCache = false,
  }) async {
    activeCalls += 1;
    lastForceRefresh = forceRefresh;
    lastBypassCache = bypassCache;
    return prize;
  }

  @override
  Future<HuhsPrizePlay> playStatus(int prizeId) async {
    statusCalls += 1;
    lastPrizeId = prizeId;
    final gate = statusGate;
    if (gate != null) return gate.future;
    return status;
  }

  @override
  Future<HuhsPrizePlay> play({
    required int prizeId,
    required int answerIndex,
  }) async {
    playCalls += 1;
    return status;
  }
}

ProviderContainer _container(PrizeService service, {String? uid = 'teszt-uid'}) {
  final container = ProviderContainer(
    overrides: [
      prizeServiceProvider.overrideWithValue(service),
      // A „már játszottam" helyi emlékezet kulcsához kell a UID. Szűk provider,
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
    // A VoteMemory statikus (memóriabeli) tükre nem szivároghat át a
    // következő tesztbe — a mockolt SharedPreferences igen, ezért mindkettőt
    // nullázni kell.
    VoteMemory.resetForTests();
    SharedPreferences.setMockInitialValues({});
  });

  /// Néhány mikrotask-fordulat: a háttérellenőrzés befejezéséhez.
  Future<void> pumpMicrotasks([int turns = 20]) async {
    for (var i = 0; i < turns; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// A mentett játékeredményt ugyanúgy írjuk, ahogy az app is teszi.
  Future<void> seedPlayed(
    String uid,
    int prizeId, {
    bool correct = false,
    int? answerIndex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'huhs.played.prize.$uid.$prizeId',
      '{"played":true,"correct":$correct,"answerIndex":$answerIndex}',
    );
  }

  group('activePrizeProvider', () {
    test('a MEGJELENITESI ut a mentett valaszt adja (nem var a halozatra)', () async {
      // A WordPress-végpontok mérve 0,4–2,0 s alatt válaszolnak, ezért a
      // főoldali sor a mentett válaszból rajzol azonnal, és csak a háttérben
      // egyeztet. A `bypassCache` itt hiba lenne: megkerülné a mentett rekordot.
      final service = _FakePrizeService(prize: _openPrize);
      final container = _container(service);

      final prize = await container.read(activePrizeProvider.future);

      expect(prize?.id, 777);
      expect(service.activeCalls, 1);
      expect(service.lastBypassCache, isFalse);
      expect(service.lastForceRefresh, isFalse);
    });

    test('a KIFEJEZETT frissites MEGKERULI a cache-t (a sorsolas azonnal latszik)', () async {
      // A játék nyitása, zárása és a sorsolás időponthoz kötött, ezért a
      // frissítés útján a mentett válasz **nem** dönthet. A `forceRefresh` erre
      // nem elég: HEAD + ETag egyeztetéssel dolgozik, a WordPress cache-elt
      // válasza pedig ugyanazt az ETag-ot adja vissza — élesben ezért jelent meg
      // a kihirdetett nyertes csak tíz perccel később.
      final service = _FakePrizeService(prize: _openPrize);
      final container = _container(service);
      await container.read(activePrizeProvider.future);

      // Közben lezárul a játék, és kihirdetik a nyertest.
      service.prize = _drawnPrize;
      final refreshed = await container.read(activePrizeRefreshProvider.future);

      expect(service.lastBypassCache, isTrue);
      expect(refreshed?.winner?.name, 'Kiss Péter');
      // A friss válasz a közös gyorsítótárba került: a megjelenítési út utána
      // már a nyertest rajzolja, hálózati várakozás nélkül.
      expect(
        (await container.read(activePrizeProvider.future))?.winner?.name,
        'Kiss Péter',
      );
    });

    test('ha nincs jatek, null jon vissza', () async {
      final container = _container(_FakePrizeService(prize: null));
      expect(await container.read(activePrizeProvider.future), isNull);
    });

    test('frissites utan ujra a szerverhez fordul', () async {
      final service = _FakePrizeService(prize: _openPrize);
      final container = _container(service);
      await container.read(activePrizeProvider.future);

      // Kozben lezarul a jatek, es kihirdetik a nyertest.
      service.prize = _drawnPrize;
      container.invalidate(activePrizeProvider);

      final prize = await container.read(activePrizeProvider.future);

      expect(service.activeCalls, 2);
      expect(prize?.winner?.name, 'Kiss Péter');
    });
  });

  group('prizePlayProvider', () {
    test('a jatszott-allapot a szerverrol jon', () async {
      final service = _FakePrizeService(
        prize: _openPrize,
        status: const HuhsPrizePlay(played: true, correct: true, answerIndex: 1),
      );
      final container = _container(service);

      final play = await container.read(prizePlayProvider(777).future);

      expect(play.played, isTrue);
      expect(play.correct, isTrue);
      expect(service.lastPrizeId, 777);
    });

    test('a jatek utan ujra lekérdez (nem ragad be a regi valasz)', () async {
      // ⚠️ A cache-kör óta a szerződés kétszeres: az **első** válasz a mentett
      // állapotból jön (ezért nincs várakozás), a **háttérellenőrzés** viszont
      // lefut, és a mentést a friss szerver-válaszra cseréli — a KÖVETKEZŐ
      // olvasás már a helyes állapotot adja.
      final service = _FakePrizeService(prize: _openPrize);
      final container = _container(service);
      expect((await container.read(prizePlayProvider(777).future)).played, isFalse);
      expect(service.statusCalls, 1);

      // A jatekos kozben jatszott (mondjuk masik keszuleken):
      service.status = const HuhsPrizePlay(played: true, correct: false);
      container.invalidate(prizePlayProvider(777));

      final stale = await container.read(prizePlayProvider(777).future);
      expect(
        stale.played,
        isFalse,
        reason: 'a mentett válaszból azonnal rajzol — nem vár a hálózatra',
      );

      await pumpMicrotasks();
      final fresh = await container.read(prizePlayProvider(777).future);

      expect(fresh.played, isTrue, reason: 'a háttérellenőrzés frissítette');
      expect(fresh.correct, isFalse);
      expect(service.statusCalls, greaterThanOrEqualTo(2));
    });

    test('ervenytelen azonosito nem indit halozati kereset', () async {
      final service = _FakePrizeService(prize: _openPrize);
      final container = _container(service);

      final play = await container.read(prizePlayProvider(0).future);

      expect(play.played, isFalse);
      expect(service.statusCalls, 0);
    });

    /* -------------------------------------------------------------- */
    /* Azonnali „már játszottam" állapot (a tulajdonos jelzése)       */
    /* -------------------------------------------------------------- */

    test(
      'mentett eredménynél a válasz AZONNAL jön, a szerver megkérdezése nélkül',
      () async {
        // A tulajdonos jelzése: *„Kvíznél elsőre kicsit sokára tölti be, hogy már
        // játszottam"*. A bizonyítás: a szerver kérése **soha nem fejeződik be**
        // (statusGate), a provider mégis azonnal válaszol.
        await seedPlayed('teszt-uid', 777, correct: true, answerIndex: 1);
        final service = _FakePrizeService(prize: _openPrize)
          ..statusGate = Completer<HuhsPrizePlay>();
        final container = _container(service);

        final play = await container
            .read(prizePlayProvider(777).future)
            .timeout(const Duration(seconds: 2));

        expect(play.played, isTrue);
        expect(
          play.correct,
          isTrue,
          reason: 'a mentett ítélet is megmarad, nem csak a „játszott" tény',
        );
        expect(play.answerIndex, 1);
      },
    );

    test('a mentett eredmény csak a SAJÁT fiókra érvényes', () async {
      await seedPlayed('mas-felhasznalo', 777, correct: true);
      final service = _FakePrizeService(prize: _openPrize);

      final play = await _container(
        service,
        uid: 'teszt-uid',
      ).read(prizePlayProvider(777).future);

      expect(play.played, isFalse);
      expect(service.statusCalls, 1);
    });

    test('a háttérellenőrzés a szerver válaszát írja be, ha az eltér', () async {
      // A mentett állapot **szerver-válasz**, ezért a háttérellenőrzés nem
      // törli, hanem a friss válaszra cseréli: így a KÖVETKEZŐ megnyitás is
      // azonnali lesz (ez a kör lényege: a nyereményjáték ne várjon a hálózatra).
      await seedPlayed('teszt-uid', 777, correct: true, answerIndex: 1);
      final service = _FakePrizeService(prize: _openPrize);
      final container = _container(service);

      expect((await container.read(prizePlayProvider(777).future)).played, isTrue);

      final prefs = await SharedPreferences.getInstance();
      for (var i = 0; i < 20; i++) {
        final stored = prefs.getString('huhs.played.prize.teszt-uid.777');
        if (stored != null && stored.contains('"played":false')) break;
        await Future<void>.delayed(Duration.zero);
      }
      expect(service.statusCalls, 1);
      expect(
        prefs.getString('huhs.played.prize.teszt-uid.777'),
        contains('"played":false'),
        reason: 'a friss szerver-válasz kerül a mentésbe, nem törlés',
      );

      container.invalidate(prizePlayProvider(777));
      expect((await container.read(prizePlayProvider(777).future)).played, isFalse);
    });

    /* -------------------------------------------------------------- */
    /* „100 év mire betölt" — a nyereményjáték azonnali nyitása        */
    /* -------------------------------------------------------------- */

    test(
      'mentett „még nem játszottál" válasznál is AZONNAL jön a válasz',
      () async {
        // A tulajdonos jelzése a most futó nyereményjátékra: *„100 év mire
        // betölt"*. A mért ok: a válaszlehetőségek csak a szerver válasza után
        // jelenhettek meg, a szerver-körút pedig hidegen másodperceket jelent.
        // A bizonyítás ugyanaz, mint a „már játszottam" esetben: a szerver
        // kérése **soha nem fejeződik be**, a provider mégis azonnal válaszol.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'huhs.played.prize.teszt-uid.777',
          '{"played":false,"correct":false,"answerIndex":null}',
        );
        final service = _FakePrizeService(prize: _openPrize)
          ..statusGate = Completer<HuhsPrizePlay>();
        final container = _container(service);

        final play = await container
            .read(prizePlayProvider(777).future)
            .timeout(const Duration(seconds: 2));

        expect(play.played, isFalse, reason: 'játszhat — jöhetnek a válaszok');
        expect(
          service.statusCalls,
          1,
          reason: 'a háttérellenőrzés elindult, de NEM blokkol',
        );
      },
    );

    test('mentett „nem játszott", de a szerver szerint már játszott: frissül', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'huhs.played.prize.teszt-uid.777',
        '{"played":false,"correct":false,"answerIndex":null}',
      );
      final service = _FakePrizeService(
        prize: _openPrize,
        status: const HuhsPrizePlay(played: true, correct: true, answerIndex: 2),
      );
      final container = _container(service);

      expect((await container.read(prizePlayProvider(777).future)).played, isFalse);

      // A háttérellenőrzés lefut, és eltérést talál.
      for (var i = 0; i < 10 && service.statusCalls == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(
        prefs.getString('huhs.played.prize.teszt-uid.777'),
        contains('"played":true'),
        reason: 'a szerver az erősebb forrás',
      );
    });
  });

  group('HuhsPrize.fromJson', () {
    test('a nyitott jatekot ertelmezi', () {
      final prize = HuhsPrize.fromJson(const {
        'id': 5,
        'state': 'open',
        'question': 'Kerdes?',
        'answers': [
          {'index': 0, 'label': 'A'},
          {'index': 1, 'label': 'B'},
        ],
        'prize_type': '',
        'prize_description': '',
        'image': '',
        'winner': null,
      });
      expect(prize?.isOpen, isTrue);
      expect(prize?.answers.length, 2);
    });

    test('a nyitott jatek a helyes valaszt NEM ismeri (nincs is a valaszban)', () {
      final prize = HuhsPrize.fromJson(const {
        'id': 5,
        'state': 'open',
        'question': 'Kerdes?',
        'answers': [
          {'index': 0, 'label': 'A'},
          {'index': 1, 'label': 'B'},
        ],
      });
      expect(prize?.answers.any((a) => a.label.contains('helyes')), isFalse);
    });

    test('a kihirdetett nyertest ertelmezi, valaszok nelkul', () {
      final prize = HuhsPrize.fromJson(const {
        'id': 5,
        'state': 'drawn',
        'question': 'Kerdes?',
        'answers': [],
        'prize_type': 'Póló',
        'prize_description': 'Leiras',
        'winner': {'name': 'Nagy Anna', 'drawn_at': '2026-09-20 18:00:00'},
      });
      expect(prize?.isOpen, isFalse);
      expect(prize?.winner?.name, 'Nagy Anna');
      expect(prize?.prizeType, 'Póló');
      expect(prize?.answers, isEmpty);
    });

    test('ismeretlen allapotot nem ertelmez', () {
      expect(HuhsPrize.fromJson(const {'id': 5, 'state': 'valami'}), isNull);
    });

    test('kevesebb mint ket valaszlehetoseggel nincs nyitott jatek', () {
      expect(
        HuhsPrize.fromJson(const {
          'id': 5,
          'state': 'open',
          'question': 'Kerdes?',
          'answers': [
            {'index': 0, 'label': 'A'},
          ],
        }),
        isNull,
      );
    });

    test('nyertes nelkul nincs kihirdetett allapot', () {
      expect(
        HuhsPrize.fromJson(const {'id': 5, 'state': 'drawn', 'question': 'K?'}),
        isNull,
      );
    });
  });
}

const _openPrize = HuhsPrize(
  id: 777,
  state: HuhsPrizeState.open,
  question: 'Melyik évben alakult a HUHS?',
  answers: [
    HuhsPrizeAnswer(index: 0, label: '2015'),
    HuhsPrizeAnswer(index: 1, label: '2018'),
  ],
  prizeType: '',
  prizeDescription: '',
  winner: null,
);

const _drawnPrize = HuhsPrize(
  id: 778,
  state: HuhsPrizeState.drawn,
  question: 'Melyik évben alakult a HUHS?',
  answers: [],
  prizeType: 'HUHS póló',
  prizeDescription: '',
  winner: HuhsPrizeWinner(name: 'Kiss Péter', drawnAt: '2026-09-20 18:00:00'),
);
