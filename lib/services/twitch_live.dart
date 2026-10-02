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

/// A nyilvános Twitch web-kliens azonosítója (ugyanaz, amit a twitch.tv oldal használ).
const String twitchWebClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

/// A GraphQL-lekérdezés — **tiszta** szöveg, ezért forrás-linttel mérhető.
String twitchLiveQuery(String channel) =>
    'query{user(login:"$channel"){id displayName stream{id title viewersCount createdAt type '
    'game{name} previewImageURL(width:640,height:360)}}}';

/// A borítókép URL-je a csatornához (a Twitch sablonja; élő adásnál mozog).
String twitchThumbnailUrl(String channel, {int width = 640, int height = 360}) =>
    'https://static-cdn.jtvnw.net/previews-ttv/live_user_${channel.toLowerCase()}-${width}x$height.jpg';

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
