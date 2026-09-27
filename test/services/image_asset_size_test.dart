import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **A beépített képek felbontása** — a Play „bittérkép-optimalizálás" javaslata.
///
/// A MÉRÉS (2026-09-27, `tmp/probe-image-dimensions.mjs` és
/// `tmp/probe-play-suggestions.mjs`): a csomagolt képek **1254×1254** (a
/// navigációs ikonok, amelyek **34 logikai képponton** látszanak!), illetve
/// 1640×856 … 2460×780 felbontásban voltak — **59 MB dekódolt
/// bittérkép-memória** a csomagban, miközben a legnagyobb valódi megjelenítés
/// ~400 logikai képpont.
///
/// A javítás (`tools/optimize-app-images.mjs`) **kicsinyít** (nem vág), így a
/// kép aránya és kinézete nem változik: **4.57 MB → 0.32 MB** fájlméret és
/// **59.2 MB → 4.7 MB** dekódolt memória.
///
/// Ez a kapu azt akadályozza meg, hogy egy jövőbeli kör **visszategyen** egy
/// nagy felbontású képet: minden beépített kép felbontását és a belőle
/// számolható memóriát méri.
void main() {
  /// PNG fejléc: szélesség/magasság a 16. bájttól (big-endian).
  ({int width, int height})? pngSize(File file) {
    final bytes = file.readAsBytesSync();
    if (bytes.length < 24) return null;
    if (bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4e || bytes[3] != 0x47) {
      return null;
    }
    int readUint32(int offset) =>
        (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
    return (width: readUint32(16), height: readUint32(20));
  }

  /// A **bundled** képek (a `pubspec.yaml` csak az `assets/logos/` és az
  /// `assets/images/` könyvtárat csomagolja — az `assets/icons/` a launcher-ikon
  /// forrása, az **nincs** a csomagban).
  List<File> bundledImages() => [
    ...Directory('assets/images').listSync().whereType<File>(),
    ...Directory('assets/logos').listSync().whereType<File>(),
  ].where((file) => file.path.toLowerCase().endsWith('.png')).toList();

  test('a navigációs ikonok legfeljebb 256×256 képpontosak', () {
    // A `main_navigation.dart` ezeket **34 logikai képponton** rajzolja; 176 px
    // (a mostani méret) ötszörös tartalék — a 256 a plafon.
    for (final file in Directory('assets/images').listSync().whereType<File>()) {
      if (!file.path.toLowerCase().endsWith('.png')) continue;
      final size = pngSize(file);
      expect(size, isNotNull, reason: '${file.path}: nem olvasható PNG');
      expect(
        size!.width <= 256 && size.height <= 256,
        isTrue,
        reason: '${file.path}: ${size.width}×${size.height} — 34 dp-hez túl nagy',
      );
    }
  });

  test('a logók legfeljebb 1200 képpont szélesek', () {
    for (final file in Directory('assets/logos').listSync().whereType<File>()) {
      if (!file.path.toLowerCase().endsWith('.png')) continue;
      final size = pngSize(file);
      expect(size, isNotNull, reason: '${file.path}: nem olvasható PNG');
      expect(
        size!.width <= 1200,
        isTrue,
        reason: '${file.path}: ${size.width}×${size.height} — a legnagyobb '
            'megjelenítés ~0.82 × képernyőszélesség',
      );
    }
  });

  test('a dekódolt bittérkép-memória a csomagban 8 MB alatt van', () {
    var decoded = 0;
    for (final file in bundledImages()) {
      final size = pngSize(file);
      if (size == null) continue;
      decoded += size.width * size.height * 4;
    }
    final megabytes = decoded / 1024 / 1024;
    expect(
      megabytes,
      lessThan(8),
      reason: 'dekódolt memória: ${megabytes.toStringAsFixed(1)} MB '
          '(a 2026-09-27 előtti állapot 59.2 MB volt)',
    );
  });

  test('az optimalizáló eszköz a repóban marad (ismételhető)', () {
    final tool = File('tools/optimize-app-images.mjs');
    expect(tool.existsSync(), isTrue);
    final content = tool.readAsStringSync();
    expect(content.contains('--write'), isTrue);
    expect(content.contains('scale='), isTrue, reason: 'kicsinyít, nem vág');
    // Minden csomagolt kép szerepeljen a listában (különben kimaradna).
    for (final file in bundledImages()) {
      final relative = file.path.replaceAll(r'\', '/');
      expect(
        content.contains(relative),
        isTrue,
        reason: '$relative nincs a célok között',
      );
    }
  });
}
