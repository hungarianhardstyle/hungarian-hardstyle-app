import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/screens/community/admin_resource_editor_screen.dart';

/// A natív szerkesztő (kérdőív / nyereményjáték / kvíz) LÉTREHOZÁSÁNAK mérése.
///
/// **MIÉRT:** a tulajdonos kérése az volt, hogy az appból **új** kérdőívet,
/// nyereményjátékot és kvízt lehessen létrehozni. Ez a teszt nem a képernyő
/// külsejét méri, hanem a **szervernek küldött tartalmat**: pontosan azok a
/// meta-kulcsok mennek-e ki, amiket a WordPress-oldali űrlap is használ
/// (`_huhs_poll_options`, `_huhs_prize_correct`, `_huhs_game_questions`).
///
/// A hálózat egyetlen szűk provideren megy (`adminResourceRequestProvider`),
/// ezért a teszt **Firebase nélkül** fut.
class _RecordingRequest {
  _RecordingRequest(this.responses);

  /// A `(path, method, body)` hívások sorrendben.
  final calls = <({String path, String method, Map<String, dynamic>? body})>[];

  /// path-töredék → válasz (vagy kivétel).
  final Map<String, Object> responses;

  Future<dynamic> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    calls.add((path: path, method: method, body: body));
    for (final entry in responses.entries) {
      if (path.contains(entry.key)) {
        final value = entry.value;
        if (value is Exception) throw value;
        if (value is Map && method == 'POST') return {...value};
        return value;
      }
    }
    throw StateError('Nem várt hívás a tesztben: $path');
  }
}

Map<String, dynamic> _field(
  String key,
  String label,
  String type, {
  int? min,
  int? max,
  List<Map<String, String>>? options,
}) => {
  'key': key,
  'label': label,
  'type': type,
  'value': '',
  if (min != null) 'min': min,
  if (max != null) 'max': max,
  if (options != null) 'options': options,
};

