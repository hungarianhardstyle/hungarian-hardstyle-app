import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/poll.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/providers/poll_provider.dart';
import 'package:hungarian_hardstyle_app/services/poll_service.dart';
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
  Future<HuhsPoll?> activePoll({bool forceRefresh = false}) async => poll;

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
  Future<HuhsPoll?> activePoll({bool forceRefresh = false}) async => poll;

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

Widget _app(PollService fake, {bool registered = true}) {
  return ProviderScope(
    overrides: [
      pollServiceProvider.overrideWithValue(fake),
      communityAuthProvider.overrideWith(
        (ref) => Stream<User?>.value(registered ? _RegisteredUser() : null),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: ListView(children: const [PollEntryButton()])),
    ),
  );
}

void main() {
  testWidgets('nyitott kerdőívnel gomb jelenik meg, a kerdessel', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakePollService(poll: _poll)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kérdőív:'), findsOneWidget);
    expect(find.textContaining('Tetszik az Applikáció?'), findsOneWidget);
  });

  testWidgets('nincs nyitott kerdőív -> nincs gomb', (tester) async {
    await tester.pumpWidget(_app(_FakePollService(poll: null)));
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('a gomb megnyitja a kerdőív sajat képernyőjét', (tester) async {
    await tester.pumpWidget(_app(_FakePollService(poll: _poll)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(OutlinedButton));
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

    await tester.tap(find.byType(OutlinedButton));
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

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Köszönjük'), findsOneWidget);
    expect(find.text('Szavazok'), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
  });

  testWidgets('a valaszlista meg sem jelenik, amig a szerver valasza uton van', (
    tester,
  ) async {
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

    await tester.tap(find.byType(OutlinedButton));
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
  });

  testWidgets('ha a status lekerdezes hibara fut, a lista NEM jelenik meg', (
    tester,
  ) async {
    final fake = _FailingStatusPollService(poll: _poll);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text('Szavazok'), findsNothing);
    expect(find.textContaining('nem sikerült lekérdezni'), findsOneWidget);
  });

  testWidgets('vendegnek regisztracios figyelmeztetes van valaszlista helyett', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakePollService(poll: _poll), registered: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('regisztrált fiók szükséges'), findsOneWidget);
    expect(find.text('Szavazok'), findsNothing);
  });
}
