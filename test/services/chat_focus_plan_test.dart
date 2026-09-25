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

    // ⚠️ A tulajdonos jelzése (2026-09-25): *„chat üzenet like értesítés néha a
    // megfelelő helyre dob, ha rányomok, néha nem"*. A gyökér az volt, hogy az
    // üres (még be nem töltött) ablak `keepLoading`-ot adott, ezért a képernyő
    // lapozásnak számolta a betöltés közbeni köröket, és a 10 lapos keret az
    // adat megérkezése ELŐTT elfogyott → hideg indításnál nem ugrott oda.
    group('amíg az élő ablak nem érkezett meg (a „néha nem" hibája)', () {
      test('az üres ablak VÁRAKOZIK, nem lapoz (nem fogyasztja a keretet)', () {
        expect(plan(focusId: 'a').status, ChatFocusStatus.waiting);
        expect(
          plan(focusId: 'a', loadedPages: 9, maxPages: 10).status,
          ChatFocusStatus.waiting,
          reason: 'a keret nem fogy, amíg nincs mit lapozni',
        );
      });

      test('a várakozás nem visz a lap-korlátba (10 kör után sem adja fel)', () {
        // A képernyő a `waiting` ágban nem növeli a lapszámot, ezért a terv
        // ugyanaz marad, akárhányszor újraszámoljuk.
        for (var round = 0; round < 25; round++) {
          expect(plan(focusId: 'a').status, ChatFocusStatus.waiting);
        }
      });

      test('ha viszont elfogytak az üzenetek, akkor feladjuk', () {
        expect(
          plan(focusId: 'a', reachedStart: true).status,
          ChatFocusStatus.giveUp,
        );
      });

      test('a lap-korlát az üres ablaknál is érvényes (nincs végtelen várás)', () {
        expect(
          plan(focusId: 'a', loadedPages: 10, maxPages: 10).status,
          ChatFocusStatus.giveUp,
          reason: 'ha az adat sosem jön meg, a keret lezárja a keresést',
        );
      });

      test('ha csak a lapozott lista van meg, az is elég a kereséshez', () {
        expect(
          plan(focusId: 'z', older: ['x']).status,
          ChatFocusStatus.keepLoading,
          reason: 'van mit tovább lapozni',
        );
      });
    });

    // ⚠️ A tulajdonos jelzése (2026-09-25): *„egy régebbi chat like … rányomtam
    // és nem dobott a chat üzire … régebbi chat üzivel nem megy, újabba igen"*.
    // A gyökér a **görgetés** volt: a `ListView` csak a látható elemeket építi
    // fel, ezért a mélyen lévő kártya kontextusa nincs meg, a régi kód pedig a
    // lista VÉGÉRE ugrott. Ez a becslés visz a cél közelébe.
    group('a cél pozíciójának becslése (a mélyen lévő üzenet odaugrása)', () {
      double estimate(int index, {int itemCount = 41, double max = 4000}) {
        return chatScrollEstimateForIndex(
          index: index,
          itemCount: itemCount,
          maxScrollExtent: max,
        );
      }

      test('a legfelső üzenet a lista teteje (nem a vége!)', () {
        expect(
          estimate(0),
          0,
          reason: 'az index 0 mindig a legteteje — ez volt a „legfrissebb sem jó" hiba',
        );
      });

      test('a középső üzenet arányosan a lista közepére esik', () {
        // 41 elem, 4000 px: átlag 100 px/elem → a 25. elem 2500 px-nél van.
        expect(estimate(25), 2500);
        expect(estimate(10), 1000);
      });

      test('az utolsó üzenet a lista végére esik', () {
        expect(estimate(40), 4000);
      });

      test('a végét túllépő index a lista végére szorul (nem ugrik túl)', () {
        expect(estimate(100), 4000);
      });

      test('negatív index és üres lista nem tör el semmit', () {
        expect(estimate(-5), 0);
        expect(estimate(10, itemCount: 1), 0);
        expect(estimate(10, itemCount: 0), 0);
      });

      test('értelmetlen görgetési hossz (0, negatív, végtelen) → 0', () {
        expect(estimate(10, max: 0), 0);
        expect(estimate(10, max: -100), 0);
        expect(estimate(10, max: double.infinity), 0);
      });
    });
  });
}
