import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Forrás-lint: az értesítésre való **odaugrás** és a **cselekvő neve**.
///
/// A tulajdonos jelzése (2026-09-24): *„jön notify hogy kedvelték egy chat
/// üzenetem, meg arról is hogy valaki írt egy hírhez kommentet, de odaírhatná,
/// hogy KI likeolta, a chatnél meg odaugorhatna arra az üzenetre amit
/// lájkoltak, ha a notifyre nyomok"*.
///
/// A tiszta szabályok tesztjei (`chat_focus_plan_test.dart`,
/// `functions/actor-name-plan.test.cjs`) a logikát fedik; ez a fájl a
/// **bekötést** őrzi — a 351-es tanulság szerint a szabály lehet helyes, a
/// bekötés hibás.
void main() {
  String readFile(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  group('forrás-lint: chat-odaugrás az értesítésből', () {
    late String center;
    late String chat;

    setUpAll(() {
      center = readFile('lib/screens/notifications/notification_center_screen.dart');
      chat = readFile('lib/screens/community/community_screen.dart');
    });

    test('az értesítés-központ átadja a megjelölt üzenetet a Chatnek', () {
      expect(
        center,
        contains('LiveFeedScreen(focusPostId: target)'),
        reason: 'a chat-ág a targetId-t adja át (a lájkolt/válaszolt üzenetet)',
      );
      expect(center, isNot(contains('const LiveFeedScreen()')));
    });

    test('a Chat képernyő elfogadja és használja a megjelölt üzenetet', () {
      expect(chat, contains('final String? focusPostId;'));
      expect(chat, contains("import '../../services/chat_focus_plan.dart';"));
      expect(chat, contains('chatFocusPlan('));
    });

    test('a keresés lapoz, de korlátozottan (nem olvas végtelenül)', () {
      expect(chat, contains('ChatFocusStatus.keepLoading'));
      expect(chat, contains('ChatFocusStatus.giveUp'));
      expect(
        chat,
        contains('_focusPagesLoaded++'),
        reason: 'a lap-korlátot számoljuk',
      );
    });

    // ⚠️ A tulajdonos jelzése (2026-09-25): *„chat üzenet like értesítés néha a
    // megfelelő helyre dob, ha rányomok, néha nem"*. A gyökér: az üres élő ablak
    // is lapozásnak számított, ezért a 10 lapos keret az adat megérkezése előtt
    // elfogyott. Ezek a lint-ek a javítás bekötését őrzik.
    test('az üres élő ablaknál VÁRAKOZIK (nem lapoz, nem fogyaszt keretet)', () {
      expect(
        chat,
        contains('ChatFocusStatus.waiting'),
        reason: 'a tiszta terv külön állapota az „adat még nincs" esetre',
      );
      expect(
        chat,
        matches(RegExp(r'case ChatFocusStatus\.waiting:[\s\S]{0,400}?return;')),
        reason: 'a várakozás nem indít lapozást',
      );
    });

    test('a lap-keret csak VALÓDI lapozás után fogy', () {
      expect(
        chat,
        contains('Future<bool> _loadOlderPosts()'),
        reason: 'a lapozás megmondja, történt-e valódi kérés',
      );
      expect(
        chat,
        contains('final loaded = await _loadOlderPosts();'),
        reason: 'a lapozás eredményét meg kell nézni',
      );
      // ⚠️ SZÁNDÉKOSAN SZIGORÚ: az első változat csak azt nézte, hogy a
      // `_focusPagesLoaded++` a `if (!loaded)` UTÁN szerepel a szövegben — az a
      // mutáció viszont átment rajta, amelyik EGY MÁSIK számlálónövelést tesz a
      // lapozás ELÉ (a régi hibás sorrend), mert a minta a régi előfordulásra is
      // illeszkedett. Ezért most a **darabszámot** és a **sorrendet** is kérjük.
      final loadIndex = chat.indexOf('final loaded = await _loadOlderPosts();');
      final guardIndex = chat.indexOf('if (!loaded) {');
      final incrementCount = '_focusPagesLoaded++'.allMatches(chat).length;
      expect(
        incrementCount,
        1,
        reason: 'a lap-keret pontosan EGY helyen fogy (nincs rejtett növelés)',
      );
      expect(
        chat.indexOf('_focusPagesLoaded++'),
        greaterThan(guardIndex),
        reason: 'a számláló a sikeres lapozás UTÁN nő',
      );
      expect(
        guardIndex,
        greaterThan(loadIndex),
        reason: 'az eredmény-ellenőrzés a lapozás UTÁN van',
      );
      expect(
        chat,
        matches(RegExp(r'if \(!loaded\) \{[\s\S]{0,160}?_focusFinished = true;')),
        reason: 'sikertelen lapozásnál feladjuk (nem pörög tovább)',
      );
    });

    test('a betöltés alatt nem indul fölösleges lapozás', () {
      expect(
        RegExp(r'if \(!mounted \|\| _focusFinished\) return;').allMatches(chat).length,
        greaterThanOrEqualTo(2),
        reason:
            'a lapozás előtt ÉS utána is ellenőrizzük, hogy közben megérkezett-e az adat',
      );
    });

    test('a megtalált üzenethez görget ÉS kiemeli', () {
      expect(chat, contains('Scrollable.ensureVisible('));
      expect(chat, contains('_highlightedPostId'));
      expect(
        chat,
        contains('_withFocusHighlight('),
        reason: 'a kiemelés a közös wrapperen keresztül megy mindkét ágra',
      );
      expect(
        chat,
        contains('_highlightTimer'),
        reason: 'a kiemelés magától eltűnik (nem marad ott örökre)',
      );
    });

    test('a kiemelés-kulcs a megjelölt kártyára kerül (nem mindegyikre)', () {
      expect(chat, contains('key: _focusKey'));
      expect(
        chat,
        contains('if (_highlightedPostId != postId) return card;'),
        reason: 'csak az érintett kártya kap kulcsot és keretet',
      );
    });
  });

  group('forrás-lint: a cselekvő neve az értesítésekben', () {
    late String index;

    setUpAll(() {
      index = readFile('functions/index.js');
    });

    test('a chat-lájk értesítés több forrásból oldja fel a nevet', () {
      expect(index, contains('async function resolveActorName(uid)'));
      expect(index, contains('const reactorName = await resolveActorName(uid);'));
      expect(
        index,
        contains("require('./actor-name-plan')"),
        reason: 'a döntés a tiszta modulban van',
      );
    });

    test('a cikk-komment értesítés megnevezi a hozzászólót', () {
      expect(index, contains('const commenterName = actorNameOrGeneric('));
      expect(
        index,
        matches(
          RegExp(
            r"body: `\$\{commenterName\} hozzászólt egy cikkhez",
          ),
        ),
        reason: 'a szövegben ott a név (a tulajdonos kérése)',
      );
      expect(
        index,
        isNot(contains('Új hozzászólás érkezett egy cikkhez. Ellenőrizd')),
        reason: 'a névtelen, általános szöveg nem maradhat bent',
      );
    });

    test('a nevet a hozzászóló profiljából vesszük (nincs extra olvasás)', () {
      expect(
        index,
        contains('communityName: profile.displayName'),
        reason: 'a hozzászóló profilja már be van töltve a híváskor',
      );
    });
  });
}
