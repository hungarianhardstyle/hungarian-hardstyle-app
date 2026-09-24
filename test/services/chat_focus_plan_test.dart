import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/chat_focus_plan.dart';

/// A Chat-értesítésre való odaugrás **tiszta** szabályai.
///
/// A tulajdonos kérése: *„a chatnél meg odaugorhatna arra az üzenetre amit
/// lájkoltak, ha a notifyre nyomok"*.
void main() {
  ChatFocusPlan plan({
    required String focusId,
    List<String> newest = const [],
    List<String> older = const [],
    bool reachedStart = false,
    int loadedPages = 0,
    int maxPages = chatFocusMaxPages,
  }) {
    return chatFocusPlan(
      focusId: focusId,
      newestIds: newest,
      olderIds: older,
      reachedStart: reachedStart,
      loadedPages: loadedPages,
      maxPages: maxPages,
    );
  }

  group('chatFocusPlan', () {
    test('az élő ablakban megtalált üzenet a saját indexére visz', () {
      final result = plan(
        focusId: 'b',
        newest: ['a', 'b', 'c'],
      );
      expect(result.status, ChatFocusStatus.found);
      expect(result.index, 1);
    });

    test('a lapozott (régebbi) üzenet indexe a lista folytatásában van', () {
      final result = plan(
        focusId: 'x',
        newest: ['a', 'b', 'c'],
        older: ['x', 'y'],
      );
      expect(result.status, ChatFocusStatus.found);
      expect(
        result.index,
        3,
        reason: 'a megjelenített lista: a, b, c után x, y',
      );
    });

    test('ha nincs meg és van mit tölteni, tovább kell lapozni', () {
      final result = plan(focusId: 'z', newest: ['a'], older: ['x']);
      expect(result.status, ChatFocusStatus.keepLoading);
      expect(result.index, isNull);
    });

    test('a beszélgetés elején feladjuk (nincs több üzenet)', () {
      expect(
        plan(focusId: 'z', newest: ['a'], reachedStart: true).status,
        ChatFocusStatus.giveUp,
      );
    });

    test('a lap-korlát után feladjuk (nem olvasunk korlátlanul)', () {
      expect(
        plan(focusId: 'z', newest: ['a'], loadedPages: 10, maxPages: 10).status,
        ChatFocusStatus.giveUp,
      );
      expect(
        plan(focusId: 'z', newest: ['a'], loadedPages: 9, maxPages: 10).status,
        ChatFocusStatus.keepLoading,
      );
    });

    test('üres vagy hiányzó azonosító esetén nincs odaugrás', () {
      expect(plan(focusId: '').status, ChatFocusStatus.giveUp);
      expect(plan(focusId: '   ').status, ChatFocusStatus.giveUp);
    });

    test('a környező szóköz nem zavar', () {
      final result = plan(focusId: ' b ', newest: ['a', 'b']);
      expect(result.status, ChatFocusStatus.found);
      expect(result.index, 1);
    });

    test('üres listáknál sem találgat', () {
      expect(plan(focusId: 'a').status, ChatFocusStatus.keepLoading);
      expect(
        plan(focusId: 'a', reachedStart: true).status,
        ChatFocusStatus.giveUp,
      );
    });
  });
}
