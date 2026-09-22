import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/artist.dart';
import 'package:hungarian_hardstyle_app/services/artist_profile_form.dart';

/// Az átvett DJ-adatlap **szerkesztő űrlapjának** bizonyítása.
///
/// A tulajdonos kérése (2026-09-22): *„Aki claimelte a dj adatlapját, tudja
/// szerkeszteni is."*
void main() {
  Artist artist({
    String title = 'DJ Példa',
    String realName = 'Példa Béla',
    String city = 'Budapest',
    String country = 'HU',
    String biography = 'Bemutatkozás',
    Map<String, String> socials = const {'instagram': 'https://instagram.com/x'},
  }) => Artist(
    id: 12699,
    title: title,
    slug: 'dj-pelda',
    biography: biography,
    excerpt: '',
    realName: realName,
    country: country,
    city: city,
    genres: const ['Hardstyle'],
    categories: const [],
    logoUrl: '',
    profileImageUrl: 'https://res.cloudinary.com/fjxo93em/image/upload/old.jpg',
    featured: false,
    visible: true,
    webUrl: '',
    bookingEmail: 'info@hungarianhardstyle.hu',
    bookingViaHuhs: true,
    socialLinks: socials,
    upcomingEvents: const [],
  );

  group('kezdőértékek', () {
    test('a nyilvános adatlapból tölti fel az űrlapot', () {
      final initial = artistProfileFormInitial(
        artist(socials: const {'instagram': 'https://instagram.com/x'}),
      );
      expect(initial['title'], 'DJ Példa');
      expect(initial['realName'], 'Példa Béla');
      expect(initial['city'], 'Budapest');
      expect(initial['biography'], 'Bemutatkozás');
      expect(initial['instagram'], 'https://instagram.com/x');
      // A hiányzó linkek üresen jelennek meg (nem hibásan).
      expect(initial['website'], '');
      expect(initial.containsKey('bookingEmail'), isFalse);
    });
  });

  group('csak a megváltozott mezők mennek ki', () {
    test('változatlan űrlap → üres kimenet', () {
      final a = artist();
      final fields = changedArtistProfileFields(
        initial: artistProfileFormInitial(a),
        values: artistProfileFormInitial(a),
      );
      expect(fields, isEmpty);
    });

    test('egy mező változása csak azt küldi', () {
      final a = artist();
      final values = artistProfileFormInitial(a)..['city'] = 'Szeged';
      final fields = changedArtistProfileFields(
        initial: artistProfileFormInitial(a),
        values: values,
      );
      expect(fields, {'city': 'Szeged'});
    });

    test('a közösségi linkek egy csomagban mennek', () {
      final a = artist();
      final values = artistProfileFormInitial(a)
        ..['instagram'] = 'https://instagram.com/uj'
        ..['website'] = 'https://peldadj.hu';
      final fields = changedArtistProfileFields(
        initial: artistProfileFormInitial(a),
        values: values,
      );
      expect(fields['socialLinks'], {
        'instagram': 'https://instagram.com/uj',
        'website': 'https://peldadj.hu',
      });
      expect(fields.containsKey('instagram'), isFalse);
    });

    test('a link kiürítése is változás (törlés)', () {
      final a = artist(socials: const {'spotify': 'https://open.spotify.com/x'});
      final values = artistProfileFormInitial(a)..['spotify'] = '';
      final fields = changedArtistProfileFields(
        initial: artistProfileFormInitial(a),
        values: values,
      );
      expect(fields['socialLinks'], {'spotify': ''});
    });

    test('üres név nem megy ki (a szerver sem fogadná)', () {
      final a = artist();
      final values = artistProfileFormInitial(a)..['title'] = '   ';
      final fields = changedArtistProfileFields(
        initial: artistProfileFormInitial(a),
        values: values,
      );
      expect(fields.containsKey('title'), isFalse);
    });

    test('az új képek URL-je bekerül', () {
      final a = artist();
      final fields = changedArtistProfileFields(
        initial: artistProfileFormInitial(a),
        values: artistProfileFormInitial(a),
        profileImageUrl: 'https://res.cloudinary.com/fjxo93em/image/upload/uj.jpg',
        coverImageUrl: 'https://res.cloudinary.com/fjxo93em/image/upload/borito.jpg',
      );
      expect(fields['profileImageUrl'], contains('uj.jpg'));
      expect(fields['coverImageUrl'], contains('borito.jpg'));
    });
  });

  group('⚠️ tiltott mezők soha nem mennek ki', () {
    test('a booking e-mail és a ház döntései kiszűrve', () {
      // A booking e-mail igazolja az átvételt: ha a DJ átírhatná, egy másik
      // fiók is átvehetné az adatlapot.
      final a = artist();
      final values = artistProfileFormInitial(a)..['city'] = 'Győr';
      final fields = changedArtistProfileFields(
        initial: artistProfileFormInitial(a),
        values: values,
      );
      for (final forbidden in artistProfileForbiddenKeys) {
        expect(fields.containsKey(forbidden), isFalse, reason: forbidden);
      }
      expect(
        artistProfileForbiddenKeys,
        containsAll(<String>[
          'booking_email',
          'contact_email',
          'visible',
          'featured',
          'genre',
        ]),
      );
    });
  });

  group('ügyféloldali ellenőrzés (a szerver a végső szó)', () {
    test('üres és túl hosszú név', () {
      expect(artistProfileFormErrors({'title': '  '})['title'], isNotNull);
      expect(
        artistProfileFormErrors({'title': 'x' * 121})['title'],
        contains('120'),
      );
      expect(artistProfileFormErrors({'title': 'Rendes név'}), isEmpty);
    });

    test('a link csak teljes http(s) cím lehet', () {
      final errors = artistProfileFormErrors({
        'title': 'DJ',
        'instagram': 'instagram.com/x',
        'website': 'javascript:alert(1)',
      });
      expect(errors['instagram'], isNotNull);
      expect(errors['website'], isNotNull);
      expect(artistProfileFormErrors({'title': 'DJ', 'facebook': ''}), isEmpty);
    });

    test('a hosszú bemutatkozás jelezve van', () {
      final errors = artistProfileFormErrors({
        'title': 'DJ',
        'biography': 'x' * 6001,
      });
      expect(errors['biography'], contains('6000'));
    });
  });

  group('FORRÁS-LINT: a képernyő és a szolgáltatás bekötése', () {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    test('a szerkesztő gomb CSAK átvett adatlapnál jelenik meg', () {
      final detail = read('lib/screens/artists/artist_detail_screen.dart');
      expect(detail.contains('ArtistEditScreen(artist: artist)'), isTrue);
      expect(detail.contains('if (claim.mine)'), isTrue);
      expect(detail.contains("'Adatlap szerkesztése'"), isTrue);
      // A gomb a claim-állapot blokkjában van, nem feltétel nélkül.
      final guard = detail.indexOf('if (claim.mine)');
      final button = detail.indexOf('ArtistEditScreen(artist: artist)');
      expect(button, greaterThan(guard));
    });

    test('a szerkesztő képernyő a közös Cloudinary-utat és a callable-t használja', () {
      final source = read('lib/screens/artists/artist_edit_screen.dart');
      expect(source.contains('uploadProfileImage('), isTrue);
      expect(source.contains('updateClaimedArtistProfile('), isTrue);
      expect(source.contains('changedArtistProfileFields('), isTrue);
      expect(source.contains('artistProfileFormErrors('), isTrue);
      // A frissítés után a nyilvános adatlap és a lista újratölt.
      expect(source.contains('invalidate(artistDetailProvider('), isTrue);
      expect(source.contains('invalidate(artistsProvider)'), isTrue);
      // Megmondja, mi NEM szerkeszthető (ne is keresse a DJ).
      expect(source.contains('foglalási e-mail cím'), isTrue);
    });

    test('a szolgáltatás a szerver callable-t hívja, mezőkkel', () {
      final source = read('lib/services/community_service.dart');
      final start = source.indexOf('Future<List<String>> updateClaimedArtistProfile(');
      expect(start, greaterThan(0), reason: 'nincs updateClaimedArtistProfile');
      final body = source.substring(start, start + 1200);
      expect(body.contains("'updateClaimedArtistProfile'"), isTrue);
      expect(body.contains("'artistId': artistId"), isTrue);
      expect(body.contains("'fields': fields"), isTrue);
      expect(body.contains('emailVerified != true'), isTrue);
    });

    test('a feltöltő út publikus és a beküldésivel azonos', () {
      final source = read('lib/services/wordpress_service.dart');
      expect(
        source.contains('Future<String> uploadProfileImage(SubmissionImage image)'),
        isTrue,
      );
      expect(source.contains('_uploadCloudinaryImage(image)'), isTrue);
    });
  });
}
