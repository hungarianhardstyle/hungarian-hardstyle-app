import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/prize.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/providers/prize_provider.dart';
import 'package:hungarian_hardstyle_app/services/prize_service.dart';
import 'package:hungarian_hardstyle_app/widgets/prize_entry_card.dart';

const _openPrize = HuhsPrize(
  id: 777,
  state: HuhsPrizeState.open,
  question: 'Melyik évben alakult a HUHS?',
  answers: [
    HuhsPrizeAnswer(index: 0, label: '2015'),
    HuhsPrizeAnswer(index: 1, label: '2018'),
    HuhsPrizeAnswer(index: 2, label: '2021'),
  ],
  prizeType: '',
  prizeDescription: '',
  imageUrl: '',
  winner: null,
);

const _drawnPrize = HuhsPrize(
  id: 778,
  state: HuhsPrizeState.drawn,
  question: 'Melyik évben alakult a HUHS?',
  answers: [],
  prizeType: 'HUHS póló',
  prizeDescription: 'Méret egyeztetés után postázzuk.',
  imageUrl: '',
  winner: HuhsPrizeWinner(name: 'Kiss Péter', drawnAt: '2026-09-20 18:00:00'),
);

/// A kviz-szolgaltatas helyettese. A helyessegrol a "szerver" dont: a fake a
/// beallitott `correctIndex` alapjan valaszol, tehat a teszt ugyanazt a
/// szerzodest hasznalja, mint az eles kod.
class _FakePrizeService extends PrizeService {
  _FakePrizeService({
    this.prize,
    this.played = false,
    this.correctIndex = 1,
    this.statusDelay,
  });

  final HuhsPrize? prize;
  bool played;

  /// A helyes valasz indexe — ezt a "szerver" donti el, nem a kliens.
  final int correctIndex;
  final Duration? statusDelay;

  /// A jatekos eredmenye (a szerver szerint).
  bool correct = false;

  int playCalls = 0;
  int? lastAnswerIndex;

  @override
  Future<HuhsPrize?> activePrize({bool forceRefresh = false}) async => prize;

  @override
  Future<HuhsPrizePlay> playStatus(int prizeId) async {
    if (statusDelay != null) await Future<void>.delayed(statusDelay!);
    return HuhsPrizePlay(played: played, correct: correct);
  }

  @override
  Future<HuhsPrizePlay> play({
    required int prizeId,
    required int answerIndex,
  }) async {
    playCalls += 1;
    lastAnswerIndex = answerIndex;
    // A szerver szabalyai: a masodik jatek nem valtoztat a taron.
    if (played) {
      return HuhsPrizePlay(played: true, correct: correct, answerIndex: null);
    }
    played = true;
    correct = answerIndex == correctIndex;
    return HuhsPrizePlay(
      played: true,
      correct: correct,
      answerIndex: answerIndex,
    );
  }
}

class _FailingStatusPrizeService extends PrizeService {
  _FailingStatusPrizeService({this.prize});

  final HuhsPrize? prize;

  @override
  Future<HuhsPrize?> activePrize({bool forceRefresh = false}) async => prize;

  @override
  Future<HuhsPrizePlay> playStatus(int prizeId) async =>
      throw Exception('network down');
}

class _RegisteredUser extends Fake implements User {
  @override
  bool get isAnonymous => false;

  @override
  String get uid => 'test-uid';
}

Widget _app(PrizeService fake, {bool registered = true}) {
  return ProviderScope(
    overrides: [
      prizeServiceProvider.overrideWithValue(fake),
      communityAuthProvider.overrideWith(
        (ref) =>
            Stream<User?>.value(registered ? _RegisteredUser() : null),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: ListView(children: const [PrizeEntryCard()])),
    ),
  );
}

