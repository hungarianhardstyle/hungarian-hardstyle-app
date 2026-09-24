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
