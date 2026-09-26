import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Kapu: ne maradhasson nyers (fordítatlan) magyar felirat a felületen.**
///
/// MIÉRT KELL (mért eset, 2026-09-26 — a tulajdonos jelzése: *„itt maradt egy
/// magyar szó"*): a „Saját zenéim" fejlécében angol módban is „11 letöltött zene"
/// állt, mert a kiírás `'${_downloaded.length} letöltött zene'` volt. Ezt a
/// hibaosztályt **egyetlen meglévő kapu sem látta**:
///   * a `tools/check-i18n.mjs` (szótár-lefedettség) azért nem, mert az extraktor
///     a `$`-t tartalmazó literált kihagyja (nem tudja, mi lesz a helyőrző),
///   * a `tmp/audit-raw-labels.mjs` azért nem, mert a regexe eleve kizárja a `$`-t.
///
/// EZ A TESZT a **forráskódot** méri, két szinten:
///   1. **Megjelenítési hely** (`Text(`, `label:`, `tooltip:`, `_message(` stb.):
///      itt a literálnak vagy fordító hívásban kell állnia, vagy **szótári
///      kulcsnak** kell lennie (a megjelenítés fordítja).
///   2. **Látens hely** (tárolt állapot, `return '…'`): magyar literál csak akkor
///      maradhat, ha **szótári kulcs** — így a „tárolom a kulcsot, a megjelenítés
///      fordítja" minta (pl. `_message`, `_profileError`, `_readableError`)
///      továbbra is működik, egy új nyers szöveg viszont **elbukik**.
///
/// ⚠️ AMIT SZÁNDÉKOSAN KIHAGY: a `RegExp(...)` minták (nem feliratok) és a
/// **szerveroldali szövegre illesztő** rész-szövegek (ezeket szó szerint kell
/// keresni, fordítani nem lehet) — ezek **névre szóló** kivétellistán vannak,
/// indoklással. Minden más kivétel gyanús: inkább a szótárba kell tenni a kulcsot.
void main() {
  final dictionary = jsonDecode(
    File('assets/i18n/en.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  /// Ezek a hívások fordítanak (a bennük álló literál rendben van).
  const translatingCalls = {
    'tr',
    'trArgs',
    'AppText',
    'AppStrings.tr',
    'AppStrings.trArgs',
  };

  /// Megjelenítő hívások/paraméterek.
  const displayCalls = {
    'Text',
    'SelectableText',
    'TextSpan',
    'RichText',
    'Chip',
    'AppBar',
    'SnackBar',
    'Tooltip',
    'ListTile',
    'DropdownMenuItem',
    'InputDecoration',
    'TextButton',
    'ElevatedButton',
    'OutlinedButton',
    'FilledButton',
    'ActionChip',
    'FilterChip',
    'ChoiceChip',
    'MenuItemButton',
    'Semantics',
  };
  final displayParams = RegExp(
    r'(?:^|[\s(,])(label|tooltip|title|subtitle|hintText|helperText|errorText|'
    r'counterText|semanticLabel|message|content|header|placeholder|text|'
    r'caption|description|confirmLabel|cancelLabel)\s*:\s*$',
  );

  /// **Névre szóló kivételek** — indoklással. Minden más magyar literál vagy
  /// fordító hívásban áll, vagy szótári kulcs kell legyen.
  const allowedLiterals = <String, String>{
    'Ismeretlen admin művelet':
        'a szerver válasz-szövegére illesztünk (szó szerint kell egyeznie)',
  };

  /// A `RegExp(...)` minták nem feliratok.
  bool insideRegExp(String call) => call == 'RegExp';

  final hungarianAccent = RegExp(r'[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]');

  /// Magyar felirat-e a szöveg? (A csak-interpolált alak nem az.)
  bool looksLikeLabel(String text) {
    final withoutPlaceholders = text
        .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
        .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), '')
        .trim();
    if (withoutPlaceholders.length < 2) return false;
    if (!RegExp(r'[A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű]{2}').hasMatch(withoutPlaceholders)) {
      return false;
    }
    return hungarianAccent.hasMatch(text);
  }

  /// A literálok kigyűjtése egy sorból (a `${…}` blokkban lévő idézőjelek nem
  /// zárnak — ez a **mért** hiba volt a korábbi szondában).
  List<({String text, int index, bool atLineEnd, String quote})> literalsOf(
    String line,
  ) {
    final out = <({String text, int index, bool atLineEnd, String quote})>[];
    var i = 0;
    while (i < line.length) {
      final quote = line[i];
      if (quote != "'" && quote != '"') {
        i += 1;
        continue;
      }
      var j = i + 1;
      final buffer = StringBuffer();
      var closed = false;
      while (j < line.length) {
        final ch = line[j];
        if (ch == r'\') {
          buffer.write(line.substring(j, j + 2));
          j += 2;
          continue;
        }
        if (ch == r'$' && j + 1 < line.length && line[j + 1] == '{') {
          var depth = 1;
          var k = j + 2;
          while (k < line.length && depth > 0) {
            if (line[k] == '{') {
              depth += 1;
            } else if (line[k] == '}') {
              depth -= 1;
            }
            k += 1;
          }
          buffer.write(line.substring(j, k));
          j = k;
          continue;
        }
        if (ch == quote) {
          closed = true;
          break;
        }
        buffer.write(ch);
        j += 1;
      }
      if (closed) {
        final rest = line.substring(j + 1).trim();
        out.add((
          text: buffer.toString(),
          index: i,
          // ⚠️ CSAK akkor folytatódhat a következő sorban, ha a literál a sor
          // **utolsó** tokenje (a Dart így fűzi össze a szomszédos literálokat).
          // A `,` a végén **nem** összefűzés — az egy külön listaelem/kulcs.
          atLineEnd: rest.isEmpty,
          quote: quote,
        ));
      }
      i = j + 1;
    }
    return out;
  }

  /// A literálot körülvevő hívás neve (zárójel-számlálással, visszafelé).
  String enclosingCall(List<String> lines, int lineIndex, int columnIndex) {
    final window = <String>[
      ...lines.sublist(lineIndex > 12 ? lineIndex - 12 : 0, lineIndex),
      lines[lineIndex].substring(0, columnIndex),
    ].join('\n');
    var depth = 0;
    for (var i = window.length - 1; i >= 0; i -= 1) {
      final ch = window[i];
      if (ch == ')') {
        depth += 1;
      } else if (ch == '(') {
        if (depth == 0) {
          final match = RegExp(
            r'([A-Za-z_][A-Za-z0-9_.]*)\s*$',
          ).firstMatch(window.substring(0, i));
          return match?.group(1) ?? '';
        }
        depth -= 1;
      }
    }
    return '';
  }

  /// A literál **folytatása** a következő sorokban (a Dart az egymás melletti
  /// literálokat összefűzi — pl. a hosszú jogi bekezdések). A szótárban az
  /// **összefűzött** szöveg a kulcs, ezért itt is össze kell fűzni.
  ({String text, int extraLines}) joinedLiteral(
    List<String> lines,
    int index,
    String first,
    bool atLineEnd,
    String quote,
  ) {
    var text = first;
    var current = index;
    var continues = atLineEnd;
    var extra = 0;
    while (continues) {
      current += 1;
      if (current >= lines.length) break;
      final next = lines[current].trimLeft();
      if (!next.startsWith(quote)) break;
      final inner = next.substring(1);
      final end = inner.indexOf(quote);
      if (end < 0) break;
      text += inner.substring(0, end);
      extra += 1;
      // Csak akkor folytatjuk tovább, ha ez a sor is a literállal ér véget.
      continues = inner.substring(end + 1).trim().isEmpty;
    }
    return (text: text, extraLines: extra);
  }

  List<File> sourceFiles(String dir) {
    final files = <File>[];
    for (final entity in Directory(dir).listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) files.add(entity);
    }
    return files;
  }

  test('a felületen nincs fordítatlan magyar felirat', () {
    final offenders = <String>[];
    for (final file in [...sourceFiles('lib/screens'), ...sourceFiles('lib/widgets')]) {
      final path = file.path.replaceAll(r'\', '/');
      final lines = file.readAsLinesSync();
      // A **folytató** sorok (egy többsoros literál darabjai) külön ne legyenek
      // vizsgálva — a szótári kulcs az **összefűzött** szöveg.
      final continuationLines = <int>{};
      for (var index = 0; index < lines.length; index += 1) {
        if (continuationLines.contains(index)) continue;
        final trimmed = lines[index].trimLeft();
        if (trimmed.startsWith('//')) continue;
        for (final literal in literalsOf(lines[index])) {
          if (!looksLikeLabel(literal.text)) continue;
          final joined = joinedLiteral(
            lines,
            index,
            literal.text,
            literal.atLineEnd,
            literal.quote,
          );
          if (joined.extraLines > 0) {
            for (var k = 1; k <= joined.extraLines; k += 1) {
              continuationLines.add(index + k);
            }
          }
          final call = enclosingCall(lines, index, literal.index);
          if (translatingCalls.contains(call)) continue;
          if (insideRegExp(call)) continue;
          final before = lines[index].substring(0, literal.index);
          // ⚠️ A nevesített paraméter (`title:`, `label:`) csak **hívásban**
          // számít megjelenítési helynek: a rekord-/térkép-literálok mezői
          // (`title: 'Eseményen ott leszek'` egy `static final` adatlistában)
          // adatként élnek, és a megjelenítés fordítja őket (`AppText(…)`).
          final display =
              displayCalls.contains(call) ||
              (call.isNotEmpty && displayParams.hasMatch(before));
          // ⚠️ KÉT SZINT (a mutációs bizonyíték mérte ki a különbséget):
          //  * **közvetlen megjelenítési helyen** (`Text('…')`, `label: '…'`)
          //    a literál **akkor is hiba, ha van szótári kulcsa** — a nyers
          //    kiírás ugyanis nem fordít (angol módban a magyar kulcs látszik);
          //  * **máshol** (tárolt állapot, `return '…'`) a szótári kulcs rendben
          //    van, mert a megjelenítés fordítja (`Text(tr(context, _message!))`).
          if (!display) {
            if (dictionary.containsKey(joined.text)) continue;
            if (allowedLiterals.containsKey(joined.text)) continue;
          }
          offenders.add(
            '$path:${index + 1} [${call.isEmpty ? 'nincs hívás' : call}]'
            '${display ? ' (megjelenítés)' : ''} ${jsonEncode(joined.text)}',
          );
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Az alábbi magyar feliratok nyersen (fordítás nélkül) mennek ki. '
          'Tedd be a szótárba (kulcs = a magyar szöveg), és írasd ki `tr`/'
          '`trArgs`/`AppText`-tel, vagy — tárolt állapotnál — a megjelenítés '
          'fordítson (`Text(tr(context, _message!))`).',
    );
  });

  test('a megjelenítéskor fordított (tárolt) kulcsok bent vannak a szótárban', () {
    // Ezek a szövegek **tárolt** állapotban élnek (pl. `_message`), ezért az
    // extraktor nem látja őket — a szótárban viszont **kulcsként** kell lenniük,
    // különben angol módban magyarul maradnak.
    const displayTranslatedKeys = [
      // A tulajdonos jelzése (2026-09-26): a „Saját zenéim" fejléce.
      '{n} letöltött zene',
      '{position} · {n} letöltve',
      'Ez a tétel most nincs a lejátszási listán.',
      'Törölve a készülékről — a vásárlás megmaradt.',
      'A letöltött zenék törölve — a vásárlásaid megmaradtak.',
      'A(z) „{title}" még nincs letöltve — előbb töltsd le, és utána játszható.',
      'Mentés…',
      'Küldés…',
      'Szünet',
      'Leállítás',
      'Keverés kikapcsolása',
      'Némítás feloldása',
      'Kötelező mező.',
      'TÖRLÉS',
      'A profil betöltése nem sikerült. Próbáld újra.',
      'A kiadvány-katalógus nem töltődött be, ezért nincs mit lekérdezni. '
          'Ellenőrizd az internetkapcsolatot, és próbáld újra.',
      'Ebben a kérdőívben már szavaztál.',
      'A szavazáshoz regisztrált fiók szükséges.',
      'A játékhoz regisztrált fiók szükséges.',
      'Túl sok próbálkozás. Próbáld kicsit később.',
      'A jutalmazott reklám betöltése…',
      'A vásárláshoz előbb be kell jelentkezni.',
    ];
    final missing = displayTranslatedKeys
        .where((key) => !dictionary.containsKey(key))
        .toList();
    expect(missing, isEmpty, reason: 'hiányzó kulcs(ok): $missing');
  });

  test('a tulajdonos jelzése konkrétan angolul szól', () {
    // A mért eset: „11 letöltött zene" angol módban.
    final english = '${dictionary['{n} letöltött zene']}';
    expect(english.toLowerCase(), contains('downloaded'));
    expect(english, contains('{n}'));
    // A fejléc kulcsa is: „… kiadvány · … tétel".
    expect('${dictionary['{releases} kiadvány · {tracks} tétel']}',
        contains('releases'));
  });
}
