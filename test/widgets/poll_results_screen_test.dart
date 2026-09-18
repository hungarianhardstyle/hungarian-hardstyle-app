import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/screens/poll/poll_results_screen.dart';

/// A kérdőív admin-összesítője.
///
/// **A tulajdonos jelzése:** *„A kérdőívnél rossz szavazási összesítő van az
/// adminnak, az éves szavazást mutatja"*. A gyökér az volt, hogy a kérdőív
/// „Eredmények megtekintése" gombja a `VotingSummaryScreen`-t nyitotta meg,
/// ami a `/huhs/v1/admin?action=voting_summary` végpontot kéri le — vagyis az
/// **éves szavazás** jelöltjeire leadott szavazatokat.
///
/// Ez a teszt a levelezést rögzíti: a képernyő a **`polls`** és a
/// **`poll_results`** műveletet kéri (és soha nem a `voting_summary`-t), a
/// válaszokból pedig a kérdőív saját válaszlehetőségeit és szavazatszámait
/// rajzolja ki, a választóból pedig a régebbi kérdőívek is elérhetők.
///
/// A hálózati szeletet a `pollAdminRequestProvider` felülírása adja: a
/// `CommunityService` példányosítása a Firestore-t is felépítené, ezért az nem
/// helyettesíthető Firebase nélkül.
class _FakeAdminApi {
  _FakeAdminApi({this.polls = const [], this.summaries = const {}});

  final List<Map<String, dynamic>> polls;
  final Map<int, Map<String, dynamic>> summaries;
  final List<String> requestedQueries = [];
  int clearCacheCalls = 0;

  Future<dynamic> request(String query) async {
    requestedQueries.add(query);
    if (query.contains('action=polls')) return {'polls': polls};
    final match = RegExp(r'pollId=(\d+)').firstMatch(query);
    final pollId = int.tryParse(match?.group(1) ?? '') ?? 0;
    return {'poll': summaries[pollId]};
  }
}

Map<String, dynamic> _poll({
  required int id,
  required String question,
  String state = 'open',
  int votes = 0,
}) {
  return {
    'id': id,
    'question': question,
    'state': state,
    'votes': votes,
  };
}

Map<String, dynamic> _summary({
  required int id,
  required String question,
  String state = 'open',
  required List<Map<String, dynamic>> options,
  required int total,
}) {
  return {
    'id': id,
    'question': question,
    'state': state,
    'total': total,
    'options': options,
  };
}

Widget _app(_FakeAdminApi api) {
  return ProviderScope(
    overrides: [
      pollAdminRequestProvider.overrideWithValue(api.request),
      pollAdminCacheClearProvider.overrideWithValue(
        () => api.clearCacheCalls += 1,
      ),
    ],
    child: const MaterialApp(home: PollResultsScreen()),
  );
}

