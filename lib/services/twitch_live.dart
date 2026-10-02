import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A Twitch-csatorna **élő állapota** — és minden, ami a főoldali kártyához kell.
///
/// MIÉRT ÍGY (mérés, 2026-10-01): a hivatalos Twitch Helix API **OAuth tokent**
/// kér (kulcs nélkül `401`), a **nyilvános web-kliens** viszont kulcs nélkül
/// válaszol ugyanarra a kérdésre:
///
/// ```
/// POST https://gql.twitch.tv/gql   (Client-ID: a nyilvános web-kliens azonosítója)
///   → user(login:"hungarianhardstyle") { id displayName stream { id title viewersCount
///     createdAt type game { name } previewImageURL(width:640,height:360) } }
/// ```
/// A mért válasz: `HungarianHardstyle`, `id 87485328`; élő adásnál a `stream`
/// kitöltve (cím, nézők, borítókép), egyébként `null`. **Nem kell hozzá
/// tulajdonosi kulcs**, ezért az app önmagában is megmondja, hogy megy-e a stream.
///
/// ⚠️ A borítókép URL-je mindig él (`static-cdn.jtvnw.net/previews-ttv/…`), élő
/// adásnál **mozog** — ezért a kártya ugyanazt a linket tölti újra néhány
/// másodpercenként (gyorsítótár-kerülő paraméterrel).
class TwitchLiveStatus {
  const TwitchLiveStatus({
    this.isLive = false,
    this.title = '',
    this.viewers = 0,
    this.game = '',
    this.thumbnailUrl = '',
    this.streamId = '',
    this.startedAt = '',
  });

  final bool isLive;
  final String title;

  /// Egyidejű nézők száma (a Twitch adja; élő adásnál értelmes).
  final int viewers;
  final String game;

  /// A **mozgó** előnézet képe (élő adásnál másodpercenként frissül a Twitch oldalán).
  final String thumbnailUrl;

  /// Az adás azonosítója — ebből tudjuk, hogy egy adásról **egyszer** szóljunk.
  final String streamId;
  final String startedAt;

  bool get isEmpty => !isLive || thumbnailUrl.isEmpty;

  @override
  String toString() =>
      'TwitchLiveStatus(isLive: $isLive, title: "$title", viewers: $viewers)';
}

/// A csatorna, amit figyelünk (a tulajdonos adta: twitch.tv/hungarianhardstyle).
const String twitchChannel = 'hungarianhardstyle';

/// A **Twitch-kártya beállításának nyilvános végpontja** (a plugin adminjából).
///
/// ⚠️ MIÉRT A PLUGIN AZ ELSŐDLEGES FORRÁS (mért hiba, 2026-10-02): a tulajdonos
/// *„feldobtam egy képet a twitch beharangozóhoz, de egyáltalán nem látom az
/// iPhone appban”*. A lánc három szeme rendben volt (a kép a szerveren, a
/// végpont adja, a Firestore-ba beíródott) — az **app** akadt el: a felülírást
/// csak a Firestore-ból olvasta, **frissítés nélkül**, és ha az olvasás
/// elhasalt, **némán** az alapértékre esett vissza. Mostantól a plugin
/// végpontja az első út (ugyanaz az adat, amit a tulajdonos beállít), a
/// Firestore pedig a tartalék — és mindkettő **3 percenként** frissül.
const String twitchCardEndpoint = 'https://hungarianhardstyle.hu/wp-json/huhs/v1/twitch-card';

/// A kártya beállítása (egy helyen, hogy a két forrás ne tudjon széttartani).
class TwitchCardConfig {
  const TwitchCardConfig({
    this.enabled = true,
    this.imageUrl = '',
    this.headerText = '',
    this.showWhenOffline = false,
  });

  final bool enabled;
  final String imageUrl;
  final String headerText;

  /// Élő adás nélkül is látszódjon (saját képpel) — a tulajdonos kérése.
  final bool showWhenOffline;

  bool get hasImage => imageUrl.trim().isNotEmpty;

  @override
  String toString() =>
      'TwitchCardConfig(enabled: $enabled, showWhenOffline: $showWhenOffline, '
      'hasImage: $hasImage, header: "$headerText")';
}

/// A beállítás értelmezése — **tiszta**, ezért hálózat nélkül mérhető.
///
/// Ugyanazt a szabályt használja, mint a plugin adminja és a szerveroldali
/// szinkron: **kép nélkül** az „élő adás nélkül is” nem kapcsol be (nem lenne
/// mit mutatni), a hiányzó `enabled` jelentése pedig **BE**.
TwitchCardConfig parseTwitchCardConfig(Map<String, dynamic>? data) {
  if (data == null) return const TwitchCardConfig();
  final imageUrl = (data['imageUrl'] as String? ?? '').trim();
  return TwitchCardConfig(
    enabled: data['enabled'] != false,
    imageUrl: imageUrl,
    headerText: (data['headerText'] as String? ?? '').trim(),
    showWhenOffline: data['showWhenOffline'] == true && imageUrl.isNotEmpty,
  );
}

