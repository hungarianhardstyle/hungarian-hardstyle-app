import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/radio_metadata.dart';

/// A rádió „most szól" metaadatának mérése — **hálózat nélkül**.
///
/// ⚠️ A minta NEM kitalált: a 2026-10-01-i éles mérésből származik
/// (`node tmp/probe-radio-icy.mjs`, `https://stream.realhardstyle.nl`):
/// `icy-metaint: 16384`, blokk:
/// `StreamTitle='LNY TNZ & Nyanda - Light Up Your Life';StreamNext='Rogue Zero - Walk Away';`
void main() {
  /// A mért blokk bájtjai az `icy-metaint` pozícióra helyezve.
  List<int> streamBytes(String block, {int metaint = 16384}) {
    // ⚠️ Növelhető lista kell: a `List.filled` alapból fix hosszúságú, és a
    // hozzáfűzés „Cannot add to a fixed-length list” hibát ad (ezt a kapu fogta
    // meg az első futásban).
    final bytes = List<int>.filled(metaint, 0x41, growable: true); // „hang” helyőrző
    final text = utf8.encode(block);
    // A hossz-bájt 16 bájtos egységekben méri a szöveget.
    final units = ((text.length + 15) ~/ 16) * 16;
    bytes.add(units ~/ 16);
    bytes.addAll(text);
    bytes.addAll(List<int>.filled(units - text.length, 0));
    return bytes;
  }

  group('az icy-metaint fejléc', () {
    test('a mért értéket kiolvassa', () {
      expect(icyMetaIntFrom('16384'), 16384);
    });

    test('hiányzó vagy hibás értékre null (nem tippelünk)', () {
      expect(icyMetaIntFrom(null), isNull);
      expect(icyMetaIntFrom(''), isNull);
      expect(icyMetaIntFrom('nem-szam'), isNull);
      expect(icyMetaIntFrom('0'), isNull);
      expect(icyMetaIntFrom('-5'), isNull);
    });
  });

  group('a metaadat-blokk', () {
    test('az ÉLES blokkot pontosan értelmezi (cím + következő)', () {
      const block =
          "StreamTitle='LNY TNZ & Nyanda - Light Up Your Life';StreamNext='Rogue Zero - Walk Away';";
      final metadata = parseIcyMetadata(block);
      expect(metadata.title, 'LNY TNZ & Nyanda - Light Up Your Life');
      expect(metadata.next, 'Rogue Zero - Walk Away');
      expect(metadata.isNotEmpty, isTrue);
    });

    test('a bájtokból a mért metaint mellett ugyanez jön ki', () {
      const block = "StreamTitle='Sub Zero Project - The Project';";
      final bytes = streamBytes(block);
      final decoded = decodeIcyBlock(bytes, 16384);
      expect(parseIcyMetadata(decoded).title, 'Sub Zero Project - The Project');
    });

    test('a nulla-bájtos feltöltés nem kerül a címbe', () {
      const block = "StreamTitle='D-Block & S-te-Fan';";
      final bytes = streamBytes(block);
      final title = parseIcyMetadata(decodeIcyBlock(bytes, 16384)).title;
      expect(title, 'D-Block & S-te-Fan');
      expect(title.contains('\u0000'), isFalse);
    });

    test('a MAGYAR ékezet UTF-8-ként helyesen jön ki', () {
      const block = "StreamTitle='Következő állomás — Ősz';";
      final bytes = streamBytes(block);
      expect(
        parseIcyMetadata(decodeIcyBlock(bytes, 16384)).title,
        'Következő állomás — Ősz',
      );
    });

    test('a latin1-es (régi Shoutcast) ékezet is működik', () {
      // 0xE9 = „é” latin1-ben — UTF-8-ként értelmezhetetlen, ezért a tartalék ág.
      final text = <int>[...utf8.encode("StreamTitle='Caf"), 0xE9, ...utf8.encode("';")];
      final bytes = <int>[...List<int>.filled(64, 0x41), (text.length / 16).ceil(), ...text];
      final block = decodeIcyBlock(bytes, 64);
      expect(parseIcyMetadata(block).title, 'Café');
    });

    test('üres blokk (a rádió nem küld címet) → üres metaadat', () {
      final bytes = <int>[...List<int>.filled(100, 0x41), 0];
      expect(decodeIcyBlock(bytes, 100), '');
      expect(parseIcyMetadata(decodeIcyBlock(bytes, 100)).isEmpty, isTrue);
    });

    test('rövid puffer nem dob és nem tippel', () {
      expect(decodeIcyBlock(<int>[1, 2, 3], 16384), '');
      expect(decodeIcyBlock(<int>[], 0), '');
    });

    test('a csonka blokk a rendelkezésre álló részt adja vissza', () {
      // A hossz-bájt 4 egységet (64 bájtot) ígér, de csak 10 bájt jön.
      final bytes = <int>[...List<int>.filled(32, 0x41), 4, ...utf8.encode('abc')];
      final block = decodeIcyBlock(bytes, 32);
      expect(block, startsWith('abc'));
      expect(block.length, lessThanOrEqualTo(10));
    });
  });

  group('a metaadat-objektum', () {
    test('az üresség csak a címen múlik (a „következő” lehet üres)', () {
      expect(const RadioMetadata(title: 'X').isNotEmpty, isTrue);
      expect(const RadioMetadata(next: 'X').isEmpty, isTrue);
    });

    test('a szöveges alak a címeket mutatja', () {
      expect(
        const RadioMetadata(title: 'A', next: 'B').toString(),
        'RadioMetadata(title: "A", next: "B")',
      );
    });
  });
}
