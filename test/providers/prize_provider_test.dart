import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/prize.dart';
import 'package:hungarian_hardstyle_app/providers/prize_provider.dart';
import 'package:hungarian_hardstyle_app/services/prize_service.dart';
/// A nyeremenyjatek PROVIDEREI: a jatek es a sajat jatszott-allapot a
/// szerverrol jon, es minden lekerdezes megkeruli a cache-t.
///
/// A jatek nyitasa, zarasa es a sorsolas időponthoz kotott, ezert egy mentett
/// valasz (peldaul egy korabbi `null`) nem dönthet arrol, latszik-e a kartya —
/// pontosan ezt a hibat kellett a kerdőívnél egyszer javítani.
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
  int? lastPrizeId;

  @override
  Future<HuhsPrize?> activePrize({bool forceRefresh = false}) async {
    activeCalls += 1;
    lastForceRefresh = forceRefresh;
    return prize;
  }

  @override
  Future<HuhsPrizePlay> playStatus(int prizeId) async {
    statusCalls += 1;
    lastPrizeId = prizeId;
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

ProviderContainer _container(PrizeService service) {
  final container = ProviderContainer(
    overrides: [prizeServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('activePrizeProvider', () {
    test('a nyitott jatekot a szerverrol keri le, cache-kikerulessel', () async {
      final service = _FakePrizeService(prize: _openPrize);
      final container = _container(service);

      final prize = await container.read(activePrizeProvider.future);

      expect(prize?.id, 777);
      expect(service.activeCalls, 1);
      expect(
        service.lastForceRefresh,
        isTrue,
        reason: 'a jatek nyitasa/zarasa időponthoz kotott, a cache nem dönthet',
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
      final service = _FakePrizeService(prize: _openPrize);
      final container = _container(service);
      await container.read(prizePlayProvider(777).future);
      expect(service.statusCalls, 1);

      // A jatekos kozben jatszott (mondjuk a sorsolas idejen mar jatszott):
      service.status = const HuhsPrizePlay(played: true, correct: false);
      container.invalidate(prizePlayProvider(777));

      final play = await container.read(prizePlayProvider(777).future);

      expect(service.statusCalls, 2);
      expect(play.played, isTrue);
      expect(play.correct, isFalse);
    });

    test('ervenytelen azonosito nem indit halozati kereset', () async {
      final service = _FakePrizeService(prize: _openPrize);
      final container = _container(service);

      final play = await container.read(prizePlayProvider(0).future);

      expect(play.played, isFalse);
      expect(service.statusCalls, 0);
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
