import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/content_link_resolver.dart';
import 'package:hungarian_hardstyle_app/services/content_link_route.dart';

void main() {
  test('a rövidlinkből azonosítóval kérdezünk (a típus így derül ki)', () {
    final route = contentLinkRouteFromUri(
      Uri.parse('https://hungarianhardstyle.hu/?p=12505'),
    );
    final uri = contentResolveUri(route);
    expect(uri, isNotNull);
    expect(uri!.path, '/wp-json/huhs/v1/resolve');
    expect(uri.queryParameters['p'], '12505');
  });

  test('a permalinkből sluggal kérdezünk', () {
    final route = contentLinkRouteFromUri(
      Uri.parse('https://hungarianhardstyle.hu/releases/goze-change-of-pace/'),
    );
    final uri = contentResolveUri(route);
    expect(uri!.queryParameters['slug'], 'goze-change-of-pace');
    expect(uri.queryParameters.containsKey('p'), isFalse);
  });

  test('meghívó linkre és üres linkre nincs mit feloldani', () {
    expect(
      contentResolveUri(
        contentLinkRouteFromUri(
          Uri.parse('https://hungarianhardstyle.hu/invite/ABC123'),
        ),
      ),
      isNull,
    );
    expect(
      contentResolveUri(contentLinkRouteFromUri(null)),
      isNull,
    );
  });

  test('a válaszból célpont lesz (mind a négy típus)', () {
    for (final entry in {
      'event': ContentLinkKind.event,
      'release': ContentLinkKind.release,
      'artist': ContentLinkKind.artist,
      'news': ContentLinkKind.news,
    }.entries) {
      final target = contentLinkTargetFromJson({
        'ok': true,
        'type': entry.key,
        'id': 42,
        'title': 'Cím',
        'url': 'https://hungarianhardstyle.hu/x/',
      });
      expect(target, isNotNull, reason: entry.key);
      expect(target!.kind, entry.value);
      expect(target.id, 42);
      expect(target.title, 'Cím');
    }
  });

  test('hibás válasz (404, ismeretlen típus, hiányzó id) nem ad célpontot', () {
    expect(contentLinkTargetFromJson(null), isNull);
    expect(contentLinkTargetFromJson({'ok': false}), isNull);
    expect(contentLinkTargetFromJson({'type': 'page', 'id': 5}), isNull);
    expect(contentLinkTargetFromJson({'type': 'event'}), isNull);
    expect(contentLinkTargetFromJson({'type': 'event', 'id': '0'}), isNull);
  });

  test('a feloldás hálózati hibája nem dob (az app nem törhet el)', () async {
    final route = contentLinkRouteFromUri(
      Uri.parse('https://hungarianhardstyle.hu/events/valami/'),
    );
    expect(
      await resolveContentLink(route, (uri) async => throw Exception('hálózat')),
      isNull,
    );
    expect(
      await resolveContentLink(route, (uri) async => null),
      isNull,
    );
    final target = await resolveContentLink(
      route,
      (uri) async => {'type': 'event', 'id': 12505},
    );
    expect(target?.id, 12505);
    expect(target?.kind, ContentLinkKind.event);
  });
}