/// **Látszik-e a főoldali Twitch-kártya?** — tiszta döntés, ezért mérhető.
///
/// MIÉRT KÜLÖN (mért hiány, 2026-10-02): a tulajdonos felülírása
/// (`app_settings/twitch`) azt ígéri, hogy `enabled: true` esetén a kártya
/// **megjelenik** — a valóság viszont az volt, hogy **élő adás nélkül nem**,
/// ezért aki előre beállítja a saját képét (pl. egy következő adás plakátját),
/// **semmit nem lát**, és azt hiheti, elromlott.
///
/// A szabály ezért:
///  * **élő adásnál** a kártya látszik (ha a kapcsoló nem tiltja) — ez a lényeg;
///  * **élő adás nélkül** csak akkor, ha a tulajdonos **kifejezetten kéri**
///    (`showWhenOffline`) **és** van saját képe (a Twitch mozgó előnézete
///    ilyenkor nincs mit mutasson);
///  * a kikapcsolt kapcsoló (`enabled: false`) **mindig** elrejti.
bool twitchCardVisible({
  required bool isLive,
  required bool enabled,
  required bool showWhenOffline,
  required bool hasImage,
}) {
  if (!enabled) return false;
  if (isLive) return true;
  return showWhenOffline && hasImage;
}


/// A nyilvános Twitch web-kliens azonosítója (ugyanaz, amit a twitch.tv oldal használ).
const String twitchWebClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

/// A GraphQL-lekérdezés — **tiszta** szöveg, ezért forrás-linttel mérhető.
String twitchLiveQuery(String channel) =>
    'query{user(login:"$channel"){id displayName stream{id title viewersCount createdAt type '
    'game{name} previewImageURL(width:640,height:360)}}}';

/// A borítókép URL-je a csatornához (a Twitch sablonja; élő adásnál mozog).
String twitchThumbnailUrl(String channel, {int width = 640, int height = 360}) =>
    'https://static-cdn.jtvnw.net/previews-ttv/live_user_${channel.toLowerCase()}-${width}x$height.jpg';

/// Igaz, ha az URL a **Twitch-csatornára** mutat.
///
/// MIÉRT (a tulajdonos kérése, 2026-10-02): *„ha kimegy a push a twitch
/// chatről, hogy live … akkor nyissa meg a twitches oldalt a pushra nyomva”*.
/// A széles (WordPress-)push a Twitch-csatorna **URL-jét** hozza
/// (`https://www.twitch.tv/hungarianhardstyle`), az app viszont eddig a
/// **böngészőt** nyitotta vele. Ez a tiszta felismerés teszi lehetővé, hogy a
/// koppintás az app **saját Twitch-oldalára** vigyen.
///
/// Szándékosan **csak a Twitch domain** számít (a `player.twitch.tv` és a
/// `clips.twitch.tv` is); minden más URL marad a böngészőben.
bool isTwitchChannelUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host == 'twitch.tv' || host == 'www.twitch.tv' || host.endsWith('.twitch.tv');
}

/// A beágyazott lejátszó URL-je (`player.twitch.tv`), a chat nélkül.
///
/// ⚠️ A `parent` paramétert a Twitch megköveteli; natív appban a `localhost`
/// bevett érték (a WebView-ból induló kérés így elfogadott).
String twitchEmbedUrl(String channel, {String parent = 'localhost'}) =>
    'https://player.twitch.tv/?channel=${channel.toLowerCase()}&parent=$parent&autoplay=true&muted=false';

