import 'wordpress_service.dart';

/// A **tartalom-értesítések** címe a MOSTANI nyelven — a régi sorokhoz.
///
/// **MIÉRT KELL (a tulajdonos jelzése, 2026-09-26):** *„most se angol a
/// notifyban a cikk címe"*. A `new_news` / `new_release` / `new_event` /
/// `new_artist` / `new_organizer` értesítés **törzse maga a cím** (adat), ezért a
/// sablon-alapú fordítás nem érinti: a szerver a **létrehozáskor** a címzett
/// akkori nyelvén renderelte, és a Firestore-ban **kész szöveg** áll.
///
/// A szerver a **jövőbeli** értesítéseknél már nyelvenkénti térképet ad
/// (`{hu, en}`), így azok eleve a címzett nyelvén születnek. A **már meglévő**
/// sorokhoz viszont a cím az `targetType` + `targetId` alapján **újra
/// lekérdezhető** a mostani nyelven — ezt teszi ez az osztály (a
/// `WordpressService` részlet-gyorsítótára nyelvenként külön él, ezért a
/// lekérdezés a választott nyelvet adja).
///
/// ⚠️ Best-effort: bármilyen hiba (nincs hálózat, régi azonosító) `null`-t ad,
/// ilyenkor a tárolt szöveg marad — az értesítés **soha** nem törik el.
class NotificationContentTitles {
  /// Azok az értesítés-típusok, amelyeknek a **törzse** egy tartalom címe.
  static const Set<String> contentTypes = <String>{
    'new_news',
    'new_release',
    'new_event',
    'new_artist',
    'new_organizer',
  };

  /// Kell-e ehhez a sorhoz tartalom-cím feloldás?
  ///
  /// Csak akkor, ha a típus tartalom-típus, az azonosító szám, és a fordítás
  /// **nem** változtatta meg a törzset (vagyis a törzs adat, nem sablon).
  static bool needsResolve({
    required String type,
    required String targetId,
    required String storedBody,
    required String localizedBody,
  }) {
    if (!contentTypes.contains(type.trim())) return false;
    if (targetId.trim().isEmpty) return false;
    if (int.tryParse(targetId.trim()) == null) return false;
    return storedBody.trim() == localizedBody.trim();
  }

  /// A tartalom címe a MOSTANI nyelven (a `WordpressService` gyorsítótárán át).
  static Future<String?> resolve({
    required String targetType,
    required String targetId,
  }) async {
    final id = int.tryParse(targetId.trim());
    if (id == null || id <= 0) return null;

    final service = WordpressService();
    try {
      switch (targetType.trim()) {
        case 'news':
          final post = await service.getPost(id);
          return _clean(post.title);
        case 'release':
          final release = await service.getRelease(id);
          return _clean(release.title);
        case 'event':
          final event = await service.getEvent(id);
          return _clean(event.title);
        case 'artist':
          final artist = await service.getArtist(id);
          return _clean(artist.title);
        case 'organizer':
          final organizer = await service.getOrganizer(id);
          return _clean(organizer.title);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String? _clean(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
