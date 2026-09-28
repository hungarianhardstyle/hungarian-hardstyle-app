/// **Link-feloldás** — a megosztott linkből nyitható célpont (tiszta kód).
///
/// A `content_link_route.dart` megmondja, **mi** a link (típus + slug vagy
/// azonosító), a WordPress `/resolve` végpontja (plugin 2.14.10) pedig megadja a
/// hiányzó **azonosítót**. Ez a modul a kettő közötti szerződés: összeállítja a
/// kérést, és a válaszból célpontot képez — hálózat nélkül tesztelhetően.
///
/// ⚠️ A tényleges HTTP-hívást a hívó adja (`fetch`), így az app a saját
/// kliensét használhatja, a teszt pedig nem függ hálózattól.
library;

import 'content_link_route.dart';

/// A feloldó végpont (a pluginban él; mért: `GET`, nyilvános, csak olvas).
const String contentResolveEndpoint =
    'https://hungarianhardstyle.hu/wp-json/huhs/v1/resolve';

/// Egy feloldott, **megnyitható** célpont.
class ContentLinkTarget {
  const ContentLinkTarget({
    required this.kind,
    required this.id,
    this.title = '',
    this.url = '',
  });

  final ContentLinkKind kind;
  final int id;
  final String title;
  final String url;

  @override
  String toString() => 'ContentLinkTarget(${kind.name}, $id)';
}

ContentLinkKind? _kindFromType(String type) {
  switch (type) {
    case 'event':
      return ContentLinkKind.event;
    case 'release':
      return ContentLinkKind.release;
    case 'artist':
      return ContentLinkKind.artist;
    case 'news':
      return ContentLinkKind.news;
    default:
      return null;
  }
}

/// A `/resolve` kérés URL-je a linkből — `null`, ha nincs mit feloldani.
///
/// Ha a link már hordozta az azonosítót (`?p=…`), akkor is feloldjuk: a
/// **típus** csak így derül ki.
Uri? contentResolveUri(ContentLinkRoute route) {
  final base = Uri.parse(contentResolveEndpoint);
  if (route.id != null && route.id! > 0) {
    return base.replace(queryParameters: {'p': '${route.id}'});
  }
  final slug = route.slug.trim();
  if (slug.isEmpty) return null;
  return base.replace(queryParameters: {'slug': slug});
}

/// A `/resolve` válaszából célpont; hibás/`404`/ismeretlen válaszra `null`.
ContentLinkTarget? contentLinkTargetFromJson(Map<String, dynamic>? json) {
  if (json == null) return null;
  final kind = _kindFromType((json['type'] ?? '').toString().trim());
  final id = int.tryParse('${json['id'] ?? ''}') ?? 0;
  if (kind == null || id <= 0) return null;
  return ContentLinkTarget(
    kind: kind,
    id: id,
    title: (json['title'] ?? '').toString().trim(),
    url: (json['url'] ?? '').toString().trim(),
  );
}

/// Feloldás egy injektált HTTP-hívással (`fetch`), hálózati hiba esetén `null`.
Future<ContentLinkTarget?> resolveContentLink(
  ContentLinkRoute route,
  Future<Map<String, dynamic>?> Function(Uri uri) fetch,
) async {
  final uri = contentResolveUri(route);
  if (uri == null) return null;
  try {
    return contentLinkTargetFromJson(await fetch(uri));
  } catch (_) {
    // A megosztott link megnyitása sosem törheti el az appot.
    return null;
  }
}