/// A nyilvános GraphQL-válasz értelmezése — **hálózat nélkül mérhető**.
///
/// Toleráns: hiányzó/„hibás" mezőkre nem dob, hanem nem-élő állapotot ad (a
/// kártya ilyenkor egyszerűen nem jelenik meg).
TwitchLiveStatus parseTwitchLiveResponse(String body) {
  final thumbnailFallback = twitchThumbnailUrl(twitchChannel);
  try {
    final decoded = jsonDecode(body);
    final user = (decoded is Map && decoded['data'] is Map)
        ? (decoded['data'] as Map)['user']
        : null;
    if (user is! Map) return TwitchLiveStatus(thumbnailUrl: thumbnailFallback);
    final stream = user['stream'];
    if (stream is! Map) return TwitchLiveStatus(thumbnailUrl: thumbnailFallback);
    final thumbnail = (stream['previewImageURL'] as String?)?.trim() ?? '';
    return TwitchLiveStatus(
      isLive: true,
      title: (stream['title'] as String?)?.trim() ?? '',
      viewers: (stream['viewersCount'] as num?)?.toInt() ?? 0,
      game: ((stream['game'] as Map?)?['name'] as String?)?.trim() ?? '',
      thumbnailUrl: thumbnail.isEmpty ? thumbnailFallback : '$thumbnail?t=${DateTime.now().millisecondsSinceEpoch}',
      streamId: (stream['id'] as String?)?.trim() ?? '',
      startedAt: (stream['createdAt'] as String?)?.trim() ?? '',
    );
  } catch (_) {
    return TwitchLiveStatus(thumbnailUrl: thumbnailFallback);
  }
}

/// Élő állapot lekérdezése (a nyilvános web-klienssel, kulcs nélkül).
///
/// Hálózati hiba vagy értelmezhetetlen válasz esetén **nem-élő** állapot: a
/// főoldali kártya ilyenkor nem jelenik meg (nem tippelünk).
Future<TwitchLiveStatus> fetchTwitchLive({
  HttpClient? client,
  String channel = twitchChannel,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final own = client ?? HttpClient();
  own.connectionTimeout = timeout;
  try {
    final request = await own.postUrl(Uri.parse('https://gql.twitch.tv/gql'));
    request.headers.set('Client-ID', twitchWebClientId);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('User-Agent', 'HUHS-App/1.0 (twitch-live)');
    request.add(utf8.encode(jsonEncode({'query': twitchLiveQuery(channel)})));
    final response = await request.close();
    if (response.statusCode != 200) {
      return TwitchLiveStatus(thumbnailUrl: twitchThumbnailUrl(channel));
    }
    final body = await response.transform(utf8.decoder).join();
    return parseTwitchLiveResponse(body);
  } catch (error) {
    debugPrint('twitch: az élő állapot nem kérdezhető le: $error');
    return TwitchLiveStatus(thumbnailUrl: twitchThumbnailUrl(channel));
  } finally {
    if (client == null) own.close(force: true);
  }
}

/// A kártya beállításának lekérdezése a **plugin végpontjáról** (elsődleges út).
///
/// `null`, ha nem érhető el vagy nem értelmezhető — ilyenkor a hívó a
/// Firestore-ból próbálkozik (a szerveroldali szinkron másolata).
Future<TwitchCardConfig?> fetchTwitchCardFromWordPress({HttpClient? client}) async {
  final own = client ?? HttpClient();
  own.connectionTimeout = const Duration(seconds: 8);
  try {
    final uri = Uri.parse('$twitchCardEndpoint?_=${DateTime.now().millisecondsSinceEpoch}');
    final request = await own.getUrl(uri);
    request.headers.set('Accept', 'application/json');
    request.headers.set('Cache-Control', 'no-cache');
    request.headers.set('User-Agent', 'HUHS-App/1.0 (twitch-card)');
    final response = await request.close();
    if (response.statusCode != 200) {
      debugPrint('twitch: a kártya-beállítás végpontja HTTP ${response.statusCode}');
      return null;
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    return parseTwitchCardConfig(Map<String, dynamic>.from(decoded));
  } catch (error) {
    debugPrint('twitch: a kártya-beállítás nem kérdezhető le a plugintól: $error');
    return null;
  } finally {
    if (client == null) own.close(force: true);
  }
}

/// A kártya beállítása: **plugin → Firestore → alapérték**.
///
/// A `firestoreLoader` injektálható, ezért a sorrend hálózat nélkül mérhető.
Future<TwitchCardConfig> fetchTwitchCardConfig({
  HttpClient? client,
  Future<TwitchCardConfig?> Function()? firestoreLoader,
}) async {
  final fromWordPress = await fetchTwitchCardFromWordPress(client: client);
  if (fromWordPress != null) return fromWordPress;
  if (firestoreLoader != null) {
    final fromFirestore = await firestoreLoader();
    if (fromFirestore != null) return fromFirestore;
  }
  debugPrint('twitch: a kártya beállítása egyik forrásból sem jött (alapérték)');
  return const TwitchCardConfig();
}

/// A Firestore-tartalék naplózása (a providerból, hogy a `dart:io` import itt
/// maradjon — a napló szövege **angol**, mert nem felületi szöveg).
void debugPrintTwitchCardFallbackFailed(Object error) {
  debugPrint('twitch: the Firestore fallback for the card settings failed: $error');
}
