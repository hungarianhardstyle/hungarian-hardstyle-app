import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/twitch_live.dart';

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

  group('a bekötés (forrás-lint)', () {
    test('a főoldal az élő kártyát a hírek blokkja után mutatja', () {
      final source = File('lib/screens/home/home_screen.dart').readAsStringSync();
      expect(source, contains('const TwitchLiveCard(),'));
      final cardIndex = source.indexOf('const TwitchLiveCard(),');
      final eventsIndex = source.indexOf("'Közelgő események'");
      expect(cardIndex, greaterThan(0));
      expect(cardIndex, lessThan(eventsIndex),
          reason: 'a Twitch-kártya a „Közelgő események" előtt van');
    });

    test('a Twitch-oldal az APP chatjét, a támogatást és a kis képernyőt használja', () {
      final source = File('lib/screens/twitch/twitch_screen.dart').readAsStringSync();
      expect(source, contains('LiveFeedScreen()'), reason: 'nincs app-chat a stream alatt');
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
