import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/content_link_route.dart';

// A MÉRT permalink-alakok (2026-09-28) — ezek a valódi linkek, nem kitaláltak.
const _eventLink =
    'https://hungarianhardstyle.hu/events/hard-base-classic-keephardstylehardstyle/';
const _releaseLink =
    'https://hungarianhardstyle.hu/releases/goze-change-of-pace/';
const _artistLink = 'https://hungarianhardstyle.hu/djs/adam-bass/';
const _newsLink =
    'https://hungarianhardstyle.hu/2026/09/26/hard-bass-2026-himnusz/';
const _inviteLink = 'https://hungarianhardstyle.hu/invite/ABC123';
const _shortLink = 'https://hungarianhardstyle.hu/?p=12505';

void main() {
  test('az esemény-link eseményt ad, a sluggal', () {
    final route = contentLinkRouteFromUri(Uri.parse(_eventLink));
    expect(route.kind, ContentLinkKind.event);
    expect(route.slug, 'hard-base-classic-keephardstylehardstyle');
    expect(route.id, isNull, reason: 'a permalink nem hordoz azonosítót');
    expect(route.isNavigable, isFalse, reason: 'a slugot előbb fel kell oldani');
  });

  test('a kiadvány- és a DJ-link a saját típusát adja', () {
    expect(
      contentLinkRouteFromUri(Uri.parse(_releaseLink)).kind,
      ContentLinkKind.release,
    );
    final artist = contentLinkRouteFromUri(Uri.parse(_artistLink));
    expect(artist.kind, ContentLinkKind.artist);
    expect(artist.slug, 'adam-bass');
  });

  test('a hír a DÁTUM-alapú permalinkról is felismerhető', () {
    final route = contentLinkRouteFromUri(Uri.parse(_newsLink));
    expect(route.kind, ContentLinkKind.news);
    expect(route.slug, 'hard-bass-2026-himnusz');
  });

  test('a meghívó kódot kiadja (és az azonnal nyitható)', () {
    final route = contentLinkRouteFromUri(Uri.parse(_inviteLink));
    expect(route.kind, ContentLinkKind.invite);
    expect(route.inviteCode, 'ABC123');
    expect(route.isNavigable, isTrue);
  });

  test('a rövidlink az azonosítót adja, típus nélkül', () {
    final route = contentLinkRouteFromUri(Uri.parse(_shortLink));
    expect(route.kind, ContentLinkKind.unknown);
    expect(route.id, 12505);
    expect(route.isNavigable, isTrue);
  });

  test('idegen domain és séma nem belső link', () {
    expect(
      contentLinkRouteFromUri(Uri.parse('https://example.com/events/x/')).kind,
      ContentLinkKind.unknown,
    );
    expect(
      contentLinkRouteFromUri(Uri.parse('huhs://events/x')).kind,
      ContentLinkKind.unknown,
    );
    expect(contentLinkRouteFromUri(null).kind, ContentLinkKind.unknown);
    expect(
      contentLinkRouteFromUri(Uri.parse('https://hungarianhardstyle.hu')).kind,
      ContentLinkKind.unknown,
    );
  });

  test('a www-s host és a nagybetűs útvonal is működik', () {
    expect(
      contentLinkRouteFromUri(
        Uri.parse('https://www.hungarianhardstyle.hu/Events/Valami/'),
      ).kind,
      ContentLinkKind.event,
    );
    expect(isAppHost('WWW.HungarianHardstyle.HU'), isTrue);
    expect(isAppHost('play.google.com'), isFalse);
  });

  test('forrás-lint: a manifest fogja a mért útvonalakat', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final prefix in ['/invite', '/events', '/releases', '/djs']) {
      expect(
        manifest,
        contains('android:pathPrefix="$prefix"'),
        reason: 'a $prefix útvonalat fel kell oldania az appnak',
      );
    }
    expect(manifest, contains('android:autoVerify="true"'));
  });
}
