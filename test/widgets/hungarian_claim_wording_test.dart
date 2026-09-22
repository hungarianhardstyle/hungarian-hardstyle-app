import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A „Claim" szó **magyar** megnevezésének bizonyítása.
///
/// A tulajdonos kérése (2026-09-22): *„a Claim helyett jó lenne valami rendes
/// magyar megfelelő és természetesen javítani mindenhol ahol szerepel ez a szó"*.
///
/// A döntés a kérdező ablakban: **„Adatlap átvétele"**. Az alakok:
///   - gomb: „Adatlap átvétele"
///   - átvett állapot: „Ez a te DJ-adatlapod." + „Átvétel visszavonása"
///   - foglalt: „Ezt a DJ-adatlapot már átvette egy fiók."
///   - kártya a profilon: „Átvett DJ-adatlap"
///
/// ⚠️ A **kód belső nevei szándékosan változatlanok** (`claimArtistProfile`,
/// `ArtistClaimStatus`, `artist_claims`) — azok nem látszanak a felhasználónak,
/// és a callable átnevezése szerver- és kliensoldali egyeztetést igényelne
/// kockázat nélküli haszon helyett. Ez a teszt ezért a **látható szövegeket**
/// méri.
void main() {
  String read(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  const screens = [
    'lib/screens/artists/artist_detail_screen.dart',
    'lib/screens/more/community_users_screen.dart',
  ];

  test('a felületen NEM maradt „claim" szó', () {
    for (final path in screens) {
      final source = read(path);
      // A `Text(...)` és `SnackBar(...)` tartalmak a felhasználónak szólnak.
      final visible = RegExp(
        r"""(Text\(\s*(?:const\s*)?'|content:\s*Text\('|tooltip:\s*')([^']*)'""",
      ).allMatches(source).map((match) => match.group(2) ?? '');
      for (final text in visible) {
        expect(
          text.toLowerCase().contains('claim'),
          isFalse,
          reason: '$path: látható szövegben maradt a „claim": „$text"',
        );
      }
    }
  });

  test('az új magyar szavak ott vannak, ahol kellenek', () {
    final artist = read('lib/screens/artists/artist_detail_screen.dart');
    expect(artist.contains("'Adatlap átvétele'"), isTrue);
    expect(artist.contains("'Átvétel visszavonása'"), isTrue);
    expect(artist.contains("'Ez a te DJ-adatlapod.'"), isTrue);
    expect(artist.contains("'Ezt a DJ-adatlapot már átvette egy fiók.'"), isTrue);
    expect(artist.contains("'Az adatlap átvétele sikerült.'"), isTrue);
    expect(artist.contains("'Az átvétel visszavonva.'"), isTrue);

    final users = read('lib/screens/more/community_users_screen.dart');
    expect(users.contains("'Átvett DJ-adatlap'"), isTrue);
    // A szekció címe is magyar marad.
    expect(users.contains("'DJ-adatlap'"), isTrue);
  });

  test('a belső nevek VÁLTOZATLANOK (a szerver-szerződés nem tört el)', () {
    final service = read('lib/services/community_service.dart');
    expect(service.contains("'claimArtistProfile'"), isTrue);
    expect(service.contains("'getArtistClaimStatus'"), isTrue);
    expect(service.contains("'releaseArtistClaim'"), isTrue);
    final status = read('lib/models/artist_claim_status.dart');
    expect(status.contains('class ArtistClaimStatus'), isTrue);
  });
}
