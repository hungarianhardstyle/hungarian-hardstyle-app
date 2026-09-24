import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/models/poll.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/providers/poll_provider.dart';
import 'package:hungarian_hardstyle_app/services/poll_service.dart';
import 'package:hungarian_hardstyle_app/services/vote_memory.dart';
import 'package:hungarian_hardstyle_app/widgets/poll_entry_button.dart';

const _poll = HuhsPoll(
  id: 12694,
  question: 'Tetszik az Applikáció?',
  options: [
    HuhsPollOption(index: 0, label: 'Igen'),
    HuhsPollOption(index: 1, label: 'Nem'),
  ],
);

class _FakePollService extends PollService {
  _FakePollService({this.poll, this.voted = false, this.statusDelay});

  final HuhsPoll? poll;
  bool voted;
  int voteCalls = 0;
  int? lastOptionIndex;

  /// Ha be van allitva, a „szavaztal mar?" valasz ennyit var, hogy a betoltes
  /// kozbeni allapot is tesztelheto legyen.
  final Duration? statusDelay;

  @override
  Future<HuhsPoll?> activePoll({
    bool forceRefresh = false,
    bool bypassCache = false,
  }) async {
    lastBypassCache = bypassCache;
    return poll;
  }

  /// A kartyanak `bypassCache: true`-val KELL kérdeznie (a `forceRefresh` a
  /// WordPress cache-elt ETag-ja miatt a régi testet adta vissza).
  bool? lastBypassCache;

  @override
  Future<bool> hasVoted(int pollId) async {
    if (statusDelay != null) await Future<void>.delayed(statusDelay!);
    return voted;
  }

  @override
  Future<bool> vote({required int pollId, required int optionIndex}) async {
    voteCalls += 1;
    lastOptionIndex = optionIndex;
    final already = voted;
    voted = true;
    return already;
  }
}

/// A „szavaztal mar?" lekerdezes halozati hibaja.
class _FailingStatusPollService extends PollService {
  _FailingStatusPollService({this.poll});

  final HuhsPoll? poll;

  @override
  Future<HuhsPoll?> activePoll({
    bool forceRefresh = false,
    bool bypassCache = false,
  }) async => poll;

  @override
  Future<bool> hasVoted(int pollId) async => throw Exception('network down');
}

/// Regisztralt (nem nevvtelen) fiok, Firebase inicializalas nelkul.
class _RegisteredUser extends Fake implements User {
  @override
  bool get isAnonymous => false;

  @override
  String get uid => 'test-uid';
}

/// A tulajdonos fiokja: az e-mail-cim alapjan admin.
class _AdminUser extends _RegisteredUser {
  @override
  String? get email => 'djdeeroy@gmail.com';
}

