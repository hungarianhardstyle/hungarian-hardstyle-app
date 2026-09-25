import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Forrás-lint: a Chat-`@`hivatkozás (mention) **bekötése**.
///
/// A tulajdonos kérése (2026-09-24): *„Kéne olyan, hogy egy @xy betűvel tudjak
/// hivatkozni a chaten cikkre, djre, szervezőre, eseményre, kiadványra vagy
/// személyre/userre … Elkezdem irni a betűket és dobja fel a lehetőségeket. A
/// személyre/userre hivatkozás legyen elérhető mindenkinek, többi csak
/// admin/moderátornak. Természetesen mindegyik kattintható legyen és a megfelelő
/// helyre vigyen."*
///
/// A tiszta szabályok (`chat_mention_plan.dart`) külön teszteltek; ez a fájl a
/// **bekötést** őrzi — a 351-es tanulság szerint a szabály lehet helyes, a
/// bekötés hibás. Külön figyelmet kap a **közös** célpont-feloldó, mert pont az
/// a hiba-osztály (az értesítés és a hivatkozás széthúz), amit a 351-es kör
/// feltárt.
void main() {
  String readFile(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  group('forrás-lint: a hivatkozások elküldése a szervernek', () {
    late String service;

    setUpAll(() {
      service = readFile('lib/services/community_service.dart');
    });

    test('a publishPost elfogadja a mentions listát (a replyTo minta szerint)', () {
      expect(
        service,
        contains(
          'List<Map<String, Object>> mentions = const <Map<String, Object>>[]',
        ),
        reason: 'a hívó akkor is működik, ha nincs hivatkozás',
      );
      expect(
        service.indexOf('String? replyToAuthorId,'),
        lessThan(service.indexOf('List<Map<String, Object>> mentions')),
        reason: 'a meglévő paraméter-minta folytatása, nem új útvonal',
      );
    });

    test('a mentions CSAK akkor kerül a callable paraméterei közé, ha van', () {
      final callIndex = service.indexOf("'publishChatPost'");
      final mentionsIndex = service.indexOf("'mentions': mentions");
      expect(callIndex, greaterThan(0));
      expect(
        mentionsIndex,
        greaterThan(callIndex),
        reason: 'a hivatkozás a publishChatPost hívás paraméterei között van',
      );
      expect(service, contains("if (mentions.isNotEmpty) 'mentions': mentions"));
    });

    test('a szerver visszajelzését (droppedMentions) a hívó megkapja', () {
      expect(service, contains('Future<int> publishPost('));
      expect(service, contains("data['droppedMentions']"));
      expect(
        service,
        isNot(contains("callFirebaseCallable<void>(\n      'publishChatPost'")),
        reason: 'a hívás nem void: a kihagyottak száma visszajön',
      );
    });
  });

  group('forrás-lint: a Chat képernyő @javaslatai', () {
    late String chat;

    setUpAll(() {
      chat = readFile('lib/screens/community/community_screen.dart');
    });

    test('a tiszta modul függvényeit használja (nem saját szabályt)', () {
      expect(chat, contains("import '../../services/chat_mention_plan.dart';"));
      expect(chat, contains('activeMentionQuery('));
      expect(chat, contains('insertMention('));
      expect(chat, contains('mentionSuggestions('));
      expect(chat, contains('mentionSpans('));
    });

    test('a beviteli mező változására indul (gépelés ÉS kurzor)', () {
      expect(chat, contains('_textController.addListener(_onComposerChanged)'));
      expect(
        chat,
        contains('_textController.removeListener(_onComposerChanged)'),
        reason: 'a listener nem szivároghat ki a képernyő eldobása után',
      );
      expect(chat, contains('activeMentionQuery(_textController.text, caret)'));
    });

    test('a kiválasztás a szöveget ÉS a kurzort is visszaírja', () {
      expect(chat, contains('_textController.value = TextEditingValue('));
      expect(
        chat,
        contains('selection: TextSelection.collapsed(offset: insertion.caret)'),
        reason: 'a kurzor a beszúrt név után marad',
      );
    });

    test('ugyanaz a célpont nem kerülhet be kétszer', () {
      expect(chat, contains("final key = '\${target.type}:\${target.id}';"));
      expect(chat, contains('if (!already) _mentions.add(target);'));
    });

    test('a küldés csak a szövegben TÉNYLEG benne lévő hivatkozásokat adja át', () {
      expect(chat, contains('_activeMentions()'));
      expect(
        chat,
        contains('mentionSpans(_textController.text, _mentions)'),
        reason: 'a visszatörölt @név nem küld felesleges hivatkozást',
      );
      expect(chat, contains('mentions: mentions'));
      expect(
        chat,
        contains('_mentions.clear()'),
        reason: 'sikeres küldés után nem szivárog át a következő üzenetbe',
      );
    });

    test('a kihagyott hivatkozásokat (droppedMentions) jelzi', () {
      expect(chat, contains('if (dropped > 0)'));
      expect(
        chat,
        contains('Néhány hivatkozás nem kattintható'),
        reason: 'a tulajdonos kérése: jelezze, ha valami nem kattintható',
      );
      expect(chat, contains('_showMessage('));
    });
  });

  group('forrás-lint: tartalom-javaslat CSAK adminnak/moderátornak', () {
    late String chat;

    setUpAll(() {
      chat = readFile('lib/screens/community/community_screen.dart');
    });

    test('a személy-javaslat mindenkinek töltődik', () {
      expect(chat, contains('mentionUserSuggestions()'));
      expect(chat, contains('import \'../../services/chat_mention_source.dart\';'));
    });

    test('a tartalom-javaslat a mentionPrivileged kapu MÖGÖTT töltődik', () {
      final guardIndex = chat.indexOf('if (!mentionPrivileged(_mentionAccessRole)) return;');
      final contentIndex = chat.indexOf('mentionContentSuggestions()');
      expect(guardIndex, greaterThan(0), reason: 'a kapu ott van a forrásban');
      expect(contentIndex, greaterThan(guardIndex));
    });

    test('a javaslatok egyszer töltődnek (nem minden leütésre hálózat)', () {
      expect(chat, contains('_mentionDataRequested'));
      expect(chat, contains('if (_mentionDataRequested) return;'));
      expect(chat, contains('_mentionDataRequested = true;'));
    });

    test('a szűrés a cache-elt listákból megy', () {
      expect(
        chat.indexOf('await _ensureMentionData();'),
        lessThan(chat.indexOf('_mentionSuggestions = mentionSuggestions(')),
        reason: 'előbb az adat, aztán a szűrés',
      );
      expect(chat, contains('privileged: mentionPrivileged('));
    });
  });

  group('forrás-lint: a megjelenítés (kattintható hivatkozások)', () {
    late String chat;
    late String messageText;
    late String overlay;

    setUpAll(() {
      chat = readFile('lib/screens/community/community_screen.dart');
      messageText = readFile('lib/widgets/chat_message_text.dart');
      overlay = readFile('lib/widgets/chat_mention_overlay.dart');
    });

    test('a kártya a ChatMessageText-et rajzolja (nem sima Text-et)', () {
      expect(chat, contains('ChatMessageText('));
      expect(
        chat,
        isNot(contains('Text(post.text)')),
        reason: 'a régi, nem kattintható megjelenítés nem maradhat bent',
      );
      expect(chat, contains('mentions: post.mentions'));
    });

    test('a szöveg-widget a mentionSpans-re épül', () {
      expect(
        messageText,
        contains("import '../services/chat_mention_plan.dart';"),
      );
      expect(messageText, contains('mentionSpans(widget.text, widget.mentions)'));
      expect(messageText, contains('Text.rich('));
      expect(
        messageText,
        contains('if (_spans.isEmpty) return Text(widget.text'),
        reason: 'hivatkozás nélkül bitre ugyanaz, mint eddig',
      );
    });

    test('a TapGestureRecognizer-eket ELDOBJA (nincs erőforrás-szivárgás)', () {
      expect(messageText, contains('TapGestureRecognizer'));
      expect(messageText, contains('void dispose()'));
      expect(messageText, contains('_disposeRecognizers()'));
      expect(
        messageText.indexOf('_disposeRecognizers();\n    super.dispose();'),
        greaterThan(0),
        reason: 'a dispose a felismerők bezárásával kezdődik',
      );
    });

    test('a javaslatlista csoportosított, és üresen nem rajzol semmit', () {
      expect(overlay, contains("Key('chat-mention-overlay')"));
      expect(overlay, contains('mentionTypeLabel(type)'));
      expect(overlay, contains('if (suggestions.isEmpty) return const SizedBox.shrink();'));
      expect(overlay, contains('onSelected(suggestion)'));
      expect(
        chat,
        contains('ChatMentionOverlay('),
        reason: 'a beviteli mező fölött rajzolódik ki',
      );
    });
  });

  group('forrás-lint: KÖZÖS célpont-feloldó (a 351-es tanulság)', () {
    late String center;
    late String chat;
    late String target;

    setUpAll(() {
      center = readFile('lib/screens/notifications/notification_center_screen.dart');
      chat = readFile('lib/screens/community/community_screen.dart');
      target = readFile('lib/core/navigation/content_target.dart');
    });

    test('a közös függvény mind a hat célpontot ismeri', () {
      for (final type in const [
        "'profile'",
        "'user'",
        "'news'",
        "'article'",
        "'event'",
        "'release'",
        "'artist'",
        "'organizer'",
      ]) {
        expect(target, contains('case $type:'), reason: 'hiányzó ág: $type');
      }
      expect(target, contains('Future<bool> openContentTarget('));
    });

    test('a közös függvény ugyanazokat a képernyőket nyitja', () {
      for (final screen in const [
        'CommunityPublicProfileScreen(',
        'NewsDetailScreen(',
        'EventDetailScreen(',
        'ReleaseDetailScreen(',
        'ArtistDetailScreen(',
        'OrganizerDetailScreen(',
      ]) {
        expect(target, contains(screen), reason: 'hiányzó cél: $screen');
      }
    });

    test('az értesítés-központ ezt hívja, és NEM maradt benne másolt ág', () {
      expect(
        center,
        contains("import '../../core/navigation/content_target.dart';"),
      );
      expect(center, contains('await openContentTarget('));
      for (final screen in const [
        'NewsDetailScreen(',
        'EventDetailScreen(',
        'ReleaseDetailScreen(',
        'ArtistDetailScreen(',
        'OrganizerDetailScreen(',
      ]) {
        expect(
          center,
          isNot(contains(screen)),
          reason: 'a másolt ág ($screen) nem maradhat a központban',
        );
      }
    });

    test('a mention-koppintás UGYANEZT hívja', () {
      expect(
        chat,
        contains("import '../../core/navigation/content_target.dart';"),
      );
      expect(chat, contains('await openContentTarget('));
      expect(chat, contains('_openMention('));
      expect(chat, contains('onTap: _openMention'));
    });

    test('a Chat-saját ágak (chat, jelentés, privát) a központban maradnak', () {
      expect(center, contains("notification.targetType == 'chat'"));
      expect(center, contains("notification.targetType == 'chat_report'"));
      expect(center, contains("notification.targetType == 'private_conversation'"));
      expect(center, contains("notification.targetType == 'achievement'"));
    });
  });

  group('forrás-lint: a modell ismeri a hivatkozásokat', () {
    test('a CommunityPost feldolgozza a mentions mezőt', () {
      final post = readFile('lib/models/community_post.dart');
      expect(post, contains('final List<ChatMentionTarget> mentions;'));
      expect(post, contains("ChatMentionTarget.listFrom(data['mentions'])"));
      expect(
        post,
        contains("import '../services/chat_mention_plan.dart';"),
        reason: 'a feldolgozás a tiszta modulban van (hibás elem kimarad)',
      );
    });
  });

  // ⚠️ A tulajdonos kérése (2026-09-25): *„kéne egy @mindenki tag is, amit ha
  // beütök, kap mindenki notifyt és csak moderátor/admin használhassa"*.
  group('forrás-lint: a @mindenki bekötése', () {
    late String plan;
    late String chat;
    late String target;
    late String messageText;
    late String center;

    setUpAll(() {
      plan = readFile('lib/services/chat_mention_plan.dart');
      chat = readFile('lib/screens/community/community_screen.dart');
      target = readFile('lib/core/navigation/content_target.dart');
      messageText = readFile('lib/widgets/chat_message_text.dart');
      center = readFile('lib/screens/notifications/notification_center_screen.dart');
    });

    test('a konstansok egy helyen vannak (kliens és szerver ne széthúzzon)', () {
      expect(plan, contains("const String mentionTypeEveryone = 'everyone';"));
      expect(plan, contains("const String mentionEveryoneId = 'everyone';"));
      expect(plan, contains("const String mentionEveryoneLabel = 'mindenki';"));
      expect(
        plan,
        contains("case mentionTypeEveryone:"),
        reason: 'a csoportfejléc is kap magyar címkét (Mindenki)',
      );
    });

    test('a javaslat CSAK adminnak/moderátornak jön (és csak gépelésre)', () {
      expect(
        plan,
        matches(
          RegExp(
            r'if \(privileged &&[\s\S]{0,80}?needle\.isNotEmpty &&[\s\S]{0,80}?mentionEveryoneLabel\.startsWith\(needle\)\)',
          ),
        ),
        reason:
            'üres lekérdezésnél nem ajánljuk fel (véletlen koppintás mindenkinek küldene)',
      );
    });

    test('a koppintás nem indul el a @mindenkinál (nincs mögötte adatlap)', () {
      expect(
        target,
        contains("if (type == 'everyone') return false;"),
        reason: 'a közös feloldó némán visszatér, nem navigál',
      );
      expect(
        chat,
        matches(
          RegExp(
            r'if \(target\.type == mentionTypeEveryone\) return;[\s\S]{0,120}?openContentTarget\(',
          ),
        ),
        reason: 'a Chat biztonsági hálója a feloldás ELŐTT áll',
      );
      expect(
        messageText,
        contains('if (target.type == mentionTypeEveryone)'),
        reason: 'a szövegben a @mindenki nem kap koppintás-felismerőt',
      );
    });

    test('az értesítés-központ nem kap külön @mindenki-ágat', () {
      expect(
        center,
        isNot(contains('mentionTypeEveryone')),
        reason:
            'a @mindenki értesítés `targetType: chat` (a szerver küldi), ezért a központban nincs külön ág',
      );
    });
  });
}
