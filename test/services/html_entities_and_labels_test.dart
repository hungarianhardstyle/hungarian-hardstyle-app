import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/content/html_text.dart';
import 'package:hungarian_hardstyle_app/models/artist.dart';
import 'package:hungarian_hardstyle_app/models/organizer.dart';

/// A tulajdonos jelzései (2026-09-26) — **mind mérve**:
///
///  * *„Goze leírásában: Hardstyle producer &amp; … itt csak a kódolási hiba
///    van"*, *„Nu-Clear leírásában: szintén a &amp; kódolási hiba"* →
///    éles mérés (`tmp/probe-amp-entities.mjs`): a `/artists` válaszban a magyar
///    leírások **2/17**, az angolok **3/17** tartalmaz `&amp;`-t; a DJ- és
///    szervező-adatlap eddig **másodszor** escape-elte (a hír, az esemény és a
///    GYÍK már feloldotta).
///  * *„eseményeknél: Ismerőseid is jönnek:"*, *„Éves e-mail módosítási
///    lehetőség: 1 maradt"*, *„Zenénél: Reklámmal feloldva"*, *„Ismerősöknél: …
///    Ismerősök: 1"* → ezek **nyers** (interpolált) feliratok voltak, ezért
///    angol módban magyarul jelentek meg, és a szótár-kapu sem látta őket.
void main() {
  group('HTML-entitás a DJ- és szervező-leírásban (mért hiba)', () {
    test('a DJ-életrajz entitásai feloldódnak', () {
      final artist = Artist.fromJson({
        'id': 1,
        'title': 'Goze',
        'biography': 'Hardstyle producer &amp; Dj',
        'excerpt': 'Denoiser &amp; Adam Bass',
      });
      expect(artist.biography, 'Hardstyle producer & Dj');
      expect(artist.excerpt, 'Denoiser & Adam Bass');
    });

    test('a szervező leírása is feloldódik', () {
      final organizer = OrganizerProfile.fromJson({
        'id': 2,
        'title': 'Hard Base',
        'description': 'D-Block &amp; S-Te-Fan &amp; friends',
        'excerpt': 'Hardstyle &amp; Hardcore',
      });
      expect(organizer.description, 'D-Block & S-Te-Fan & friends');
      expect(organizer.excerpt, 'Hardstyle & Hardcore');
    });

    test('a HTML-tageket NEM bántja (a képernyő HTML-ként rajzolja)', () {
      final artist = Artist.fromJson({
        'id': 3,
        'title': 'X',
        'biography': '<p>Első &amp; második</p>',
      });
      expect(artist.biography, '<p>Első & második</p>');
    });

    test('a közös segéd a numerikus és a szöveges entitásokat is ismeri', () {
      expect(decodeHtmlEntities('a &amp; b'), 'a & b');
      expect(decodeHtmlEntities('&quot;idézet&quot;'), '"idézet"');
      expect(decodeHtmlEntities('&#039; &apos;'), "' '");
      expect(decodeHtmlEntities('&#x27;'), "'");
      expect(decodeHtmlEntities('&#8211;'), '–');
      expect(decodeHtmlEntities('&nbsp;x'), ' x');
      expect(decodeHtmlEntities('&lt;b&gt;'), '<b>');
      // Ami nem entitás, az bájtazonos marad (nincs felesleges kör).
      expect(decodeHtmlEntities('Hardstyle producer & Dj'), 'Hardstyle producer & Dj');
      expect(decodeHtmlEntities(''), '');
    });
  });

  group('forrás-lint: a nyers feliratok helyén kulcs + fordítás van', () {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    test('a jelentett helyeken nincs nyers, interpolált felirat', () {
      const expectations = <String, List<String>>{
        'lib/screens/events/event_detail_screen.dart': [
          "trArgs(\n                                                        context,\n                                                        'Ismerőseid is jönnek: {names}',",
        ],
        'lib/screens/community/community_screen.dart': [
          "'Éves névmódosítási lehetőség: {n} maradt'",
          "'Éves e-mail-módosítási lehetőség: {n} maradt'",
        ],
        'lib/screens/more/my_music_screen.dart': [
          "tr(context, 'Reklámmal feloldva')",
        ],
        'lib/screens/more/community_users_screen.dart': [
          "trArgs(context, 'Ismerősök: {n}'",
        ],
      };
      for (final entry in expectations.entries) {
        final source = read(entry.key);
        for (final needle in entry.value) {
          expect(source, contains(needle), reason: '${entry.key}: hiányzik');
        }
      }
      // A régi, nyers alakok egyike sem maradhat bent.
      final all = expectations.keys.map(read).join('\n');
      for (final raw in const [
        "'Ismerőseid is jönnek: \${names.join(', ')}'",
        "'Éves névmódosítási lehetőség: \${1 - _usernameChangesUsed} maradt'",
        "'Éves e-mail-módosítási lehetőség: \${1 - _emailChangesUsed} maradt'",
        "? 'Reklámmal feloldva'",
        "Text('Ismerősök: \${friends.length}')",
      ]) {
        expect(all, isNot(contains(raw)), reason: 'nyers alak maradt: $raw');
      }
    });

    test('az értesítés-fejléc kulcsot ad, és a szótárban ott a fordítás', () {
      final plan = read('lib/services/notification_selection_plan.dart');
      expect(plan, contains('String notificationSelectionKey(int count)'));
      expect(plan, contains("count <= 0 ? 'Jelölj ki értesítéseket' : 'Kijelölve: {n}'"));
      expect(plan, isNot(contains("'Kijelölve: \$count'")));

      final center = read('lib/screens/notifications/notification_center_screen.dart');
      expect(center, contains('notificationSelectionKey('));
      expect(center, contains('notificationDeletedKey('));

      final dictionary = jsonDecode(read('assets/i18n/en.json')) as Map<String, dynamic>;
      for (final key in const [
        'Jelölj ki értesítéseket',
        'Kijelölve: {n}',
        'Ismerősök: {n}',
        'Reklámmal feloldva',
        'Ismerőseid is jönnek: {names}',
        'Közös esemény: te és {names} is ott lesztek.',
        'Éves névmódosítási lehetőség: {n} maradt',
        'Éves e-mail-módosítási lehetőség: {n} maradt',
      ]) {
        expect(dictionary.containsKey(key), isTrue, reason: 'hiányzó kulcs: $key');
        expect(
          '${dictionary[key]}'.trim().isEmpty,
          isFalse,
          reason: 'üres fordítás: $key',
        );
      }
    });

    test('a pont-értesítés magyar sablonjában nincs szóismétlés', () {
      // ⚠️ A megjegyzéseket kiszűrjük: a javítás OKA kommentben is szerepel
      // („Új összösszpontszámod" volt) — a tiltás a **kódra** vonatkozik.
      final texts = read('functions/notification-texts.js').replaceAll(
        RegExp(r'^\s*//.*$', multiLine: true),
        '',
      );
      expect(texts, contains('Új összpontszámod: {points}'));
      expect(
        texts.contains('összösszpontszámod'),
        isFalse,
        reason: 'a tulajdonos jelzése: „ez a magyarnál javítandó"',
      );
    });
  });
}
