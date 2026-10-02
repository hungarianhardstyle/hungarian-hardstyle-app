import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A rádió **„most szól"** metaadata (ICY/Shoutcast — a stream saját fejléce).
///
/// MIÉRT (mérés, 2026-10-01): a `https://stream.realhardstyle.nl` fejlécei
/// `icy-name: Real Hardstyle Radio`, **`icy-metaint: 16384`**, és a folyam
/// 16384. bájtja után jön a metaadat-blokk:
/// `StreamTitle='LNY TNZ & Nyanda - Light Up Your Life';StreamNext='Rogue Zero - Walk Away';`
/// Vagyis a **zeneszám és a következő szám is kiolvasható** — ebből lesz az
/// értesítés/zárképernyő szövege (a rádiónak nincs ehhez API-ja).
///
/// ⚠️ EZ A FÁJL **TISZTA** (hálózat nélkül mérhető): a bájtok értelmezése és a
/// szöveg kinyerése külön függvény, a hálózat csak a [fetchIcyMetadata]-ben van.
class RadioMetadata {
  const RadioMetadata({this.title = '', this.next = ''});

  /// A most szóló szám (üres, ha a rádió éppen nem küld címet).
  final String title;

  /// A következő szám, ha a szerver megadja (gyakran üres).
  final String next;

  bool get isEmpty => title.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  @override
  String toString() => 'RadioMetadata(title: "$title", next: "$next")';

  @override
  bool operator ==(Object other) =>
      other is RadioMetadata && other.title == title && other.next == next;

  @override
  int get hashCode => Object.hash(title, next);
}

/// Az `icy-metaint` fejléc értéke — hány bájt hang után jön a metaadat.
///
/// `null`, ha a szerver nem küldi (ilyenkor **nincs** metaadat, nem tippelünk).
int? icyMetaIntFrom(String? headerValue) {
  final value = int.tryParse((headerValue ?? '').trim());
  if (value == null || value <= 0) return null;
  return value;
}

/// A metaadat-blokk kiolvasása a nyers folyambájtokból.
///
/// A blokk a [metaint]. bájton kezdődik: ott egy **hossz-bájt** áll (16 bájtos
/// egységekben), utána a szöveg, `\0` feltöltéssel. Ha a puffer rövidebb, a
/// **rendelkezésre álló** részt adjuk vissza (nem tippelünk és nem dobunk).
String decodeIcyBlock(List<int> bytes, int metaint) {
  if (metaint <= 0 || bytes.length <= metaint) return '';
  final length = bytes[metaint] * 16;
  if (length <= 0) return '';
  final end = metaint + 1 + length;
  final slice = bytes.sublist(
    metaint + 1,
    end <= bytes.length ? end : bytes.length,
  );
  return decodeIcyText(slice);
}

/// A blokk szövegének dekódolása.
///
/// ⚠️ A gyakorlatban a szerverek **UTF-8-at** küldenek, de régebbi Shoutcast
/// szerverek **latin1**-et — ezért előbb UTF-8-at próbálunk, és ha az nem
/// értelmezhető, latin1-re esünk vissza. A magyar ékezet (`ő`, `é`) mindkettőben
/// előfordulhat, ezért ez nem elméleti kérdés.
String decodeIcyText(List<int> bytes) {
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    text = latin1.decode(bytes);
  }
  return text.replaceAll('\u0000', '');
}

/// A `StreamTitle='…'` / `StreamNext='…'` mezők kiolvasása a metaadat-szövegből.
RadioMetadata parseIcyMetadata(String block) {
  final title = RegExp(r"StreamTitle='([^']*)'").firstMatch(block)?.group(1) ?? '';
  final next = RegExp(r"StreamNext='([^']*)'").firstMatch(block)?.group(1) ?? '';
  return RadioMetadata(title: title.trim(), next: next.trim());
}

/// Egy ICY-lekérdezés: a stream **első** metaadat-blokkja.
///
/// ⚠️ Csak a szükséges bájtokat olvassuk (a hangot eldobjuk), és a kapcsolatot
/// azonnal lezárjuk — a stream végtelen, ezért a naiv `await for` soha nem
/// fejeződne be. Hálózati hiba esetén `null` (a hívó megtartja a régi címet).
Future<RadioMetadata?> fetchIcyMetadata(
  Uri streamUri, {
  HttpClient? client,
  Duration timeout = const Duration(seconds: 6),
}) async {
  final own = client ?? HttpClient();
  own.connectionTimeout = timeout;
  try {
    final request = await own.getUrl(streamUri);
    request.headers.set('Icy-MetaData', '1');
    request.headers.set('User-Agent', 'HUHS-App/1.0 (now-playing)');
    final response = await request.close();
    final metaint = icyMetaIntFrom(response.headers.value('icy-metaint'));
    if (metaint == null) return null;
    // A hossz-bájt + a maximális blokk (255 × 16) is bele kell férjen.
    final needed = metaint + 1 + 255 * 16;
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length >= needed) break;
      if (bytes.length > metaint + 1) {
        // Megvan a hossz-bájt: ha a blokk már teljes, nem várunk tovább.
        final length = bytes[metaint] * 16;
        if (bytes.length >= metaint + 1 + length) break;
      }
    }
    return parseIcyMetadata(decodeIcyBlock(bytes, metaint));
  } catch (_) {
    return null;
  } finally {
    if (client == null) own.close(force: true);
  }
}