Future<void> _pumpEditor(
  WidgetTester tester,
  _RecordingRequest request,
  String type,
) async {
  // Magasabb felület: a „Létrehozás” gomb a lista alján van, és a `ListView`
  // lustán épít — így a gomb biztosan létrejön (különben a `tap` nem találná).
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminResourceRequestProvider.overrideWithValue(request.call),
      ],
      child: MaterialApp(
        home: AdminResourceEditorScreen(type: type, typeLabel: 'Teszt'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kérdőív: a mentés a valódi meta-kulcsokat küldi', (tester) async {
    final request = _RecordingRequest({
      'action=resource': {
        'id': 0,
        'title': '',
        'status': 'draft',
        'fields': [
          _field('_huhs_poll_question', 'Kérdés', 'text'),
          _field('_huhs_poll_options', 'Válaszlehetőségek (2–6)', 'text_list', min: 2, max: 6),
          _field('_huhs_poll_start', 'Kezdés', 'text'),
        ],
      },
      'action=save_resource': {'saved': true, 'id': 77, 'created': true},
    });
    await _pumpEditor(tester, request, 'huhs_poll');

    await tester.enterText(
      find.byKey(const Key('admin-field-_huhs_poll_question')),
      'Tetszik az app?',
    );
    await tester.enterText(find.byKey(const Key('admin-list-_huhs_poll_options-0')), 'Igen');
    await tester.enterText(find.byKey(const Key('admin-list-_huhs_poll_options-1')), 'Nem');
    await tester.tap(find.text('Létrehozás'));
    await tester.pumpAndSettle();

    final save = request.calls.firstWhere((call) => call.method == 'POST');
    expect(save.path, '/huhs/v1/admin');
    expect(save.body?['action'], 'save_resource');
    expect(save.body?['id'], 0);
    expect(save.body?['type'], 'huhs_poll');
    expect(save.body?['status'], 'publish');
    final meta = save.body?['meta'] as Map<String, dynamic>;
    expect(meta['_huhs_poll_question'], 'Tetszik az app?');
    expect(meta['_huhs_poll_options'], ['Igen', 'Nem']);
  });

  testWidgets('kérdőív: 1 megadott válasszal nem küld semmit (helyi ellenőrzés)', (tester) async {
    final request = _RecordingRequest({
      'action=resource': {
        'id': 0,
        'fields': [
          _field('_huhs_poll_question', 'Kérdés', 'text'),
          _field('_huhs_poll_options', 'Válaszlehetőségek (2–6)', 'text_list', min: 2, max: 6),
        ],
      },
      'action=save_resource': {'saved': true, 'created': true},
    });
    await _pumpEditor(tester, request, 'huhs_poll');

    await tester.enterText(
      find.byKey(const Key('admin-field-_huhs_poll_question')),
      'Kérdés?',
    );
    await tester.enterText(find.byKey(const Key('admin-list-_huhs_poll_options-0')), 'Egy');
    await tester.tap(find.text('Létrehozás'));
    await tester.pumpAndSettle();

    expect(request.calls.any((call) => call.method == 'POST'), isFalse, reason: 'nem mehet ki mentés');
    expect(find.textContaining('legalább 2'), findsOneWidget);
  });

  testWidgets('nyereményjáték: a helyes válasz sorszáma számként megy ki', (tester) async {
    final request = _RecordingRequest({
      'action=resource': {
        'id': 0,
        'fields': [
          _field('_huhs_prize_question', 'Kvízkérdés', 'text'),
          _field('_huhs_prize_answers', 'Válaszlehetőségek (3–5)', 'text_list', min: 3, max: 5),
          _field('_huhs_prize_correct', 'A helyes válasz sorszáma (1-től)', 'int'),
          _field('_huhs_prize_display_days', 'A nyertes ennyi napig látszik', 'int'),
        ],
      },
      'action=save_resource': {'saved': true, 'id': 99, 'created': true},
    });
    await _pumpEditor(tester, request, 'huhs_prize');

    await tester.enterText(
      find.byKey(const Key('admin-field-_huhs_prize_question')),
      'Melyik évben alakult?',
    );
    for (var index = 0; index < 3; index++) {
      await tester.enterText(
        find.byKey(Key('admin-list-_huhs_prize_answers-$index')),
        '${2019 + index}',
      );
    }
    await tester.enterText(
      find.byKey(const Key('admin-field-_huhs_prize_correct')),
      '2',
    );
    await tester.enterText(
      find.byKey(const Key('admin-field-_huhs_prize_display_days')),
      '7',
    );
    await tester.tap(find.text('Létrehozás'));
    await tester.pumpAndSettle();

    final save = request.calls.firstWhere((call) => call.method == 'POST');
    final meta = save.body?['meta'] as Map<String, dynamic>;
    expect(meta['_huhs_prize_answers'], ['2019', '2020', '2021']);
    expect(meta['_huhs_prize_correct'], '2');
    expect(meta['_huhs_prize_display_days'], '7');
  });

  testWidgets('kvíz: a kérdések helyes-válasz jelöléssel mennek ki', (tester) async {
    final request = _RecordingRequest({
      'action=resource': {
        'id': 0,
        'fields': [
          _field('_huhs_game_type', 'Játék típusa', 'select', options: [
            {'value': 'hardstyle_quiz', 'label': 'Hardstyle kvíz'},
            {'value': 'festival_quiz', 'label': 'Fesztivál kvíz'},
          ]),
          _field('_huhs_game_questions', 'Kérdések', 'questions'),
        ],
      },
      'action=save_resource': {'saved': true, 'id': 55, 'created': true},
    });
    await _pumpEditor(tester, request, 'huhs_game');

    await tester.enterText(
      find.byKey(const Key('admin-question-0-prompt')),
      'Ki a DJ?',
    );
    await tester.enterText(
      find.byKey(const Key('admin-question-0-option-0')),
      'Denoiser',
    );
    await tester.enterText(
      find.byKey(const Key('admin-question-0-option-1')),
      'Valaki más',
    );
    // Új válasz hozzáadása és a helyes válasz megjelölése (a 2. sor).
    await tester.tap(find.byKey(const Key('admin-question-0-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin-question-0-option-2')),
      'Harmadik',
    );
    await tester.tap(find.byKey(const Key('admin-question-0-correct-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Létrehozás'));
    await tester.pumpAndSettle();

    final save = request.calls.firstWhere((call) => call.method == 'POST');
    final meta = save.body?['meta'] as Map<String, dynamic>;
    expect(meta['_huhs_game_type'], 'hardstyle_quiz');
    final questions = meta['_huhs_game_questions'] as List;
    expect(questions.length, 1);
    expect(questions.first['prompt'], 'Ki a DJ?');
    expect(questions.first['options'], ['Denoiser', 'Valaki más', 'Harmadik']);
    expect(questions.first['correct'], 1, reason: 'a megjelölt válasz indexe');
  });

  testWidgets('kvíz: a hibás kérdés sorszáma megjelenik, és nem megy ki mentés', (tester) async {
    final request = _RecordingRequest({
      'action=resource': {
        'id': 0,
        'fields': [
          _field('_huhs_game_type', 'Játék típusa', 'select', options: [
            {'value': 'hardstyle_quiz', 'label': 'Hardstyle kvíz'},
          ]),
          _field('_huhs_game_questions', 'Kérdések', 'questions'),
        ],
      },
      'action=save_resource': {'saved': true, 'created': true},
    });
    await _pumpEditor(tester, request, 'huhs_game');

    // 1. kérdés rendben.
    await tester.enterText(find.byKey(const Key('admin-question-0-prompt')), 'Első');
    await tester.enterText(find.byKey(const Key('admin-question-0-option-0')), 'A');
    await tester.enterText(find.byKey(const Key('admin-question-0-option-1')), 'B');
    await tester.tap(find.byKey(const Key('admin-question-0-correct-0')));
    // 2. kérdés: nincs megjelölt helyes válasz.
    await tester.tap(find.byKey(const Key('admin-question-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin-question-1-prompt')), 'Második');
    await tester.enterText(find.byKey(const Key('admin-question-1-option-0')), 'A');
    await tester.enterText(find.byKey(const Key('admin-question-1-option-1')), 'B');
    await tester.tap(find.text('Létrehozás'));
    await tester.pumpAndSettle();

    expect(request.calls.any((call) => call.method == 'POST'), isFalse);
    expect(find.textContaining('jelöld meg a helyes választ'), findsOneWidget);
  });

  testWidgets('a szerver hibaüzenete megjelenik (nem néma hiba)', (tester) async {
    final request = _RecordingRequest({
      'action=resource': {
        'id': 0,
        'fields': [
          _field('_huhs_poll_question', 'Kérdés', 'text'),
          _field('_huhs_poll_options', 'Válaszlehetőségek (2–6)', 'text_list', min: 2, max: 6),
        ],
      },
      'action=save_resource': Exception('HIBA: a szerver elutasította'),
    });
    await _pumpEditor(tester, request, 'huhs_poll');

    await tester.enterText(
      find.byKey(const Key('admin-field-_huhs_poll_question')),
      'Kérdés?',
    );
    await tester.enterText(find.byKey(const Key('admin-list-_huhs_poll_options-0')), 'A');
    await tester.enterText(find.byKey(const Key('admin-list-_huhs_poll_options-1')), 'B');
    await tester.tap(find.text('Létrehozás'));
    await tester.pumpAndSettle();

    expect(find.textContaining('nem sikerült'), findsOneWidget);
  });
}
