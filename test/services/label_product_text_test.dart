import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **A Label-termékek szövege a felület nyelvén szól.**
///
/// A TULAJDONOS JELZÉSE (2026-09-27, képernyőkép): *„a labelnél a termékek még
/// magyarul vannak az angol felületen"* — a kiadvány-adatlap terméksorának
/// **második sora** a Play-termék **leírásából** jött
/// (`product!.description`), amit a szerver (`upsertPlayProduct`) eddig **csak
/// magyarul** (`hu-HU`) hozott létre. Ezért a Play a felület nyelvétől
/// függetlenül a magyar szöveget adta vissza.
///
/// A javítás **két** helyen történt, és ez a fájl mindkettőt méri:
///  1. **kliens:** a leírás a saját, **fordított** sablonunkból épül
///     (`Hungarian Hardstyle {variant} letöltés: {title}`) — így a MOSTANI
///     nyelven szól, a Play-fiók nyelvétől függetlenül;
///  2. **szerver:** a Play-listázás **angol** változatot is kap (`en-US`), hogy
///     a vásárlási lap is a helyes nyelven szóljon (lásd
///     `functions/play-product-plan.test.cjs`).
void main() {
  final screen = File(
    'lib/screens/releases/release_detail_screen.dart',
  ).readAsStringSync();
  final dictionary =
      jsonDecode(File('assets/i18n/en.json').readAsStringSync()) as Map<String, dynamic>;

  test('a termék leírása a SAJÁT, fordított sablonunkból jön', () {
    expect(
      screen.contains(
        "trArgs(context, 'Hungarian Hardstyle {variant} letöltés: {title}', {",
      ),
      isTrue,
      reason: 'a sorként a fordítón át, sablonnal épül',
    );
    expect(
      screen.contains("'variant': label,"),
      isTrue,
      reason: 'a változat neve a már lefordított címkéből jön',
    );
    expect(
      screen.contains("'title': widget.release.title,"),
      isTrue,
      reason: 'a kiadvány címe adat, változatlanul kerül bele',
    );
  });

  test('a Play-termék leírását NEM írjuk ki közvetlenül', () {
    // ⚠️ A MEGJEGYZÉSEKET előbb kivesszük: a magyarázó sorok említik a régi
    // kódot (`product.description`), és a naiv minta azokra is illeszkedne —
    // a kapu a KÓDRA szól (ez a saját mérőeszközöm hibája volt).
    final code = screen.replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
    // ⚠️ Ez a lényeg: a Play-leírás nyelvenként EGY (a fiók nyelvét követi),
    // ezért nem lehet a felület szövege.
    expect(
      RegExp(r'product!?\.description').hasMatch(code),
      isFalse,
      reason: 'a Play-termék leírása nem jelenhet meg közvetlenül',
    );
    expect(
      code.contains('Megvásárolható a Google Playen'),
      isFalse,
      reason: 'a régi tartalék szöveg helyett a sablon van (nincs benne duplikáció)',
    );
  });

  test('a sablon angol fordítása megvan a szótárban', () {
    const key = 'Hungarian Hardstyle {variant} letöltés: {title}';
    expect(dictionary.containsKey(key), isTrue, reason: 'hiányzó kulcs: $key');
    final english = '${dictionary[key]}';
    expect(english.contains('download'), isTrue, reason: english);
    expect(
      english.contains('letöltés'),
      isFalse,
      reason: 'az angol szövegben nem maradhat magyar szó: $english',
    );
    expect(english.contains('{variant}') && english.contains('{title}'), isTrue);
  });
}
