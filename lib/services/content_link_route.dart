/// **Megosztott link → belső cél** — tiszta, hálózat nélkül tesztelhető kód.
///
/// MIÉRT (a cél 3. pontja): a megosztott hír/esemény/kiadvány/DJ link eddig a
/// **böngészőt** nyitotta. Az app mostantól a `AndroidManifest.xml`-ben **fogja**
/// a mért permalink-alakokat (`/events…`, `/releases…`, `/djs…`, `/invite…`), és
/// ebből a modulból tudja meg, **mit** kell megnyitnia.
///
/// ⚠️ **MÉRT ALAKOK (2026-09-28, nem tippelve):**
///   * esemény  → `https://hungarianhardstyle.hu/events/hard-base-classic…`
///   * kiadvány → `https://hungarianhardstyle.hu/releases/goze-change-of-pace/`
///   * DJ       → `https://hungarianhardstyle.hu/djs/adam-bass/`
///   * hír      → `https://hungarianhardstyle.hu/2026/09/26/hard-bass-2026-himnusz/`
///   * meghívó  → `https://hungarianhardstyle.hu/invite/{kód}`
///   * rövidlink → `https://hungarianhardstyle.hu/?p={id}` (WordPress)
///
/// ⚠️ **ŐSZINTE KORLÁT:** a szép permalink **slugot** ad, a rövidlink **id-t** —
/// az app adatlapjai viszont **id** alapján nyílnak. Ezért ez a modul csak a
/// **szándékot** állapítja meg (`kind` + `id` VAGY `slug`); az azonosító
/// feloldása (slug → id) külön lépés, és a következő kör dolga.
library;

/// Milyen tartalomra mutat a link?
enum ContentLinkKind { invite, news, event, release, artist, unknown }

/// Egy bejövő link értelmezett célja.
class ContentLinkRoute {
  const ContentLinkRoute({
    required this.kind,
    this.id,
    this.slug = '',
    this.inviteCode = '',
    required this.raw,
  });

  final ContentLinkKind kind;

  /// A WordPress-azonosító, ha a link hordozta (`?p={id}`). Egyébként `null`.
  final int? id;

  /// A permalink utolsó értelmes darabja (a feloldáshoz).
  final String slug;

  /// Meghívó-kód (`/invite/{kód}`).
  final String inviteCode;

  /// Az eredeti link (naplózáshoz és a feloldáshoz).
  final String raw;

  /// Van-e azonnal megnyitható célpontja (id VAGY meghívó-kód)?
  bool get isNavigable =>
      id != null || (kind == ContentLinkKind.invite && inviteCode.isNotEmpty);

  @override
  String toString() =>
      'ContentLinkRoute(${kind.name}, id: $id, slug: $slug, code: $inviteCode)';
}

/// Az app domainje(i) — csak ezeket értelmezzük belső linkként.
bool isAppHost(String host) {
  final clean = host.trim().toLowerCase();
  return clean == 'hungarianhardstyle.hu' || clean == 'www.hungarianhardstyle.hu';
}

/// A permalink-előtag → tartalom-típus (a **mért** alakok szerint).
ContentLinkKind _kindForFirstSegment(String segment) {
  switch (segment) {
    case 'invite':
      return ContentLinkKind.invite;
    case 'events':
      return ContentLinkKind.event;
    case 'releases':
      return ContentLinkKind.release;
    case 'djs':
    case 'artists':
      return ContentLinkKind.artist;
    default:
      return ContentLinkKind.unknown;
  }
}

/// Hír-e a dátum-alapú permalink (`/2026/09/26/slug/`)?
bool _looksLikeNews(String first) {
  if (first.length != 4) return false;
  final year = int.tryParse(first);
  return year != null && year >= 2000 && year <= 2100;
}

/// Egy bejövő `Uri` értelmezése. Ismeretlen/hiányos linkre `unknown` a válasz
/// (az app ilyenkor a **főoldalt** mutatja, nem téved el).
ContentLinkRoute contentLinkRouteFromUri(Uri? uri) {
  final raw = uri?.toString() ?? '';
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return ContentLinkRoute(kind: ContentLinkKind.unknown, raw: raw);
  }
  if (uri.host.isNotEmpty && !isAppHost(uri.host)) {
    return ContentLinkRoute(kind: ContentLinkKind.unknown, raw: raw);
  }

  // Rövidlink: `/?p={id}` — a WordPress a szép permalinkre irányítja, de a
  // típusát nem mondja meg, ezért itt csak az azonosítót ismerjük.
  final shortId = int.tryParse(uri.queryParameters['p'] ?? '');
  if (shortId != null && shortId > 0) {
    return ContentLinkRoute(
      kind: ContentLinkKind.unknown,
      id: shortId,
      raw: raw,
    );
  }

  final segments = uri.pathSegments.where((part) => part.trim().isNotEmpty).toList();
  if (segments.isEmpty) {
    return ContentLinkRoute(kind: ContentLinkKind.unknown, raw: raw);
  }

  final first = segments.first.toLowerCase();
  var kind = _kindForFirstSegment(first);
  if (kind == ContentLinkKind.unknown && _looksLikeNews(first)) {
    kind = ContentLinkKind.news;
  }

  if (kind == ContentLinkKind.invite) {
    final code = segments.length > 1 ? segments[1].trim() : '';
    return ContentLinkRoute(
      kind: ContentLinkKind.invite,
      inviteCode: code,
      raw: raw,
    );
  }

  // A permalink utolsó darabja a slug (tartalomnál; hírnél a nap is előtte van).
  final slug = segments.length > 1 ? segments.last.trim() : '';
  return ContentLinkRoute(kind: kind, slug: slug, raw: raw);
}
