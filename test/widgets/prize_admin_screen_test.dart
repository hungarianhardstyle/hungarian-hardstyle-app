import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/screens/community/prize_admin_screen.dart';

/// A nyereményjáték **natív** admin-nézete.
///
/// **A tulajdonos kérése:** *„Natív HUHS adminba bekerülhetnének az új dolgok,
/// működően (értds: az appba)"*. A nyereményjáték eddig csak a WordPress
/// adminjában volt átlátható; ez a képernyő ugyanazt mutatja az appban.
///
/// Ez a teszt a levelezést rögzíti: a képernyő a **`prize_games`** és a
/// **`prize_results`** admin-műveletet kéri (tehát a `manage_options` mögötti,
/// admin-adatokat adó végpontot), és a válaszból kirajzolja a válaszmegoszlást,
/// a **helyes válasz jelölését**, valamint a résztvevőket a nyertessel.
///
/// A hálózati szeletet a `prizeAdminRequestProvider` felülírása adja: a
/// `CommunityService` példányosítása a Firestore-t is felépítené, ezért az nem
/// helyettesíthető Firebase nélkül.
class _FakeAdminApi {
  _FakeAdminApi({this.games = const [], this.summaries = const {}});

  final List<Map<String, dynamic>> games;
  final Map<int, Map<String, dynamic>> summaries;
  final List<String> requestedQueries = [];
  int clearCacheCalls = 0;

  Future<dynamic> request(String query) async {
    requestedQueries.add(query);
    if (query.contains('action=prize_games')) return {'prizes': games};
    final match = RegExp(r'prizeId=(\d+)').firstMatch(query);
    final prizeId = int.tryParse(match?.group(1) ?? '') ?? 0;
    return {'prize': summaries[prizeId]};
  }
}

Map<String, dynamic> _game({
  required int id,
  required String question,
  String state = 'closed',
  int players = 0,
  int correct = 0,
  String winner = '',
}) {
  return {
    'id': id,
    'question': question,
    'state': state,
    'players': players,
    'correct': correct,
    'winner': winner,
  };
}

Map<String, dynamic> _summary({
  required int id,
  required String question,
  String state = 'drawn',
  required int correctIndex,
  required List<Map<String, dynamic>> answers,
  required List<Map<String, dynamic>> participants,
  int players = 0,
  int correct = 0,
  int displayDays = 7,
  Map<String, dynamic>? winner,
  String prizeType = '',
  String prizeDescription = '',
}) {
  return {
    'id': id,
    'question': question,
    'state': state,
    'correctIndex': correctIndex,
    'answers': answers,
    'participants': participants,
    'players': players,
    'correct': correct,
    'displayDays': displayDays,
    'winner': winner,
    'prizeType': prizeType,
    'prizeDescription': prizeDescription,
  };
}

Widget _app(_FakeAdminApi api) {
  return ProviderScope(
    overrides: [
      prizeAdminRequestProvider.overrideWithValue(api.request),
      prizeAdminCacheClearProvider.overrideWithValue(
        () => api.clearCacheCalls += 1,
      ),
    ],
    child: const MaterialApp(home: PrizeAdminScreen()),
  );
}

void main() {
  testWidgets('a játék résztvevőit és a helyes választ mutatja', (tester) async {
    final api = _FakeAdminApi(
      games: [
        _game(
          id: 900,
          question: 'Melyik évben alakult a HUHS?',
          players: 2,
          correct: 1,
          winner: 'Kiss Péter',
        ),
      ],
      summaries: {
        900: _summary(
          id: 900,
          question: 'Melyik évben alakult a HUHS?',
          correctIndex: 1,
          answers: [
            {'index': 0, 'label': '2015', 'count': 1, 'percent': 50},
            {'index': 1, 'label': '2018', 'count': 1, 'percent': 50},
          ],
          participants: [
            {
              'name': 'Kiss Péter',
              'answerLabel': '2018',
              'correct': true,
              'at': '2026-09-20 18:00:00',
              'winner': true,
            },
            {
              'name': 'Nagy Anna',
              'answerLabel': '2015',
              'correct': false,
              'at': '2026-09-20 18:05:00',
              'winner': false,
            },
          ],
          players: 2,
          correct: 1,
          winner: {'name': 'Kiss Péter', 'drawnAt': '2026-09-20 18:10:00'},
          prizeType: 'HUHS póló',
        ),
      },
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    // A KÉRÉS az admin-műveletre megy (nem a nyilvános /prize/active-ra).
    expect(
      api.requestedQueries.any((q) => q.contains('action=prize_games')),
      isTrue,
    );
    expect(
      api.requestedQueries.any((q) => q.contains('action=prize_results')),
      isTrue,
    );

    // A helyes válasz meg van jelölve — ezt a nyilvános végpont nem adná ki.
    expect(find.textContaining('2018'), findsWidgets);
    expect(find.textContaining('helyes'), findsWidgets);
    // A résztvevők neve és a nyertes jelölése látszik.
    expect(find.text('Kiss Péter'), findsWidgets);
    expect(find.text('Nagy Anna'), findsOneWidget);
    expect(find.textContaining('Nyertes: Kiss Péter'), findsOneWidget);
    expect(find.textContaining('HUHS póló'), findsOneWidget);
  });

  testWidgets('a legördülőből a régebbi játék is kiválasztható', (tester) async {
    final api = _FakeAdminApi(
      games: [
        _game(id: 900, question: 'Első játék'),
        _game(id: 899, question: 'Régebbi játék', winner: 'Nagy Anna'),
      ],
      summaries: {
        900: _summary(
          id: 900,
          question: 'Első játék',
          correctIndex: 0,
          answers: [
            {'index': 0, 'label': 'A', 'count': 0, 'percent': 0},
          ],
          participants: const [],
        ),
        899: _summary(
          id: 899,
          question: 'Régebbi játék',
          correctIndex: 0,
          answers: [
            {'index': 0, 'label': 'A', 'count': 1, 'percent': 100},
          ],
          participants: [
            {
              'name': 'Nagy Anna',
              'answerLabel': 'A',
              'correct': true,
              'at': '2026-09-01 10:00:00',
              'winner': true,
            },
          ],
        ),
      },
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('Első játék'), findsWidgets);

    await tester.tap(find.byKey(const Key('prize-admin-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Régebbi játék').last);
    await tester.pumpAndSettle();

    expect(
      api.requestedQueries.any((q) => q.contains('prizeId=899')),
      isTrue,
      reason: 'a választott játék adatait külön kéri le',
    );
    expect(find.text('Nagy Anna'), findsOneWidget);
  });

  testWidgets('üres játékkal érthető üzenet jön', (tester) async {
    final api = _FakeAdminApi(games: const []);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nincs elérhető'), findsOneWidget);
  });

  testWidgets('a játékos nélküli játéknál jelzi, hogy még senki nem játszott', (
    tester,
  ) async {
    final api = _FakeAdminApi(
      games: [_game(id: 900, question: 'Üres játék', state: 'open')],
      summaries: {
        900: _summary(
          id: 900,
          question: 'Üres játék',
          state: 'open',
          correctIndex: 1,
          answers: [
            {'index': 0, 'label': 'A', 'count': 0, 'percent': 0},
            {'index': 1, 'label': 'B', 'count': 0, 'percent': 0},
          ],
          participants: const [],
        ),
      },
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Még senki nem játszott'),
      findsOneWidget,
    );
  });
}
