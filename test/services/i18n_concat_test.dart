import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A **többsoros, összefűzött** szövegek fordítása.
///
/// ⚠️ MIÉRT KÜLÖN TESZT (mért hiba, 2026-09-25): a Dart a **szomszédos**
/// string-literálokat összefűzi (`'a ' 'b'` → `'a b'`), a vesszővel elválasztott
/// argumentumokat viszont nem. A futásidejű szöveg ezért a **fűzött** változat —
/// ha a szótár csak a **töredéket** ismeri, a fordítás **csendben nem
/// érvényesül**, és a képernyő angol módban is magyar marad. A 361/362-ben
/// **10 ilyen hely** volt (pl. a beállítások „Kedvencek/Hírlevél" sorai, a
/// privacy-szakaszok, a „Keverés közben…" súgó).
///
/// ⚠️ MÉRÉSI TANULSÁG A TESZT SAJÁT ELSŐ VÁLTOZATÁBÓL: a literál-kereső regexet
/// nyers stringbe írtam, amitől a minta **elromlott**, a teszt **nulla helyet**
/// vizsgált, és **zölden hazudott** (a mutáció sem buktatta meg). Ezért most
/// (a) a minta két külön, egyszerű regex, és (b) a teszt **őrszemet** kapott:
/// ha nem vizsgál legalább néhány helyet, maga a teszt bukik el.
void main() {
  String readFile(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

  final singleQuoted = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
  final doubleQuoted = RegExp('"((?:[^"\\\\\n]|\\\\.)*)"');

  /// A sor string-literáljai pozíció szerint.
  List<({String value, int start, int end})> literals(String line) {
    final found = <({String value, int start, int end})>[];
    for (final match in singleQuoted.allMatches(line)) {
      found.add((value: match.group(1) ?? '', start: match.start, end: match.end));
    }
    for (final match in doubleQuoted.allMatches(line)) {
      found.add((value: match.group(1) ?? '', start: match.start, end: match.end));
    }
    found.sort((a, b) => a.start.compareTo(b.start));
    return found;
  }

  bool startsWithLiteral(String line) => RegExp('^\\s*[\'"]').hasMatch(line);

  /// Folytatás-e a sor (az előző sor literállal **vessző nélkül** végződik)?
  ///
  /// ⚠️ Enélkül egy hosszú, sok sorra tördelt bekezdés **minden** soráról azt
  /// hinnénk, hogy önálló fűzött szöveg — a privacy-szakaszoknál ez 15 ál-változatot
  /// adott. A futásidejű érték a **csoport első** sorától indul.
  bool isContinuation(List<String> lines, int index) {
    if (index == 0) return false;
    final previous = lines[index - 1];
    final parts = literals(previous);
    if (parts.length != 1) return false;
    return previous.substring(parts.first.end).trim().isEmpty && startsWithLiteral(lines[index]);
  }

  /// A fűzött érték (ha a literál többsoros fűzésben áll).
  String? joinedValue(List<String> lines, int index) {
    final parts = literals(lines[index]);
    if (parts.length != 1) return null;
    // Vessző (vagy bármi más) a literál után → NEM fűzés (külön argumentum).
    if (lines[index].substring(parts.first.end).trim().isNotEmpty) return null;
    var value = parts.first.value;
    var cursor = index;
    while (cursor + 1 < lines.length && startsWithLiteral(lines[cursor + 1])) {
      final next = literals(lines[cursor + 1]);
      if (next.isEmpty) break;
      value += next.first.value;
      cursor += 1;
      if (lines[cursor].substring(next.first.end).trim().isNotEmpty) break;
    }
    return cursor == index ? null : value;
  }

  test('a fűzés-felismerés működik (őrszem a néma zöld ellen)', () {
    const sample = [
      "  const AppText(",
      "    'Első rész '",
      "    'második rész.',",
      "  ),",
    ];
    expect(joinedValue(sample, 1), 'Első rész második rész.');
    // Vesszővel elválasztott argumentumok NEM fűződnek össze.
    const separate = ["      'Felhasználó blokkolása',", "      'Nem tudtok majd egymásnak írni.',"];
    expect(joinedValue(separate, 0), isNull);
    expect(literals("      'egy', 'kettő',").length, 2);
  });

  test('minden többsoros (fűzött) UI-szöveg kulcsa benne van a szótárban', () {
    final dictionary = jsonDecode(readFile('assets/i18n/en.json')) as Map<String, dynamic>;
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        // A chat üzenet a felhasználó szövege — soha nem fordítjuk.
        .where((file) => !file.path.endsWith('chat_message_text.dart'))
        .toList();

    var checked = 0;
    var skippedInterpolated = 0;
    final problems = <String>[];
    for (final file in files) {
      final lines = readFile(file.path).split('\n');
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (line.trimLeft().startsWith('//')) continue;
        // A csoport folytatásait kihagyjuk (csak az első sor a futásidejű szöveg).
        if (isContinuation(lines, index)) continue;
        final joined = joinedValue(lines, index);
        if (joined == null) continue;
        // Csak a magyar (ékezetes) szövegek érdekesek.
        if (!RegExp('[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]').hasMatch(joined)) continue;
        // ⚠️ Az INTERPOLÁLT (`${…}`) fűzés a `trArgs`-kör: ott a szótár kulcsa a
        // `{n}` helyőrzős VÁLTOZAT, ezért itt szándékosan kimarad (mérve: a
        // prize_admin és az admin_resource_editor ilyen sorai).
        if (joined.contains(r'$')) {
          skippedInterpolated += 1;
          continue;
        }
        // A technikai literal (útvonal, kulcs, azonosító) nem szöveg.
        if (RegExp(r'[/\\@#_]').hasMatch(joined)) continue;
        checked += 1;
        if (dictionary.containsKey(joined)) continue;
        problems.add('${file.path}:${index + 1}  ${joined.length} karakter');
      }
    }

    expect(
      checked,
      greaterThan(15),
      reason: 'a teszt tényleg vizsgált fűzött helyeket (néma zöld elleni őrszem; '
          'mérve 23 csoport van, a folytatások nélkül)',
    );
    expect(
      skippedInterpolated,
      greaterThan(0),
      reason: 'az interpolált fűzések külön körben mennek (trArgs); ez a szám mutatja, hogy van ilyen',
    );
    expect(
      problems,
      isEmpty,
      reason: 'a fűzött szöveg a futásidejű érték: ennek kell a szótár kulcsának lennie '
          '(különben a fordítás csendben nem érvényesül)',
    );
  });
}
