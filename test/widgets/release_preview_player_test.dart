import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/release.dart';
import 'package:hungarian_hardstyle_app/widgets/release_preview_player.dart';

/// A tulajdonos jelzése: „az appban nincs lejátszó a Goze oldalán".
///
/// A főoldali kiadvány-részletoldal a `ReleasePreviewPlayer`-t minden trackhez
/// kirajzolja. A szöveg akkor vált „Preview még nem érhető el."-re, ha a
/// `preview_url` üres. Ez a teszt a KÉT ágat rögzíti, és a valódi API-alakból
/// indul (`tracks: [{title, preview_url}]`), hogy a lánc (JSON → modell →
/// widget) ott bukjon el, ahol kell, ha valaha elromlik.
void main() {
  const apiTrack = {
    'title': 'Goze - Change of Pace',
    'preview_url':
        'https://hungarianhardstyle.hu/wp-content/uploads/2026/09/'
            'huhs-release-12699-preview-1789739500.mp3',
  };

  test('az API-alak (tracks[].preview_url) atmegy a modellen', () {
    final release = HuhsRelease.fromJson({
      'id': 12699,
      'title': 'Goze - Change of Pace',
      'release_date': '2026-09-25',
      'is_upcoming': true,
      'presave_url': 'https://hypeddit.com/changeofpace',
      'tracks': [apiTrack],
      'versions': [
        {'type': 'radio', 'available': true},
      ],
      'audio_status': 'ready',
    });

    expect(release.tracks, hasLength(1));
    expect(release.tracks.first.title, 'Goze - Change of Pace');
    expect(release.tracks.first.previewUrl, contains('huhs-release-12699'));
    expect(release.isUpcoming, isTrue);
  });

  testWidgets('ervenyes preview_url-nel lejatszo ikonok jelennek meg', (
    tester,
  ) async {
    final track = ReleaseTrack.fromJson(Map<String, dynamic>.from(apiTrack));
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ReleasePreviewPlayer(track: track, index: 0))),
    );

    expect(find.textContaining('Goze - Change of Pace'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    expect(find.byIcon(Icons.stop_circle), findsOneWidget);
    // A „még nem érhető el" szöveg CSAK üres URL-nél szabad, hogy megjelenjen.
    expect(find.textContaining('még nem érhető el'), findsNothing);
  });

  testWidgets('ures preview_url-nel a tartalek sor jelenik meg, nem lejatszo', (
    tester,
  ) async {
    const track = ReleaseTrack(title: 'Goze - Change of Pace', previewUrl: '');
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ReleasePreviewPlayer(track: track, index: 0))),
    );

    expect(find.textContaining('még nem érhető el'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);
  });
}