Widget _app(PollService fake, {bool registered = true, bool admin = false}) {
  return ProviderScope(
    overrides: [
      pollServiceProvider.overrideWithValue(fake),
      // Az admin-jogosultsagot a kepernyo a sajat providerbol olvassa, ezert a
      // teszt ezt allitja be (nem kell hozza Firestore).
      currentUserIsAdminProvider.overrideWith((ref) async => admin),
      communityAuthProvider.overrideWith(
        (ref) => Stream<User?>.value(
          registered ? (admin ? _AdminUser() : _RegisteredUser()) : null,
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: ListView(children: const [PollEntryButton()])),
    ),
  );
}

void main() {
  final entry = find.byKey(const Key('poll-entry'));

  setUp(() {
    // A „már szavaztál" állapot helyi emlékezete (VoteMemory) SharedPreferences-t
    // használ. Mock nélkül a plugin-hívás nem fejeződik be a teszt-környezetben,
    // ezért a képernyő „töltés" állapotban maradna (pumpAndSettle timeout).
    TestWidgetsFlutterBinding.ensureInitialized();
    // A statikus (memóriabeli) tükör sem szivároghat át a következő tesztbe.
    VoteMemory.resetForTests();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('nyitott kerdőívnel megjelenik a kerdőív sor, a kerdessel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_FakePollService(poll: _poll)));
    await tester.pumpAndSettle();

    expect(entry, findsOneWidget);
    expect(find.text('KÉRDŐÍV'), findsOneWidget);
    expect(find.textContaining('Tetszik az Applikáció?'), findsOneWidget);
  });

  testWidgets('a kerdőív sor olyan szeles, mint a hero kartya', (tester) async {
    // A tulajdonos kérése: a sor a főoldali tartalom TELJES szelességet
    // kitöltse, pontosan úgy, ahogy a felette levo hero kartya.
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
                  pollServiceProvider.overrideWithValue(
                    _FakePollService(poll: _poll),
                  ),
                  communityAuthProvider.overrideWith(
                    (ref) => Stream<User?>.value(_RegisteredUser()),
                  ),
                ],
                child: const PollEntryButton(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hero = tester.getRect(find.byKey(heroKey));
    final pollCard = tester.getRect(entry);

    expect(pollCard.left, moreOrLessEquals(hero.left, epsilon: 0.5));
    expect(pollCard.width, moreOrLessEquals(hero.width, epsilon: 0.5));
  });

  testWidgets('nincs nyitott kerdőív -> nincs sor', (tester) async {
    await tester.pumpWidget(_app(_FakePollService(poll: null)));
    await tester.pumpAndSettle();

    expect(entry, findsNothing);
    expect(find.text('KÉRDŐÍV'), findsNothing);
  });

  testWidgets('a sor megnyitja a kerdőív sajat képernyőjét', (tester) async {
    await tester.pumpWidget(_app(_FakePollService(poll: _poll)));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();

    // A kerdőív képernyője: cim + a valaszlehetosegek radio sorokként.
    expect(find.text('Kérdőív'), findsOneWidget);
    expect(find.text('Igen'), findsOneWidget);
    expect(find.text('Nem'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    expect(find.text('Szavazok'), findsOneWidget);
  });

  testWidgets('szavazas utan a „Köszönjük" allapot jelenik meg', (
    tester,
  ) async {
    final fake = _FakePollService(poll: _poll);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szavazok'));
    await tester.pumpAndSettle();

    expect(fake.voteCalls, 1);
    expect(fake.lastOptionIndex, 1);
    expect(find.textContaining('Köszönjük'), findsOneWidget);
    expect(find.text('Szavazok'), findsNothing);
  });

  testWidgets('ha a szerver szerint mar szavazott, nincs valaszlista', (
    tester,
  ) async {
    // Ez a tulajdonos esete: a szavazat megvan a szerveren, ezert nem szabad
    // megint a valaszlehetosegeket mutatni.
    final fake = _FakePollService(poll: _poll, voted: true);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.textContaining('Köszönjük'), findsOneWidget);
    expect(find.text('Szavazok'), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
  });

  testWidgets(
    'a valaszlista meg sem jelenik, amig a szerver valasza uton van',
    (tester) async {
      // A tulajdonos kérése: „ha valaki szavazott, csak kapja meg a már
      // szavaztál dolgot és ne lássa a listát". Ez akkor is igaz, ha a
      // válasz még úton van: a lista csak KIFEJEZETT „nem szavaztál" után jön.
      final fake = _FakePollService(
        poll: _poll,
        voted: true,
        statusDelay: const Duration(milliseconds: 400),
      );
      await tester.pumpWidget(_app(fake));
      await tester.pumpAndSettle();

      await tester.tap(entry);
      // Egy pillanat: a status valasz MEG NEM erkezett meg.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsNothing,
        reason: 'a lista nem villanhat fel, mielott a szerver valaszol',
      );
      expect(find.text('Szavazok'), findsNothing);

      // A valasz megjott: szavazott -> a „Köszönjük" allapot.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('Köszönjük'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    },
  );

  testWidgets('ha a status lekerdezes hibara fut, a lista NEM jelenik meg', (
    tester,
  ) async {
    final fake = _FailingStatusPollService(poll: _poll);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text('Szavazok'), findsNothing);
    expect(find.textContaining('nem sikerült lekérdezni'), findsOneWidget);
  });

  testWidgets(
    'vendegnek regisztracios figyelmeztetes van valaszlista helyett',
    (tester) async {
      await tester.pumpWidget(
        _app(_FakePollService(poll: _poll), registered: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.textContaining('regisztrált fiók szükséges'), findsOneWidget);
      expect(find.text('Szavazok'), findsNothing);
    },
  );

  testWidgets('sima felhasznalonak NINCS eredmeny-gomb (nincs jogosultsaga)', (
    tester,
  ) async {
    // A tulajdonos jelzese: szavazas utan a sima user latott egy
    // „Eredmények megtekintése" gombot, ami a WordPress ADMIN vegpontra visz,
    // ezert hibat kapott. A gombot sima felhasznalonak nem szabad kiadni.
    final fake = _FakePollService(poll: _poll);
    await tester.pumpWidget(_app(fake, admin: false));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szavazok'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Köszönjük'),
      findsOneWidget,
      reason: 'szavazott',
    );
    expect(
      find.text('Eredmények megtekintése'),
      findsNothing,
      reason: 'a sima user nem kaphat eredmeny-gombot',
    );
  });

  testWidgets('adminként ott van az eredmeny-gomb, szavazas elott is', (
    tester,
  ) async {
    // A tulajdonos jelzese: „nekem adminként nincs ott". Aki a kerdőívet
    // osszeallitja, annak a szavazas ELOTT is meg kell tudnia nezni az allast,
    // ezert a gomb nem fugg attol, hogy szavazott-e mar.
    final fake = _FakePollService(poll: _poll);
    await tester.pumpWidget(_app(fake, admin: true));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Eredmények megtekintése'), findsOneWidget);
    expect(find.text('Szavazok'), findsOneWidget, reason: 'a szavazas is megy');
  });

  testWidgets('adminként szavazas utan is ott van az eredmeny-gomb', (
    tester,
  ) async {
    final fake = _FakePollService(poll: _poll);
    await tester.pumpWidget(_app(fake, admin: true));
    await tester.pumpAndSettle();

    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szavazok'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Köszönjük'), findsOneWidget);
    expect(find.text('Eredmények megtekintése'), findsOneWidget);
  });
}
