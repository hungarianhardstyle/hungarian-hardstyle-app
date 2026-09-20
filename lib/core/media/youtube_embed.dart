/// A YouTube-videó **appon belüli** lejátszásához tartozó tiszta logika.
///
/// MIÉRT: a tulajdonos jelzése szerint a cikkekben lévő YouTube-videó a „play"
/// gombra **külső alkalmazást** nyitott meg ahelyett, hogy az appban játszódna le.
///
/// A beágyazás WebView-ban **három dolgon** szokott elhasalni, és mind a három itt
/// van kezelve:
///
///   1. **Nincs „origin" (hivatkozó).** Ha a WebView közvetlenül a
///      `youtube.com/embed/...` címet tölti be, a kérésnek nincs hivatkozója, és a
///      YouTube „Video unavailable" / 153-as hibát ad. Ezért a lejátszót
///      **saját HTML-be** ágyazzuk, és a `baseUrl` adja a valódi origin-t
///      ([youTubeEmbedBaseUrl]) — ez a legfontosabb javítás.
///   2. **A WebView alapértelmezett user-agentje** (`…; wv`) alapján a YouTube
///      „nem támogatott böngészőt" lát. Ezért explicit Chrome-fejlécet adunk
///      ([youTubeEmbedUserAgent]).
///   3. **JavaScript** nélkül a lejátszó el sem indul (a hívó kapcsolja be).
///
/// A `playsinline=1` gondoskodik arról, hogy a lejátszás az appban maradjon
/// (ne kényszerítsen teljes képernyős natív lejátszóra).
library;

/// A beágyazás „hivatkozója" — a YouTube ezt látja origin-ként.
///
/// Szándékosan a saját domain: ez egy létező, HTTPS-en futó oldal, ezért a
/// YouTube elfogadja a beágyazást. **Ne** cseréld `about:blank`-ra vagy üresre:
/// attól jön vissza a „Video unavailable" hiba.
const String youTubeEmbedBaseUrl = 'https://hungarianhardstyle.hu/';

/// Chrome-fejléc, mert a WebView sajátját (`wv`) a YouTube elutasíthatja.
const String youTubeEmbedUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/124.0.0.0 Mobile Safari/537.36';

/// A videó azonosítója a YouTube **összes** ismert linkformájából.
///
/// Kezelt alakok (a valódi cikkekből mérve):
///   * `https://www.youtube.com/watch?v=ID` (és `&feature=shared`, `&t=42`)
///   * `https://www.youtube.com/watch?feature=shared&v=ID` (a `v` nem az első)
///   * `https://youtu.be/ID`
///   * `https://www.youtube.com/shorts/ID`
///   * `https://www.youtube.com/embed/ID`
///   * `https://www.youtube.com/live/ID`
///   * `www.youtube.com/watch?v=ID` (séma nélkül) és HTML-entity (`&amp;`)
///
/// `null`, ha nem kinyerhető azonosító.
String? youTubeVideoId(String url) {
  final cleaned = _clean(url);
  if (cleaned.isEmpty) return null;
  final uri = Uri.tryParse(cleaned);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  if (host.isEmpty || !host.contains('youtu')) return null;

  if (host.contains('youtu.be')) {
    return _firstSegment(uri.pathSegments);
  }
  final queryId = uri.queryParameters['v'];
  if (queryId != null && queryId.trim().isNotEmpty) return queryId.trim();
  for (final marker in const ['shorts', 'embed', 'live', 'v']) {
    final id = _after(uri.pathSegments, marker);
    if (id != null && id.trim().isNotEmpty) return id.trim();
  }
  return null;
}

/// A beágyazható lejátszó címe (ha valaki közvetlenül URL-t szeretne betölteni).
///
/// A `post_embed_card.dart` a HTML-utat használja (lásd [youTubeEmbedHtml]),
/// mert az adja a szükséges origin-t; ez a függvény a tartalék/ellenőrzés.
Uri youTubeEmbedUri(String videoId) => Uri.https('www.youtube.com', '/embed/$videoId', {
  'playsinline': '1',
  'rel': '0',
  'modestbranding': '1',
});

/// A lejátszót tartalmazó HTML — ezt töltjük be a `baseUrl`-lel együtt.
String youTubeEmbedHtml(String videoId) {
  final src = youTubeEmbedUri(videoId).toString();
  return '''
<!DOCTYPE html>
<html lang="hu">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<meta name="referrer" content="origin">
<style>
html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}
iframe{position:absolute;inset:0;width:100%;height:100%;border:0}
</style>
</head>
<body>
<iframe
  src="$src"
  title="YouTube videó"
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
  allowfullscreen
  referrerpolicy="origin"></iframe>
</body>
</html>
''';
}

String _clean(String url) {
  var value = url.trim();
  // A WordPress/JSON néha megtartja a HTML-entityt vagy a JSON-escape-et.
  value = value.replaceAll('&amp;', '&').replaceAll(r'\u0026', '&');
  // Láthatatlan karakterek (a bemásolt linkek gyakori szennyeződése).
  value = value.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  if (value.startsWith('//')) return 'https:$value';
  if (value.startsWith('http://')) return 'https://${value.substring(7)}';
  if (!value.startsWith('http')) {
    final uri = Uri.tryParse('https://$value');
    if (uri != null && uri.host.contains('youtu')) return 'https://$value';
  }
  return value;
}

String? _firstSegment(List<String> parts) {
  for (final part in parts) {
    if (part.trim().isNotEmpty) return part.trim();
  }
  return null;
}

String? _after(List<String> parts, String marker) {
  final index = parts.indexOf(marker);
  if (index < 0 || index + 1 >= parts.length) return null;
  final value = parts[index + 1].trim();
  return value.isEmpty ? null : value;
}