void main() {
  final entry = find.byKey(const Key('prize-entry'));

  testWidgets('nyitott jateknal megjelenik a sor, a kerdessel', (tester) async {
    await tester.pumpWidget(_app(_FakePrizeService(prize: _openPrize)));
    await tester.pumpAndSettle();

    expect(entry, findsOneWidget);
    expect(find.text('NYEREMÉNYJÁTÉK'), findsOneWidget);
    // A kartya fo szovege Addig csak annyit mond, hogy jatszani lehet: a
    // nyeremeny neve es leirasa a sorsolasig NEM latszik.
    expect(find.textContaining('Játssz és nyerj'), findsOneWidget);
    expect(find.textContaining('HUHS póló'), findsNothing);
  });

  testWidgets('nincs jatek -> nincs sor', (tester) async {
    await tester.pumpWidget(_app(_FakePrizeService(prize: null)));
    await tester.pumpAndSettle();

    expect(entry, findsNothing);
    expect(find.text('NYEREMÉNYJÁTÉK'), findsNothing);
  });

  testWidgets('a sor megnyitja a kviz sajat képernyőjét', (tester) async {
    await tester.pumpWidget(_app(_FakePrizeService(prize: _openPrize)));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Nyereményjáték'), findsOneWidget);
    expect(find.text('2015'), findsOneWidget);
    expect(find.text('2018'), findsOneWidget);
    expect(find.text('2021'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
    expect(find.text('Játszom'), findsOneWidget);
  });

  testWidgets('helyes valasz utan a sorsolas-uzzenet jelenik meg', (
    tester,
  ) async {
    final fake = _FakePrizeService(prize: _openPrize, correctIndex: 1);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2018'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Játszom'));
    await tester.pumpAndSettle();

    expect(fake.playCalls, 1);
    expect(fake.lastAnswerIndex, 1);
    expect(find.textContaining('Helyes válasz!'), findsOneWidget);
    expect(find.text('Játszom'), findsNothing);
  });

  testWidgets('rontas utan nincs ujraproba: a jatek lezarult', (tester) async {
    // A tulajdonosi szabaly: „ha ront, ennyi volt, jatszott, nincs javitas".
    final fake = _FakePrizeService(prize: _openPrize, correctIndex: 1);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2015'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Játszom'));
    await tester.pumpAndSettle();

    expect(find.textContaining('nem ez volt a helyes válasz'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text('Játszom'), findsNothing);
  });

  testWidgets('ha a szerver szerint mar jatszott, nincs valaszlista', (
    tester,
  ) async {
    final fake = _FakePrizeService(prize: _openPrize, played: true);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text('Játszom'), findsNothing);
  });

  testWidgets('a lista meg sem jelenik, amig a szerver valasza uton van', (
    tester,
  ) async {
    final fake = _FakePrizeService(
      prize: _openPrize,
      played: true,
      statusDelay: const Duration(milliseconds: 400),
    );
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byIcon(Icons.radio_button_unchecked),
      findsNothing,
      reason: 'a lista nem villanhat fel, mielott a szerver valaszol',
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
  });

  testWidgets('ha a status hibara fut, a lista NEM jelenik meg', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FailingStatusPrizeService(prize: _openPrize)));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text('Játszom'), findsNothing);
    expect(find.textContaining('nem sikerült lekérdezni'), findsOneWidget);
  });

  testWidgets('vendegnek regisztracios figyelmeztetes van valaszlista helyett', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakePrizeService(prize: _openPrize), registered: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.textContaining('regisztrált fiók szükséges'), findsOneWidget);
    expect(find.text('Játszom'), findsNothing);
  });

  testWidgets('kihirdetett nyertesnel a sor a nyertest mutatja', (tester) async {
    await tester.pumpWidget(_app(_FakePrizeService(prize: _drawnPrize)));
    await tester.pumpAndSettle();

    expect(entry, findsOneWidget);
    expect(find.text('NYERTES'), findsOneWidget);
    expect(find.textContaining('Kiss Péter'), findsOneWidget);
  });
  testWidgets('a nyertes képernyőn a nyeremeny leirasa is latszik', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakePrizeService(prize: _drawnPrize)));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Kiss Péter'), findsOneWidget);
    expect(find.textContaining('HUHS póló'), findsOneWidget);
    expect(find.textContaining('Méret egyeztetés'), findsOneWidget);
    // Lezart jateknal nincs valaszlehetoseg es nincs jatek-gomb.
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text('Játszom'), findsNothing);
  });

  testWidgets('a sor olyan szeles, mint a hero kartya', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const heroKey = Key('hero-card');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
              Container(
                key: heroKey,
                height: 120,
                color: const Color(0xFF1B1E22),
              ),
              const SizedBox(height: 20),
              ProviderScope(
                overrides: [
                  prizeServiceProvider.overrideWithValue(
                    _FakePrizeService(prize: _openPrize),
                  ),
                  communityAuthProvider.overrideWith(
                    (ref) => Stream<User?>.value(_RegisteredUser()),
                  ),
                ],
                child: const PrizeEntryCard(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hero = tester.getRect(find.byKey(heroKey));
    final card = tester.getRect(entry);

    expect(card.left, moreOrLessEquals(hero.left, epsilon: 0.5));
    expect(card.width, moreOrLessEquals(hero.width, epsilon: 0.5));
  });
}
