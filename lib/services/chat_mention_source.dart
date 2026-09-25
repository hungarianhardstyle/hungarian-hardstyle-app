import '../core/content/date_formatters.dart';
import 'chat_mention_plan.dart';
import 'community_service.dart';
import 'wordpress_service.dart';

/// Admin vagy moderátor? — **csak ő** hivatkozhat tartalomra a Chatben.
///
/// A tulajdonos döntése: *„A személyre/userre hivatkozás legyen elérhető
/// mindenkinek, többi csak admin/moderátornak."* A szerepkör a profil
/// `accessRole` mezője (`admin` / `moderator` / `none`), ezért itt **csak ez a
/// három érték** számít — a szöveg trimelve és kisbetűsítve érkezik, mert egy
/// kézzel írt vagy régi dokumentumból `" Admin "` is előfordulhat.
///
/// ⚠️ Ez **kliens-oldali** kapu: csak a felületet kíméli (ne kínáljon
/// lehetetlent). A **hiteles** szűrés a szerveren van (`sanitizeMentions`
/// a `functions/chat-mention-plan.js`-ben) — ezért a `publishChatPost`
/// visszaadja a kihagyottak számát, amit a felület jelez.
bool mentionPrivileged(String? accessRole) {
  final role = (accessRole ?? '').trim().toLowerCase();
  return role == CommunityService.accessAdmin ||
      role == CommunityService.accessModerator;
}

/// A `@`-javaslatok **adatforrása** (hálózat + cache).
///
/// MIÉRT külön fájl: a felület ne tudjon arról, **honnan** jön a lista. A
/// személyek a **már meglévő, cache-elt** publikus profil-listából
/// (`getRegisteredPublicProfiles`), a tartalom a **mentett** WordPress-listákból
/// (`getArtists` / `getOrganizers` / `getEvents` / `getReleases` / `getPosts`).
///
/// ⚠️ **Minden hiba el van nyelve** (üres lista / üres térkép): a
/// javaslatlista soha nem törheti el a Chatet. Ez tudatos: a Chat írása nem
/// függhet attól, hogy épp válaszol-e a WordPress.
class ChatMentionSource {
  ChatMentionSource({CommunityService? community, WordpressService? wordpress})
    : _community = community ?? CommunityService(),
      _wordpress = wordpress ?? WordpressService();

  final CommunityService _community;
  final WordpressService _wordpress;

  /// Ennyi találat elég egy típusból (a lista úgyis szűkül gépelés közben).
  static const int _contentLimit = 60;

  /// A **személyek** javaslatai: `id` = uid, `label` = a nyilvános név,
  /// `subtitle` = a HUHS-szám vagy a város, ha van ilyen a profilban.
  Future<List<MentionSuggestion>> mentionUserSuggestions() async {
    try {
      final profiles = await _community.getRegisteredPublicProfiles();
      final result = <MentionSuggestion>[];
      for (final profile in profiles) {
        final id = (profile['userId'] as String? ?? '').trim();
        final label = (profile['displayName'] as String? ?? '').trim();
        if (id.isEmpty || label.isEmpty) continue;
        result.add(
          MentionSuggestion(
            type: mentionTypeUser,
            id: id,
            label: label,
            subtitle: _userSubtitle(profile),
          ),
        );
      }
      return List<MentionSuggestion>.unmodifiable(result);
    } catch (_) {
      return const <MentionSuggestion>[];
    }
  }

  /// A **tartalom** javaslatai típus szerint: a kulcsok pontosan a
  /// [mentionContentTypes] ( `article`, `artist`, `organizer`, `event`,
  /// `release` ), hogy a felület ne találgasson.
  ///
  /// A tartalom **csak adminnak/moderátornak** jár — ezt a hívó dönti el
  /// ([mentionPrivileged]), itt nincs jogosultság-ág.
  Future<Map<String, List<MentionSuggestion>>> mentionContentSuggestions() async {
    final loaded = await Future.wait<List<MentionSuggestion>>([
      _safe(_articleSuggestions),
      _safe(_artistSuggestions),
      _safe(_organizerSuggestions),
      _safe(_eventSuggestions),
      _safe(_releaseSuggestions),
    ]);
    final content = <String, List<MentionSuggestion>>{};
    for (var index = 0; index < mentionContentTypes.length; index++) {
      content[mentionContentTypes[index]] = loaded[index];
    }
    return Map<String, List<MentionSuggestion>>.unmodifiable(content);
  }

