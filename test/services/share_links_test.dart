import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/services/share_links.dart';

/// A **megosztható tartalom-linkek** mérése (`lib/services/share_links.dart`).
///
/// A mérés tárgya a **szöveg**, amit a felhasználó ténylegesen elküld: tartalmazza-e
/// a címet, a linket és az app-hivatkozást; nem törik-e el hiányos adatnál; és a
/// szótárban **megvan-e** a záró sor fordítása.
void main() {
  setUp(() {
    AppStrings.setLanguage(AppLanguage.hu);
  });

  group('contentShareUrl', () {
    test('a kanonikus linket használja, ha van (hír, DJ)', () {
      expect(
        contentShareUrl(id: 12864, canonicalLink: 'https://hungarianhardstyle.hu/2026/09/26/cikk/'),
        'https://hungarianhardstyle.hu/2026/09/26/cikk/',
      );
    });

    test('kanonikus link nélkül a WordPress rövidlinkjét adja (esemény, kiadvány)', () {
      expect(contentShareUrl(id: 12505), 'https://hungarianhardstyle.hu/?p=12505');
      expect(contentShareUrl(id: 12699, canonicalLink: '   '), 'https://hungarianhardstyle.hu/?p=12699');
    });

    test('érvénytelen azonosítóval a weboldal gyökerére esik vissza (nem tippel)', () {
      expect(contentShareUrl(id: 0), siteBaseUrl);
      expect(contentShareUrl(id: -3), siteBaseUrl);
    });
  });

  group('buildShareMessage', () {
    test('a cím, a link és az app-sor is benne van', () {
      final message = buildShareMessage(
        title: 'Hard Bass 2026: elkészült a visszatérés himnusza',
        url: 'https://hungarianhardstyle.hu/?p=12864',
      );
      expect(message, contains('Hard Bass 2026'));
      expect(message, contains('https://hungarianhardstyle.hu/?p=12864'));
      expect(message, contains(playStoreUrl));
    });

    test('a sorok külön bekezdésbe kerülnek (a link kattintható legyen)', () {
      final message = buildShareMessage(title: 'Cím', url: 'https://pelda.hu/x');
      expect(message.split('\n\n').length, 3);
    });

    test('üres címmel sem törik el, és nem marad üres sor', () {
      final message = buildShareMessage(title: '   ', url: 'https://pelda.hu/x');
      expect(message.startsWith('https://pelda.hu/x'), isTrue);
      expect(message, contains(playStoreUrl));
      expect(message.contains('\n\n\n'), isFalse);
    });

    test('a felesleges szóközöket levágja', () {
      final message = buildShareMessage(title: '  Cím  ', url: '  https://pelda.hu/x  ');
      expect(message, contains('\n\nhttps://pelda.hu/x\n\n'));
    });
  });

  test('buildContentShareMessage a tartalom linkjét használja', () {
    final message = buildContentShareMessage(title: 'Buli', id: 12505);
    expect(message, contains('https://hungarianhardstyle.hu/?p=12505'));
    expect(message, contains('Buli'));
  });

  test('shareSubject: a cím a tárgy, üres címnél az app neve', () {
    expect(shareSubject('  Buli  '), 'Buli');
    expect(shareSubject('   '), 'Hungarian Hardstyle');
  });

  test('angol felületen az app-sor angolul szól (a szótárból)', () {
    // ⚠️ A szótárt a tesztnek KELL betöltenie (`AppStrings.setEnglish`): az app
    // induláskor tölti, tesztkörnyezetben viszont nincs mögötte asset-betöltés —
    // enélkül a „fordítás" hamisan magyar maradna (ez a mérés volt a hiba).
    final dictionary = jsonDecode(File('assets/i18n/en.json').readAsStringSync()) as Map<String, dynamic>;
    AppStrings.setEnglish(dictionary.map((key, value) => MapEntry(key, value.toString())));
    AppStrings.setLanguage(AppLanguage.en);
    final message = buildShareMessage(title: 'Event', url: 'https://pelda.hu/x');
    expect(message, contains('news, parties and DJs in one place'));
    expect(message, isNot(contains('hírek, bulik')));
  });

  test('a szótár tartalmazza a megosztott app-sort (magyar kulcs → angol érték)', () {
    final raw = File('assets/i18n/en.json').readAsStringSync();
    final dictionary = jsonDecode(raw) as Map<String, dynamic>;
    final translation = dictionary[shareAppLineKey] as String?;
    expect(translation, isNotNull, reason: 'hiányzik a(z) „$shareAppLineKey" kulcs az en.json-ból');
    expect(translation, contains('{store}'), reason: 'a helyőrzőnek meg kell maradnia');
  });

  test('forrás-lint: mind a négy adatlap kínál megosztást', () {
    const screens = {
      'lib/screens/news/news_detail_screen.dart': 'news',
      'lib/screens/events/event_detail_screen.dart': 'event',
      'lib/screens/releases/release_detail_screen.dart': 'release',
      'lib/screens/artists/artist_detail_screen.dart': 'artist',
    };
    for (final entry in screens.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(
        source.contains('ContentShareButton('),
        isTrue,
        reason: '${entry.key}: nincs megosztás gomb (${entry.value})',
      );
    }
    // ⚠️ A `Share.share(` hívás **egy helyen** él (`share_action.dart`): ha a
    // gomb létezik, de a tényleges megosztás eltűnik, ez a mérés bukik.
    final widget = File('lib/widgets/share_action.dart').readAsStringSync();
    expect(widget.contains('Share.share('), isTrue, reason: 'a megosztás hívása hiányzik');
    expect(widget.contains('buildContentShareMessage('), isTrue, reason: 'a szöveg-összeállítás hiányzik');
  });
}
