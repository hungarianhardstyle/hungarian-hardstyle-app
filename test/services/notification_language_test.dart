import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/core/i18n/notification_texts.dart';

/// Az **értesítések** nyelve — a tulajdonos jelzése (2026-09-26):
/// *„a notifyok még mindig magyarul vannak az angol felületen vagy lassan áll
/// át"* → *„ja lassan áll át"* → *„nagyon lassan"*.
///
/// **A MÉRT GYÖKÉR:** a szerver az értesítés szövegét a **létrehozáskor**
/// rendereli a címzett akkori nyelvén (`createNotification` →
/// `recipientLanguage`), és a Firestore-ba **kész szöveget** ír. Ezért a
/// nyelvváltás után a **régi** sorok a régi nyelven maradtak, és csak az **új**
/// értesítések jöttek az új nyelven — ez a „nagyon lassú átállás".
///
/// **A MEGOLDÁS:** a megjelenítés helyén fordítunk: a tárolt szöveg a katalógus
/// egyik nyelvű sablonjából készült, ezért a másik nyelv sablonjával kinyerjük a
/// helyőrzőket, és a mostani nyelven újra kitöltjük. A katalógus a
/// szerveroldali `functions/notification-texts.js`-ből generált
/// `assets/i18n/notification_texts.json` (a `--check` kapu az elcsúszást jelzi).
void main() {
  final catalogText = File(
    'assets/i18n/notification_texts.json',
  ).readAsStringSync();

  setUp(() {
    AppStrings.setLanguage(AppLanguage.hu);
    NotificationTexts.setCatalogFromJson(catalogText);
  });

  tearDown(() {
    AppStrings.setLanguage(AppLanguage.hu);
    NotificationTexts.setCatalog(null);
  });

  group('a katalógus rendben van', () {
    test('a szerveroldali forrásból generált katalógus betölthető', () {
      expect(NotificationTexts.isLoaded, isTrue);

      final catalog = jsonDecode(catalogText) as Map<String, dynamic>;
      final kinds = (catalog['kinds'] as Map).keys.toList();
      expect(kinds.length, greaterThanOrEqualTo(30));

      for (final kind in kinds) {
        final entry = (catalog['kinds'] as Map)[kind] as Map;
        for (final language in ['hu', 'en']) {
          final byLanguage = entry[language] as Map?;
          expect(byLanguage, isNotNull, reason: '$kind: hiányzik a $language változat');
          expect(
            '${byLanguage!['body'] ?? ''}'.trim(),
            isNotEmpty,
            reason: '$kind ($language): üres a törzs',
          );
        }
      }
    });

    test('a kliens által használt típusok mind benne vannak', () {
      final catalog = jsonDecode(catalogText) as Map<String, dynamic>;
      final kinds = (catalog['kinds'] as Map).keys.toSet();
      for (final kind in [
        'chat_reaction',
        'chat_reply',
        'chat_mention',
        'chat_everyone',
        'new_news',
        'new_release',
        'new_artist',
        'new_event',
        'prize_winner',
        'connection_request',
        'meetup_interest',
        'achievement_points',
        'achievement_points_level',
        'article_comment',
        'article_comment_reply',
        'private_message',
      ]) {
        expect(kinds.contains(kind), isTrue, reason: 'hiányzik: $kind');
      }
    });
  });

  group('a tárolt értesítés a MOSTANI nyelven jelenik meg', () {
    test('magyarul tárolt szöveg angol felületen angolul szól', () {
      AppStrings.setLanguage(AppLanguage.en);
      final text = NotificationTexts.localize(
        type: 'chat_reaction',
        title: 'Kedvelték a Chat-üzenetedet',
        body: 'Teszt Felhasználó kedvelte a Chat-üzenetedet.',
      );

      expect(text.title, 'Your Chat message was liked');
      expect(text.body, 'Teszt Felhasználó liked your Chat message.');
    });

    test('angolul tárolt szöveg magyar felületen magyarul szól', () {
      AppStrings.setLanguage(AppLanguage.hu);
      final text = NotificationTexts.localize(
        type: 'chat_reaction',
        title: 'Your Chat message was liked',
        body: 'Teszt Felhasználó liked your Chat message.',
      );

      expect(text.title, 'Kedvelték a Chat-üzenetedet');
      expect(text.body, 'Teszt Felhasználó kedvelte a Chat-üzenetedet.');
    });

    test('a helyőrző értéke (idézet, név, szám) VÁLTOZATLAN marad', () {
      AppStrings.setLanguage(AppLanguage.en);
      final mention = NotificationTexts.localize(
        type: 'chat_mention',
        title: 'Megemlítettek a Chatben',
        body: 'Teszt Felhasználó megemlített a Chatben: „Szia, ott leszel?”',
      );
      expect(
        mention.body,
        'Teszt Felhasználó mentioned you in the Chat: “Szia, ott leszel?”',
      );

      final points = NotificationTexts.localize(
        type: 'achievement_points',
        title: '+20 achievement pont',
        body: '+20 pont egy hír kedveléséért. Új összösszpontszámod: 540.',
      );
      expect(points.title, '+20 achievement points');
      expect(
        points.body,
        '+20 points for liking a news article. Your new total is 540.',
      );
    });

    test('a már a mostani nyelven tárolt szöveg változatlan (nincs dupla fordítás)', () {
      AppStrings.setLanguage(AppLanguage.en);
      final text = NotificationTexts.localize(
        type: 'chat_reply',
        title: 'Someone replied to your Chat message',
        body: 'Teszt Felhasználó replied to your Chat message.',
      );

      expect(text.title, 'Someone replied to your Chat message');
      expect(text.body, 'Teszt Felhasználó replied to your Chat message.');
    });

    test('az ADAT (cikk címe, név) nem fordul le — csak a sablon szövege', () {
      AppStrings.setLanguage(AppLanguage.en);
      final news = NotificationTexts.localize(
        type: 'new_news',
        title: 'Új hír érkezett',
        body: 'Hardstyle találkozó Budapesten',
      );

      expect(news.title, 'New article');
      // A törzs maga az adat: marad, ahogy a szerkesztő megírta.
      expect(news.body, 'Hardstyle találkozó Budapesten');
    });

    test('ismeretlen vagy egyedi szöveg változatlanul megy ki (nem tippelünk)', () {
      AppStrings.setLanguage(AppLanguage.en);
      final unknown = NotificationTexts.localize(
        type: 'general',
        title: 'Valami egyedi',
        body: 'Kézzel írt szöveg',
      );
      expect(unknown.title, 'Valami egyedi');
      expect(unknown.body, 'Kézzel írt szöveg');

      final custom = NotificationTexts.localize(
        type: 'chat_reaction',
        title: 'Egészen más cím',
        body: 'Egészen más törzs',
      );
      expect(custom.title, 'Egészen más cím');
      expect(custom.body, 'Egészen más törzs');
    });

    test('a privát üzenet címe is fordul (a küldő nevével)', () {
      AppStrings.setLanguage(AppLanguage.en);
      final text = NotificationTexts.localize(
        type: 'private_message',
        title: 'Teszt Felhasználó üzenetet küldött',
        body: 'Szia, találkozunk szombaton?',
      );

      expect(text.title, 'Teszt Felhasználó sent you a message');
      expect(text.body, 'Szia, találkozunk szombaton?');
    });

    test('üres tárolt szöveg nem lesz se több, se kevesebb', () {
      AppStrings.setLanguage(AppLanguage.en);
      final text = NotificationTexts.localize(
        type: 'achievement_reason_news_like',
        title: '',
        body: '',
      );
      expect(text.title, '');
      expect(text.body, '');
    });
  });

  group('FORRÁS-LINT: a felület a fordítón át ír ki', () {
    test('a NotificationCenter a katalógussal fordít, és nincs nyers ág', () {
      // ⚠️ A **megjegyzéseket** előbb kivesszük: a magyarázó sorok a `Text(` és a
      // fordított érték KÖZÖTT állnak, ezért a naiv minta nem illeszkedne (ez a
      // saját mérőeszközöm hibája volt — a minta a kódra szól, nem a szövegre).
      final screen = File(
        'lib/screens/notifications/notification_center_screen.dart',
      ).readAsStringSync().replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

      expect(screen.contains('NotificationTexts.localize('), isTrue);
      // A megjelenítés a FORDÍTOTT értéket használja (a cím és a törzs is)…
      expect(
        RegExp(r'Text\(\s*localized\.body').hasMatch(screen),
        isTrue,
        reason: 'a törzs a fordított értékkel jelenik meg',
      );
      expect(RegExp(r'Text\(\s*localized\.title').hasMatch(screen), isTrue);
      // …és SEHOL nem írja ki nyersen a tárolt szöveget.
      expect(
        RegExp(r'Text\(\s*item\.body').hasMatch(screen),
        isFalse,
        reason: 'a törzs nyersen ment ki — pont ez maradt magyarul',
      );
      expect(
        RegExp(r'Text\(\s*item\.title').hasMatch(screen),
        isFalse,
        reason: 'a cím nyersen ment ki — pont ez maradt magyarul',
      );
      expect(
        screen.contains("archived ? 'Archivált értesítések törlése'"),
        isFalse,
        reason: 'a nyers ternary-ág angol felületen magyarul maradt',
      );
      expect(screen.contains("'Archivált értesítések törlése'"), isTrue);
      expect(
        screen.contains(r"üzenetet küldött|sent you a message"),
        isTrue,
        reason: 'a küldő nevének levágása mindkét nyelvű utótagra működik',
      );
    });

    test('az értesítés-katalógus be van töltve induláskor', () {
      final provider = File(
        'lib/providers/language_provider.dart',
      ).readAsStringSync();
      expect(provider.contains('NotificationTexts.setCatalogFromJson('), isTrue);
      expect(provider.contains('NotificationTexts.asset'), isTrue);
    });
  });
}