  /// Egy típus betöltése — hiba esetén **üres lista** (nem kivétel).
  Future<List<MentionSuggestion>> _safe(
    Future<List<MentionSuggestion>> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (_) {
      return const <MentionSuggestion>[];
    }
  }

  Future<List<MentionSuggestion>> _articleSuggestions() async {
    final page = await _wordpress.getPosts(perPage: _contentLimit);
    return _suggestions(
      mentionTypeArticle,
      page.items,
      id: (post) => '${post.id}',
      label: (post) => post.title,
      subtitle: (post) => formatHungarianDate(post.date),
    );
  }

  Future<List<MentionSuggestion>> _artistSuggestions() async {
    final page = await _wordpress.getArtists(perPage: _contentLimit);
    return _suggestions(
      mentionTypeArtist,
      page.items,
      id: (artist) => '${artist.id}',
      label: (artist) => artist.title,
      // A város a legbeszédesebb (a műfaj-lista hosszú lehet).
      subtitle: (artist) => artist.city.isNotEmpty
          ? artist.city
          : artist.genres.isNotEmpty
          ? artist.genres.first
          : '',
    );
  }

  Future<List<MentionSuggestion>> _organizerSuggestions() async {
    final page = await _wordpress.getOrganizers(perPage: _contentLimit);
    return _suggestions(
      mentionTypeOrganizer,
      page.items,
      id: (organizer) => '${organizer.id}',
      label: (organizer) => organizer.title,
      subtitle: (organizer) => organizer.city,
    );
  }

  Future<List<MentionSuggestion>> _eventSuggestions() async {
    // `includePast: true`, mert egy régebbi üzenet hivatkozása is a helyére
    // vigyen: a múltbeli esemény adatlapja ugyanúgy nyílik.
    final events = await _wordpress.getEvents(
      includePast: true,
      perPage: _contentLimit,
    );
    return _suggestions(
      mentionTypeEvent,
      events,
      id: (event) => '${event.id}',
      label: (event) => event.title,
      subtitle: (event) => [
        formatEventDate(event.startDate, ''),
        event.venueCity,
      ].where((part) => part.trim().isNotEmpty).join(' · '),
    );
  }

  Future<List<MentionSuggestion>> _releaseSuggestions() async {
    final releases = await _wordpress.getReleases();
    return _suggestions(
      mentionTypeRelease,
      releases,
      id: (release) => '${release.id}',
      label: (release) => release.title,
      subtitle: (release) => [
        release.genre,
        formatHungarianDate(release.releaseDate),
      ].where((part) => part.trim().isNotEmpty).join(' · '),
    );
  }

  /// Egységes leképezés: **üres azonosítójú vagy nevű** elem kimarad (nem
  /// küldünk használhatatlan hivatkozást a listába).
  List<MentionSuggestion> _suggestions<T>(
    String type,
    List<T> items, {
    required String Function(T item) id,
    required String Function(T item) label,
    required String Function(T item) subtitle,
  }) {
    final result = <MentionSuggestion>[];
    for (final item in items) {
      final itemId = id(item).trim();
      final itemLabel = label(item).trim();
      if (itemId.isEmpty || itemLabel.isEmpty) continue;
      result.add(
        MentionSuggestion(
          type: type,
          id: itemId,
          label: itemLabel,
          subtitle: subtitle(item).trim(),
        ),
      );
      if (result.length >= _contentLimit) break;
    }
    return List<MentionSuggestion>.unmodifiable(result);
  }

  /// A HUHS-szám a legjobb másodlagos sor (a „HUHS user 1234" név párja);
  /// ha nincs, a város. Ha egyik sincs, **üres** — nem találgatunk.
  String _userSubtitle(Map<String, dynamic> profile) {
    final rawNumber = profile['huhsUserNumber'];
    final number = rawNumber is num
        ? rawNumber.toInt()
        : int.tryParse('${rawNumber ?? ''}');
    if (number != null && number > 0) return 'HUHS #$number';
    for (final key in const ['city', 'venueCity', 'region']) {
      final value = (profile[key] as String? ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}
