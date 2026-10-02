import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/twitch_live.dart';

/// Egy `HttpClient` helyettesítő, ami a megadott szöveget adja vissza.
///
/// ⚠️ Így a **forrás-sorrend** (plugin → Firestore → alapérték) hálózat nélkül
/// mérhető: a `fetchTwitchCardFromWordPress` ezen a kliensen keresztül kapja a
/// választ, a Firestore-oldal pedig injektált `firestoreLoader`.
HttpClient _stubClient(String body, {int status = 200}) {
  final client = _FakeHttpClient();
  client.body = body;
  client.status = status;
  return client;
}

class _FakeHttpClient implements HttpClient {
  String body = '';
  int status = 200;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest(body, status);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.body, this.status);

  final String body;
  final int status;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse(body, status);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeHttpClientResponse(this.body, this.statusCode);

  final String body;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(utf8Bytes(body)).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<int> utf8Bytes(String text) => const Utf8Encoder().convert(text);

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A Twitch-élő állapot mérése — **hálózat nélkül**.
///
/// ⚠️ A minta a 2026-10-01-i éles mérés alakját követi
/// (`node tmp/probe-twitch.mjs`): a nyilvános web-kliens GraphQL-válasza,
/// `HungarianHardstyle`, `id 87485328`; élő adásnál a `stream` kitöltve,
/// egyébként `null`.
void main() {
  group('a nyilvános GraphQL válasz', () {
    test('élő adásnál kiolvassa a címet, a nézőket és a borítót', () {
      const body = '''
      {"data":{"user":{"id":"87485328","displayName":"HungarianHardstyle","stream":{
        "id":"44123456789","title":"HUHS Live #42 — hardstyle session","viewersCount":128,
        "createdAt":"2026-10-01T18:00:00Z","type":"live","game":{"name":"Music"},
        "previewImageURL":"https://static-cdn.jtvnw.net/previews-ttv/live_user_hungarianhardstyle-640x360.jpg"
      }}}}''';
      final status = parseTwitchLiveResponse(body);
      expect(status.isLive, isTrue);
      expect(status.title, 'HUHS Live #42 — hardstyle session');
      expect(status.viewers, 128);
      expect(status.game, 'Music');
      expect(status.streamId, '44123456789');
      expect(status.thumbnailUrl, contains('previews-ttv'));
      // A kártya a mozgó képet tölti újra: gyorsítótár-kerülő paraméter.
      expect(status.thumbnailUrl, contains('?t='));
    });

    test('nem élő adásnál (stream = null) nem jelez élőt', () {
      const body = '{"data":{"user":{"id":"87485328","displayName":"HungarianHardstyle","stream":null}}}';
      final status = parseTwitchLiveResponse(body);
      expect(status.isLive, isFalse);
      expect(status.isEmpty, isTrue);
      // A borító URL-je ilyenkor is megvan (a Twitch helyettesítő képe).
      expect(status.thumbnailUrl, contains('live_user_hungarianhardstyle'));
    });

    test('hibás vagy üres válaszra nem dob, és nem jelez élőt', () {
      for (final body in ['', 'nem json', '{"data":{}}', '{"data":{"user":{}}}']) {
        final status = parseTwitchLiveResponse(body);
        expect(status.isLive, isFalse, reason: body);
      }
    });

    test('a hiányzó borítókép helyére a Twitch sablon-URL-je kerül', () {
      const body = '{"data":{"user":{"stream":{"id":"1","title":"x","viewersCount":3}}}}';
      final status = parseTwitchLiveResponse(body);
      expect(status.thumbnailUrl, contains('live_user_hungarianhardstyle-640x360'));
    });
  });

  group('a linkek (tiszta függvények)', () {
    test('a csatorna a tulajdonosé', () {
      expect(twitchChannel, 'hungarianhardstyle');
    });

    test('a borítókép URL-je a Twitch sablonja', () {
      expect(
        twitchThumbnailUrl('HungarianHardstyle'),
        'https://static-cdn.jtvnw.net/previews-ttv/live_user_hungarianhardstyle-640x360.jpg',
      );
    });

    test('a beágyazott lejátszó a parent paraméterrel indul', () {
      final url = twitchEmbedUrl(twitchChannel);
      expect(url, startsWith('https://player.twitch.tv/?channel=hungarianhardstyle'));
      expect(url, contains('parent=localhost'));
      expect(url, contains('autoplay=true'));
    });

    test('a lekérdezés a mért mezőket kéri', () {
      final query = twitchLiveQuery(twitchChannel);
      expect(query, contains('user(login:"hungarianhardstyle")'));
      expect(query, contains('viewersCount'));
      expect(query, contains('previewImageURL'));
    });
  });

  group('a kártya láthatósága (tiszta döntés)', () {
    // ⚠️ MIÉRT EZ A KÖR (mért hiány, 2026-10-02): a tulajdonos felülírása azt
    // ígéri, hogy `enabled: true` esetén a kártya megjelenik — élő adás nélkül
    // viszont nem jelent meg, ezért aki előre beállítja a saját képét, semmit
    // nem látott. A döntés ezért egy helyen, mérhetően él.
    test('élő adásnál látszik (ez a lényeg)', () {
      expect(
        twitchCardVisible(isLive: true, enabled: true, showWhenOffline: false, hasImage: false),
        isTrue,
      );
    });

    test('élő adás nélkül alapból NEM látszik', () {
      expect(
        twitchCardVisible(isLive: false, enabled: true, showWhenOffline: false, hasImage: true),
        isFalse,
      );
    });

    test('élő adás nélkül kérésre + saját képpel látszik (előre behirdetés)', () {
      expect(
        twitchCardVisible(isLive: false, enabled: true, showWhenOffline: true, hasImage: true),
        isTrue,
      );
    });

    test('kérésre, de kép nélkül nem látszik (nem lenne mit mutatni)', () {
      expect(
        twitchCardVisible(isLive: false, enabled: true, showWhenOffline: true, hasImage: false),
        isFalse,
      );
    });

    test('a kikapcsolt kapcsoló MINDIG elrejti (élő adásnál is)', () {
      expect(
        twitchCardVisible(isLive: true, enabled: false, showWhenOffline: true, hasImage: true),
        isFalse,
      );
      expect(
        twitchCardVisible(isLive: false, enabled: false, showWhenOffline: true, hasImage: true),
        isFalse,
      );
    });
  });

  group('a beállítás értelmezése (tiszta)', () {
    // ⚠️ MIÉRT EZ A KÖR (mért hiba, 2026-10-02): a tulajdonos beállította a
    // képet a plugin adminjában, és nem látta az appban. Az app-oldali olvasást
    // ezért két forrásból tápláljuk (plugin → Firestore), és a szabályoknak
    // UGYANAZOKNAK kell lenniük, mint a pluginban és a szerveroldali szinkronban.
    test('a teljes beállítást kiolvassa', () {
      final config = parseTwitchCardConfig(const {
        'enabled': true,
        'imageUrl': 'https://hungarianhardstyle.hu/wp-content/uploads/2026/10/denioser-stream.png',
        'headerText': 'Következő adás: péntek 20:00',
        'showWhenOffline': true,
      });
      expect(config.enabled, isTrue);
      expect(config.hasImage, isTrue);
      expect(config.showWhenOffline, isTrue);
      expect(config.headerText, 'Következő adás: péntek 20:00');
    });

    test('a hiányzó enabled jelentése BE (nem rejti el a működő kártyát)', () {
      expect(parseTwitchCardConfig(const {}).enabled, isTrue);
      expect(parseTwitchCardConfig(null).enabled, isTrue);
    });

    test('KÉP NÉLKÜL az „élő adás nélkül is” nem kapcsol be', () {
      final config = parseTwitchCardConfig(const {'showWhenOffline': true});
      expect(config.showWhenOffline, isFalse);
      expect(config.hasImage, isFalse);
    });

    test('a kikapcsolt kártya jelzése átjön', () {
      expect(parseTwitchCardConfig(const {'enabled': false}).enabled, isFalse);
    });

    test('a mezők körüli szóközöket levágja', () {
      final config = parseTwitchCardConfig(const {
        'imageUrl': '  https://example.test/a.jpg  ',
        'headerText': '  Felirat  ',
      });
      expect(config.imageUrl, 'https://example.test/a.jpg');
      expect(config.headerText, 'Felirat');
    });
  });

  group('a beállítás forrásai (plugin → Firestore → alapérték)', () {
    test('ha a plugin válaszol, az nyer (a tulajdonos ott állítja)', () async {
      final config = await fetchTwitchCardConfig(
        client: _stubClient(
          '{"imageUrl":"https://example.test/plugin.jpg","headerText":"Plugin","showWhenOffline":true}',
        ),
        firestoreLoader: () async => const TwitchCardConfig(imageUrl: 'https://example.test/firestore.jpg'),
      );
      expect(config.imageUrl, 'https://example.test/plugin.jpg');
      expect(config.showWhenOffline, isTrue);
    });

    test('ha a plugin nem él, a Firestore-másolat jön', () async {
      final config = await fetchTwitchCardConfig(
        client: _stubClient('', status: 500),
        firestoreLoader: () async => const TwitchCardConfig(
          imageUrl: 'https://example.test/firestore.jpg',
          showWhenOffline: true,
        ),
      );
      expect(config.imageUrl, 'https://example.test/firestore.jpg');
      expect(config.showWhenOffline, isTrue);
    });

    test('ha egyik forrás sem él, az alapérték jön (nem tippelünk)', () async {
      final config = await fetchTwitchCardConfig(
        client: _stubClient('nem json'),
        firestoreLoader: () async => null,
      );
      expect(config.imageUrl, '');
      expect(config.hasImage, isFalse);
      expect(config.enabled, isTrue);
    });

    test('a hibás JSON nem dönti el az appot', () async {
      final config = await fetchTwitchCardConfig(client: _stubClient('<html>hiba</html>'));
      expect(config.hasImage, isFalse);
    });
  });

  group('a bekötés (forrás-lint)', () {
    test('a kártya a tiszta döntést használja, és nem hazudik élő adást', () {
      final card = File('lib/widgets/twitch_live_card.dart').readAsStringSync();
      expect(card, contains('twitchCardVisible('), reason: 'a láthatóság nem a közös döntésből jön');
      expect(card, contains('showWhenOffline: override?.showWhenOffline ?? false'));
      // Az „ÉLŐ" jelvény és a „Nézd élőben" gomb csak valódi élő adásnál jelenik meg.
      expect(card, contains('if (live.isLive) const Positioned('));
      expect(card, contains("live.isLive ? 'Nézd élőben' : 'Twitch-csatorna'"));
    });

    test('a felülírás olvassa a showWhenOffline mezőt', () {
      // ⚠️ A mező olvasása 2026-10-02 óta a **tiszta értelmezőben** él
      // (`parseTwitchCardConfig`), ezért azt mérjük — és azt is, hogy a provider
      // ezt használja (nem a saját, széttartó másolatát).
      final service = File('lib/services/twitch_live.dart').readAsStringSync();
      expect(service, contains("data['showWhenOffline'] == true && imageUrl.isNotEmpty"));
      expect(service, contains('TwitchCardConfig parseTwitchCardConfig'));
      final provider = File('lib/providers/twitch_live_provider.dart').readAsStringSync();
      expect(provider, contains('parseTwitchCardConfig('), reason: 'a provider nem a közös értelmezőt használja');
      // A frissítés (a mért hiba oka): 3 percenként újraolvassuk.
      expect(provider, contains('Timer.periodic(const Duration(minutes: 3)'));
      // A plugin az első forrás, a Firestore a tartalék.
      expect(provider, contains('fetchTwitchCardConfig('));
      expect(provider, contains('loadTwitchCardFromFirestore'));
    });

    test('a főoldal az élő kártyát a hírek blokkja után mutatja', () {
      final source = File('lib/screens/home/home_screen.dart').readAsStringSync();
      expect(source, contains('const TwitchLiveCard(),'));
      final cardIndex = source.indexOf('const TwitchLiveCard(),');
      final eventsIndex = source.indexOf("'Közelgő események'");
      expect(cardIndex, greaterThan(0));
      expect(cardIndex, lessThan(eventsIndex),
          reason: 'a Twitch-kártya a „Közelgő események" előtt van');
    });

    test('a Twitch-oldal a stream-chatjét, a támogatást és a kis képernyőt használja', () {
      final source = File('lib/screens/twitch/twitch_screen.dart').readAsStringSync();
      // ⚠️ A MÉRT HIBA (2026-10-02, a tulajdonos jelzése): *„a twitch oldal alatti
      // chatr ha írok, valamiért a fő chatre is kikerül...”* — itt eddig a fő chat
      // widgetje (`LiveFeedScreen`) állt, ezért ugyanabba a gyűjteménybe írt.
      expect(source, contains('TwitchStreamChat()'), reason: 'nincs stream-chat a videó alatt');
      expect(source.contains('LiveFeedScreen'), isFalse,
          reason: 'a Twitch-oldal a FŐ chatet használná (ez volt a hiba)');
      expect(source, contains('DonateScreen.openDonate()'), reason: 'nincs támogatás gomb');
      expect(source, contains('pictureInPicture.setEnabled(true)'), reason: 'nincs kis képernyő');
      expect(source, contains('stopRadioPlayback()'), reason: 'a rádió nem áll le a streamhez');
      expect(source, contains('resumeRadioPlayback()'), reason: 'a rádió nem tér vissza kilépéskor');
      expect(source, contains('twitchEmbedUrl(twitchChannel)'), reason: 'nincs beágyazott lejátszó');
    });

    test('a támogatás linkje EGY helyen él (a Twitch-oldal is azt használja)', () {
      final donate = File('lib/screens/more/donate_screen.dart').readAsStringSync();
      expect(donate, contains('static final Uri donateUri'));
      expect(donate, contains('paypal.com/donate'));
      final twitch = File('lib/screens/twitch/twitch_screen.dart').readAsStringSync();
      expect(twitch.contains('paypal.com'), isFalse,
          reason: 'a Twitch-oldal nem tartalmazhat külön PayPal-linket');
    });

    test('a támogatás gomb a videó alatt van, a chattől elkülönítve', () {
      // ⚠️ A MÉRT HIBA (2026-10-02, a tulajdonos képe): *„az a támogatás gomb
      // nagyon rossz helyen van”* — a támogatás `floatingActionButton` volt,
      // ezért a chat alsó sávjában, pont a „Küldés” gomb mellett lebegett.
      // Ez a teszt a HELYÉT méri (nem azt, hogy „benne van a fájlban”).
      final source = File('lib/screens/twitch/twitch_screen.dart').readAsStringSync();

      expect(
        source.contains('floatingActionButton:'),
        isFalse,
        reason: 'a támogatás újra lebegő gombként a chat küldés gombja mellé került',
      );
      expect(
        source.contains('FloatingActionButton.extended('),
        isFalse,
        reason: 'a támogatás újra lebegő gombként a chat küldés gombja mellé került',
      );

      // ⚠️ A HELYET a metódus TESTÉBEN mérjük (a fájl-szintű „benne van” minta
      // gyenge — a 386/390 tanulsága). A tényleges geometriát (a gomb a videó
      // alatt, a chat fölött, minden képernyőn) a
      // `test/screens/twitch_layout_test.dart` méri kirajzolva.
      final infoBody = source.substring(source.indexOf('Widget _infoColumn('));
      expect(infoBody.contains("label: const AppText('Támogatás PayPallal')"), isTrue,
          reason: 'a támogatás gomb az adatsávban van');
      expect(infoBody.contains('TwitchStreamChat'), isFalse,
          reason: 'a támogatás gomb nem a chatben van');

      final frameIndex = source.indexOf('TwitchLayoutFrame(');
      final infoArgIndex = source.indexOf('info: _infoColumn(', frameIndex);
      final chatArgIndex = source.indexOf('chat: const TwitchStreamChat()', frameIndex);
      expect(frameIndex, greaterThan(0), reason: 'nincs alkalmazkodó váza');
      expect(infoArgIndex, greaterThan(frameIndex), reason: 'az adatsáv nincs megadva');
      expect(chatArgIndex, greaterThan(infoArgIndex),
          reason: 'az adatsáv (támogatás) a chat ELŐTT van a vázban');
    });

    test('a támogatás ikonja mindkét helyen ugyanaz (nem szív — az a kedvencelés)', () {
      final source = File('lib/screens/twitch/twitch_screen.dart').readAsStringSync();
      expect(source.contains('Icons.volunteer_activism'), isTrue,
          reason: 'a támogatás ikonja hiányzik');
      expect(source.contains('Icons.favorite'), isFalse,
          reason: 'a szív ikon a kedvencelést jelenti, nem a támogatást');
      expect(source.contains('Icons.payment'), isFalse,
          reason: 'a lebegő gomb ikonja maradt a képernyőn');
    });

    test('a Twitch-csatorna URL-je felismerhető (a push erre visz)', () {
      // A tulajdonos kérése (2026-10-02): *„ha kimegy a push a twitch chatről,
      // hogy live … akkor nyissa meg a twitches oldalt a pushra nyomva”* — a
      // széles push a Twitch URL-jét hozza, ezt kell az app-oldalra fordítani.
      expect(isTwitchChannelUrl('https://www.twitch.tv/hungarianhardstyle'), isTrue);
      expect(isTwitchChannelUrl('https://twitch.tv/hungarianhardstyle'), isTrue);
      expect(isTwitchChannelUrl('https://player.twitch.tv/?channel=hungarianhardstyle'), isTrue);
      expect(isTwitchChannelUrl('  https://www.twitch.tv/hungarianhardstyle  '), isTrue);
      expect(isTwitchChannelUrl('https://clips.twitch.tv/abc'), isTrue);
    });

    test('minden MÁS URL marad a böngészőben', () {
      expect(isTwitchChannelUrl(''), isFalse);
      expect(isTwitchChannelUrl('   '), isFalse);
      expect(isTwitchChannelUrl('https://hungarianhardstyle.hu/hirek'), isFalse);
      expect(isTwitchChannelUrl('https://www.youtube.com/watch?v=1'), isFalse);
      // A „twitch.tv” a saját domainben nem Twitch (nincs séma/host).
      expect(isTwitchChannelUrl('twitch.tv/hungarianhardstyle'), isFalse);
      expect(isTwitchChannelUrl('https://nottwitch.tv/x'), isFalse);
      expect(isTwitchChannelUrl('https://twitch.tv.evil.example/x'), isFalse);
    });

    test('az Android-oldal engedi a kis képernyőt, és a kapcsolót figyeli', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:supportsPictureInPicture="true"'));
      final activity =
          File('android/app/src/main/kotlin/hu/hungarianhardstyle/app/MainActivity.kt').readAsStringSync();
      expect(activity, contains('hu_hs/pip'));
      expect(activity, contains('onUserLeaveHint'));
      expect(activity, contains('enterPictureInPictureMode'));
    });
  });
}
