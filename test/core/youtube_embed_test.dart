import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/media/youtube_embed.dart';

/// A YouTube-videó **appon belüli** lejátszása.
///
/// A tulajdonos jelzése: *„a cikkekben lévő youtube linket az appban le tudja
/// játszani a play gombra, most youtube appot nyitja meg"*.
///
/// A beágyazás WebView-ban három dolgon szokott elhasalni — mind a három
/// **mérhető**, ezért itt mérjük is:
///   1. **origin/hivatkozó** nélkül a YouTube „Video unavailable" hibát ad →
///      a lejátszó saját HTML-ben van, és a `baseUrl` adja az origin-t;
///   2. a WebView `wv` user-agentjét a YouTube elutasíthatja → explicit Chrome-fejléc;
///   3. JavaScript nélkül a lejátszó el sem indul (a kártya bekapcsolja).
///
/// A valódi lejátszást (hang, kép) csak telefonon lehet igazolni — ez a teszt a
/// **konfigurációt** és az azonosító-kinyerést zárja le, hogy a hiba ne tudjon
/// visszakúszni.
void main() {
  group('videó-azonosító kinyerése (a valódi cikkekből mért alakok)', () {
    test('watch?v= — a legegyszerűbb alak', () {
      expect(
        youTubeVideoId('https://www.youtube.com/watch?v=x4wKQ6zbQzE'),
        'x4wKQ6zbQzE',
      );
    });

    test('watch — a v NEM az első paraméter', () {
      expect(
        youTubeVideoId(
          'https://www.youtube.com/watch?feature=shared&v=x4wKQ6zbQzE',
        ),
        'x4wKQ6zbQzE',
      );
    });

    test('a HTML-entity (&amp;) és a JSON-escape (\\u0026) is kezelt', () {
      expect(
        youTubeVideoId('https://www.youtube.com/watch?feature=shared&amp;v=abc123'),
        'abc123',
      );
      expect(
        youTubeVideoId(
          r'https://www.youtube.com/watch?feature=shared\u0026v=abc123',
        ),
        'abc123',
      );
    });

    test('youtu.be rövid link', () {
      expect(youTubeVideoId('https://youtu.be/4GqDZ_Dp_2I'), '4GqDZ_Dp_2I');
      expect(youTubeVideoId('https://youtu.be/4GqDZ_Dp_2I?t=42'), '4GqDZ_Dp_2I');
    });

    test('shorts, embed és live alak', () {
      expect(
        youTubeVideoId('https://www.youtube.com/shorts/SHORT123'),
        'SHORT123',
      );
      expect(
        youTubeVideoId('https://www.youtube.com/embed/EMBED123'),
        'EMBED123',
      );
      expect(youTubeVideoId('https://www.youtube.com/live/LIVE123'), 'LIVE123');
    });

    test('séma nélküli és http-s link is működik (https-re váltva)', () {
      expect(youTubeVideoId('www.youtube.com/watch?v=abc123'), 'abc123');
      expect(youTubeVideoId('http://youtu.be/abc123'), 'abc123');
    });

    test('az azonosító körüli szemét (szóköz, láthatatlan karakter) nem zavar', () {
      expect(
        youTubeVideoId('  https://youtu.be/abc123\u200B  '),
        'abc123',
      );
    });

    test('nem YouTube linkből NEM talál ki azonosítót', () {
      expect(youTubeVideoId('https://example.com/watch?v=abc123'), isNull);
      expect(youTubeVideoId('https://vimeo.com/123456'), isNull);
      expect(youTubeVideoId('https://www.youtube.com/'), isNull);
      expect(youTubeVideoId('https://www.youtube.com/@HungarianHardstyle'), isNull);
      expect(youTubeVideoId(''), isNull);
      expect(youTubeVideoId('   '), isNull);
    });
  });

  group('a beágyazó konfiguráció (ez a „Video unavailable" elleni védelem)', () {
    test('a baseUrl valódi, HTTPS origin — enélkül nincs hivatkozó', () {
      final uri = Uri.parse(youTubeEmbedBaseUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
      expect(
        youTubeEmbedBaseUrl,
        isNot(contains('about:blank')),
        reason: 'az about:blank originnel a YouTube elutasítja a lejátszást',
      );
    });

    test('a user-agent Chrome-fejléc (nem a WebView „wv" jelzése)', () {
      expect(youTubeEmbedUserAgent, contains('Chrome/'));
      expect(youTubeEmbedUserAgent, contains('Mobile'));
      expect(
        youTubeEmbedUserAgent,
        isNot(contains('; wv')),
        reason: 'a wv-s fejlécet a YouTube nem támogatott böngészőnek látja',
      );
    });

    test('a lejátszó címe appon belüli lejátszást kér (playsinline)', () {
      final uri = youTubeEmbedUri('abc123');
      expect(uri.host, 'www.youtube.com');
      expect(uri.path, '/embed/abc123');
      expect(uri.queryParameters['playsinline'], '1');
      expect(uri.queryParameters['rel'], '0');
    });

    test('a HTML tartalmazza a lejátszót, az engedélyeket és az origin-t', () {
      final html = youTubeEmbedHtml('abc123');
      expect(html, contains('https://www.youtube.com/embed/abc123'));
      expect(html, contains('playsinline=1'));
      expect(html, contains('allowfullscreen'));
      expect(html, contains('referrerpolicy="origin"'));
      expect(html, contains('name="referrer" content="origin"'));
      expect(html, contains('width=device-width'));
      expect(html, contains('encrypted-media'), reason: 'DRM-es videókhoz kell');
    });
  });

  group('a kártya bekötése (forrás-lint)', () {
    late String source;

    setUpAll(() {
      source = File('lib/widgets/post_embed_card.dart').readAsStringSync();
    });

    test('a YouTube NEM esik ki a WebView-ból (ez volt a hiba)', () {
      expect(
        source,
        isNot(contains("widget.embed.type == 'youtube') return;")),
        reason: 'a korábbi kód a YouTube-ot kihagyta, és külső appot nyitott',
      );
    });

    test('a videót HTML-lel, valódi baseUrl-lel töltjük be', () {
      expect(source, contains('loadHtmlString('));
      expect(source, contains('baseUrl: youTubeEmbedBaseUrl'));
      expect(source, contains('setUserAgent(youTubeEmbedUserAgent)'));
      expect(source, contains('JavaScriptMode.unrestricted'));
    });

    test('marad külső tartalék, ha a videó beágyazása tiltott', () {
      expect(source, contains('Megnyitás a YouTube-on'));
      expect(source, contains('_openExternal'));
    });

    test('az azonosító nélküli YouTube-link a régi kártyát kapja (nem törik el)', () {
      expect(source, contains('_YouTubeLinkCard'));
      expect(source, contains('youTubeVideoId(widget.embed.url)'));
    });
  });
}