void main() {
  testWidgets('a kerdőív SAJAT valaszait mutatja, nem az éves szavazast', (
    tester,
  ) async {
    final service = _FakeAdminApi(
      polls: [_poll(id: 12694, question: 'Tetszik az Applikáció?', votes: 5)],
      summaries: {
        12694: _summary(
          id: 12694,
          question: 'Tetszik az Applikáció?',
          options: [
            {'index': 0, 'label': 'Igen', 'count': 4, 'percent': 80},
            {'index': 1, 'label': 'Nem', 'count': 1, 'percent': 20},
          ],
          total: 5,
        ),
      },
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Tetszik az Applikáció?'), findsWidgets);
    expect(find.text('Igen'), findsOneWidget);
    expect(find.text('Nem'), findsOneWidget);
    expect(find.text('4 szavazat · 80%'), findsOneWidget);
    expect(find.text('1 szavazat · 20%'), findsOneWidget);
    expect(find.textContaining('összes szavazat: 5'), findsOneWidget);
  });

  testWidgets('SOHA nem az éves szavazas összesítőjét kéri', (tester) async {
    // Ez a lényegi regresszió-védelem: a rossz gomb pontosan ezt hívta.
    final service = _FakeAdminApi(
      polls: [_poll(id: 1, question: 'Kerdes?')],
      summaries: {
        1: _summary(
          id: 1,
          question: 'Kerdes?',
          options: [
            {'index': 0, 'label': 'A', 'count': 0, 'percent': 0},
          ],
          total: 0,
        ),
      },
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(
      service.requestedQueries.any((query) => query.contains('voting_summary')),
      isFalse,
    );
    expect(
      service.requestedQueries.any((query) => query.contains('action=polls')),
      isTrue,
      reason: 'a valasztohoz le kell kérnie a kerdőívek listáját',
    );
    expect(
      service.requestedQueries.any(
        (query) => query.contains('action=poll_results&pollId=1'),
      ),
      isTrue,
    );
  });

  testWidgets('a legordulobol a REGI kerdőív is kivalaszthato', (tester) async {
    final service = _FakeAdminApi(
      polls: [
        _poll(id: 200, question: 'Uj kerdes', votes: 2),
        _poll(id: 100, question: 'Regi kerdes', state: 'closed', votes: 7),
      ],
      summaries: {
        200: _summary(
          id: 200,
          question: 'Uj kerdes',
          options: [
            {'index': 0, 'label': 'Uj-A', 'count': 2, 'percent': 100},
          ],
          total: 2,
        ),
        100: _summary(
          id: 100,
          question: 'Regi kerdes',
          state: 'closed',
          options: [
            {'index': 0, 'label': 'Regi-A', 'count': 5, 'percent': 71},
            {'index': 1, 'label': 'Regi-B', 'count': 2, 'percent': 29},
          ],
          total: 7,
        ),
      },
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    // Alapertelmezesben a legfrissebb.
    expect(find.text('Uj-A'), findsOneWidget);

    await tester.tap(find.byKey(const Key('poll-results-select')));
    await tester.pumpAndSettle();
    // A legorduloben a cimke tartalmazza az allapotot es a szavazatszamot.
    expect(find.text('Regi kerdes — lezárult · 7 szavazat'), findsWidgets);

    await tester.tap(find.text('Regi kerdes — lezárult · 7 szavazat').last);
    await tester.pumpAndSettle();

    expect(find.text('Regi-A'), findsOneWidget);
    expect(find.text('Regi-B'), findsOneWidget);
    expect(find.text('5 szavazat · 71%'), findsOneWidget);
    expect(find.textContaining('összes szavazat: 7'), findsOneWidget);
  });

  testWidgets('a frissites gomb ujra lekérdez es üríti az admin-cache-t', (
    tester,
  ) async {
    final service = _FakeAdminApi(
      polls: [_poll(id: 1, question: 'Kerdes?')],
      summaries: {
        1: _summary(
          id: 1,
          question: 'Kerdes?',
          options: [
            {'index': 0, 'label': 'A', 'count': 1, 'percent': 100},
          ],
          total: 1,
        ),
      },
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final before = service.requestedQueries.length;

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(service.clearCacheCalls, 1);
    expect(service.requestedQueries.length, greaterThan(before));
  });

  testWidgets('nincs kerdőív -> ertheto uzenet', (tester) async {
    await tester.pumpWidget(_app(_FakeAdminApi()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nincs elérhető kérdőív'), findsOneWidget);
  });

  testWidgets('szavazat nelkul is mutatja a nullakat', (tester) async {
    final service = _FakeAdminApi(
      polls: [_poll(id: 1, question: 'Kerdes?')],
      summaries: {
        1: _summary(
          id: 1,
          question: 'Kerdes?',
          options: [
            {'index': 0, 'label': 'A', 'count': 0, 'percent': 0},
            {'index': 1, 'label': 'B', 'count': 0, 'percent': 0},
          ],
          total: 0,
        ),
      },
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('0 szavazat · 0%'), findsNWidgets(2));
    expect(find.textContaining('összes szavazat: 0'), findsOneWidget);
  });
}
