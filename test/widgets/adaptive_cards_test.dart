import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Fekvő (tablet) nézet:** a kártyák ne nőjenek óriásira.
///
/// A tulajdonos jelzései (2026-09-21, tableten, **kifejezetten fekvő nézetben**):
///
///  * *„tableten a kiemelt hírek a hírek tabon nagyon nagyok, olyannak kéne
///    lennie mint a többi hír kártyának"*;
///  * *„tableten a kvíz kártya is kurvanagy"*;
///  * *„álló nézetben okés a tablet, csak a fekvőre vonatkozik amit írtam"*.
///
/// A gyökér mindkettőnél ugyanaz: **széles nézetben a kártya a teljes szélességet
/// kitölti**, a hírkártya 16:9-es képe és a játék `fitWidth` borítója pedig az
/// eredeti képarányával együtt nő — egy 1200 px széles tableten ez 675 px magas
/// kép, azaz az egész képernyő.
///
/// A javítás **egy helyen** van (`AdaptiveNewsCard`), ezért a „Kiemelt hírek" sor
/// és a „Friss hírek" lista nem tud széthúzni — ez volt a hiba lényege: a friss
/// lista már kezelte a fekvő nézetet, a kiemelt sor nem.
void main() {
  group('a hírkártya fekvő nézetben (news_card.dart)', () {
    late String card;

    setUpAll(() {
      // ⚠️ A sorvég normalizálása: a fájlok egy része CRLF-fel van a lemezen, és a
      // többsoros minták különben hamisan nem illeszkednének.
      card = _read('lib/widgets/news_card.dart');
    });

    test('van EGY közös elhelyezés, ami a fekvő nézetet kezeli', () {
      expect(card, contains('class AdaptiveNewsCard'));
      expect(
        card,
        contains('Orientation.landscape'),
        reason: 'álló nézetben szándékosan nem változtatunk',
      );
      expect(
        card,
        contains('maxLandscapeWidth'),
        reason: 'fekvő nézetben a kártya legfeljebb 760 px széles',
      );
      expect(
        card,
        contains('compact: landscape'),
        reason: 'fekvő nézetben a sávos (kép balra, szöveg jobbra) kártya kell',
      );
    });
  });

  group('a hírek tab használja is ezt (news_screen.dart)', () {
    late String screen;

    setUpAll(() {
      screen = _read('lib/screens/news/news_screen.dart');
    });

    test('a „Kiemelt hírek" sor UGYANAZT a kártyát kapja, mint a friss lista', () {
      // ⚠️ Ez volt az éles hiba: a kiemelt sor a nyers `NewsCard`-ot rajzolta
      // (teljes szélesség, nagy kép), a friss lista viszont a fekvő nézetre
      // szabott változatot.
      expect(
        screen,
        contains('for (final post in stickyPosts)\n'
            '                                      AdaptiveNewsCard(post: post)'),
        reason: 'a kiemelt hírek is a közös, fekvő nézetet kezelő kártyát kapják',
      );
      expect(
        screen,
        contains('AdaptiveNewsCard(post: posts[postIndex])'),
        reason: 'a friss lista ugyanazt a kártyát használja',
      );
      // ⚠️ A `NewsCard(` szöveg **benne van** az `AdaptiveNewsCard(`-ban, ezért
      // darabszámot mérünk: minden előfordulás a közös, fekvő nézetet kezelő
      // változat legyen (külön, kezeletlen hívás ne maradjon).
      final adaptive = RegExp(r'AdaptiveNewsCard\(').allMatches(screen).length;
      final plain = RegExp(r'NewsCard\(').allMatches(screen).length;
      expect(
        adaptive,
        2,
        reason: 'a kiemelt sor és a friss lista is ezt használja',
      );
      expect(
        plain,
        adaptive,
        reason:
            'nincs külön `NewsCard(` hívás: két helyen lenne a szabály, és újra '
            'széthúznának (ez volt az éles hiba)',
      );
    });
  });

  group('a kvíz kártya fekvő nézetben (home_screen.dart)', () {
    late String home;

    setUpAll(() {
      home = _read('lib/screens/home/home_screen.dart');
    });

    test('a borító magassága fekvő nézetben korlátozott', () {
      final body = _functionBody(home, '_ActiveGameCard');
      expect(
        body,
        contains('Orientation.landscape'),
        reason: 'csak a fekvő nézet a hibás (az álló nézetet hagyjuk békén)',
      );
      expect(
        body,
        contains('maxHeight'),
        reason: 'a `fitWidth` kép különben az egész kártyát elvinné',
      );
      expect(
        body,
        contains('? 260'),
        reason: 'fekvő nézetben legfeljebb 260 px magas a borító',
      );
      expect(
        body,
        contains(': double.infinity'),
        reason: 'álló nézetben marad a korlátlan (változatlan) magasság',
      );
      expect(
        body,
        contains('BoxFit.cover'),
        reason: 'a korlátozott magasságban a kép kitölti a helyet (nem nyúlik)',
      );
      expect(
        body,
        isNot(contains('BoxFit.fitWidth')),
        reason: 'a `fitWidth` volt az óriási kártya okozója fekvő nézetben',
      );
    });
  });
}

/// Beolvas egy forrásfájlt **normalizált sorvéggel** (`\n`).
String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

/// Kiveszi egy Dart-metódus (vagy konstruktor utáni első metódus) törzsét.
///
/// A minta a **definícióra** illeszkedik, és a paraméterlistát átugorja — ezért a
/// `const _ActiveGameCard({required this.game});` konstruktor után a **következő**
/// metódus (`build`) törzsét adja vissza, ami pont a kártya felépítése.
String _functionBody(String source, String name) {
  final match = RegExp(
    '\\n\\s*(?!await\\b|unawaited\\b|return\\b|if\\b|while\\b|for\\b|switch\\b|assert\\b)'
    '[A-Za-z_][\\w<>, ?]*\\s${RegExp.escape(name)}\\(',
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'nincs ilyen tag: $name');
  final openParen = source.indexOf('(', match!.start);
  var parens = 0;
  var afterParams = -1;
  for (var i = openParen; i < source.length; i++) {
    final char = source[i];
    if (char == '(') parens++;
    if (char == ')') {
      parens--;
      if (parens == 0) {
        afterParams = i;
        break;
      }
    }
  }
  expect(afterParams, isNonNegative, reason: '$name paraméterlistája hibás');
  final open = source.indexOf('{', afterParams);
  expect(open, isNonNegative, reason: '$name törzse nem található');
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  fail('$name törzse nem záródik le');
}
