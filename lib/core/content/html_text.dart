/// HTML-entitások feloldása a **szerverről jövő** szövegekben.
///
/// **MIÉRT KELL (a tulajdonos jelzése, 2026-09-26):** *„Goze leírásában:
/// Hardstyle producer &amp; … itt csak a kódolási hiba van"* — a WordPress-ben a
/// leírás **entitásként** áll (`&amp;`), az app pedig a sima szöveget még egyszer
/// escape-eli (hogy HTML-ként biztonságosan megjeleníthető legyen), ezért a
/// képernyőn **`&amp;`** látszott a `&` helyett.
///
/// **ÉLES MÉRÉS** (`tmp/probe-amp-entities.mjs`, 2026-09-26): a `/artists`
/// válaszban a magyar leírások közül **2/17**, az angolok közül **3/17**
/// tartalmaz `&amp;`-t — pl. `Hardstyle producer &amp; Dj` (Goze),
/// `Denzor &amp; Adam Bass` (Nu-Clear, angolul; magyarul sima `&`),
/// `D-Block &amp; S-Te-Fan` (Subrage).
///
/// A minta **nem új**: a hír (`post.dart`), az esemény (`event.dart`) és a GYÍK
/// (`faq.dart`) már feloldja az entitásokat — a DJ- és szervező-adatlapnál
/// viszont kimaradt. Ez a közös segéd ezt a rést zárja be.
library;

/// A leggyakoribb HTML-entitások + a numerikus (`&#39;`, `&#x27;`) alakok.
///
/// Szándékosan **csak** entitásokat oldunk fel, tageket nem: a hívó dönti el,
/// hogy a szöveget HTML-ként vagy sima szövegként rajzolja-e ki.
String decodeHtmlEntities(String value) {
  if (value.isEmpty || !value.contains('&')) return value;
  var text = value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&hellip;', '...')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
  text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
    final codePoint = int.tryParse(match.group(1)!, radix: 16);
    return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
  });
  return text.replaceAllMapped(RegExp(r'&#([0-9]+);'), (match) {
    final codePoint = int.tryParse(match.group(1)!);
    return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
  });
}
