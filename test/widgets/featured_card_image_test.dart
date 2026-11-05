import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/adaptive_card_layout.dart';

/// **A kiemelt hír képe: a RÉGI kinézet** (build 407) — a tulajdonos döntése:
/// *„ne hari de így az app főoldal cikk kép kurvaszar, inkább legyen a régi vissza”*.
///
/// A 405-ben a kép elmosott háttér előtt, teljes egészében (`contain`) látszott;
/// ez **nem tetszett**, ezért visszaállt a régi, egyszerű `BoxFit.cover`.
///
/// ⚠️ Ez a mérés a **visszaállítást** védi: ha valaki újra beemelné az elmosott
/// hátteret vagy a `contain`-t, a kapu pirosra vált. Emellett a geometria továbbra
/// is mérve van (a sáv 149×250 px, a borítókép 1200×630 → a kép 31%-a látszik),
/// hogy a döntés **tudatos** legyen, ne véletlen.
void main() {
  final source = File('lib/widgets/featured_news_card.dart').readAsStringSync();

  group('a kiemelt hír képe a régi kinézetet használja (cover)', () {
    test('a kártya `BoxFit.cover`-rel rajzolja a képet', () {
      expect(source.contains('fit: BoxFit.cover'), isTrue);
      expect(source.contains('ResizedNetworkImage('), isTrue);
    });

    test('NINCS elmosott háttér és NINCS contain (a 405-ös kísérlet kikerült)', () {
      expect(source.contains('ImageFiltered'), isFalse,
          reason: 'az elmosott háttér a 405-ben volt, a tulajdonos visszakérte a régit');
      expect(source.contains('BoxFit.contain'), isFalse);
      expect(source.contains('FeaturedNewsImageBand'), isFalse);
      expect(source.contains("import 'dart:ui'"), isFalse);
    });

    test('a kártya szerkezete változatlan (kép balra, szöveg jobbra)', () {
      expect(source.contains('flex: 5'), isTrue);
      expect(source.contains('flex: 7'), isTrue);
      expect(source.contains('Hero('), isTrue);
    });

    test('a geometria mérve van: a keskeny sávban a kép ~31%-a látszik', () {
      // A kártya 358×250 px, a képsáv 149×250 px, a borítókép 1200×630 (1,90).
      final visible = coverVisibleFraction(
        boxWidth: 149,
        boxHeight: 250,
        imageAspectRatio: 1200 / 630,
      );
      expect(visible, closeTo(0.313, 0.01));
      expect(visible, lessThan(0.5),
          reason: 'ezért tűnik nagyítottnak a kép — tudatos döntés, hogy így marad');
    });
  });
}
