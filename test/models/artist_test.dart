import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/artist.dart';

void main() {
  test('a profile_image mezőt és a közelgő eseményeket használja', () {
    final artist = Artist.fromJson({
      'id': 12,
      'title': 'Denoiser',
      'profile_image': 'https://example.com/profile.jpg',
      'booking_email': 'booking@example.com',
      'booking_via_huhs': true,
      'hero_image': 'https://example.com/legacy.jpg',
      'genres': ['Hardstyle', 'Rawstyle'],
      'categories': [
        {'id': 1, 'name': 'Hardstyle', 'slug': 'hardstyle'},
      ],
      'social_links': {
        'facebook': 'https://facebook.com/example',
        'spotify': '',
      },
      'upcoming_events': [
        {
          'id': 99,
          'title': 'Teszt esemény',
          'start_date': '2026-08-15',
          'flyer': 'https://example.com/flyer.jpg',
        },
      ],
    });

    expect(artist.profileImageUrl, 'https://example.com/profile.jpg');
    expect(artist.bookingEmail, 'booking@example.com');
    expect(artist.bookingViaHuhs, isTrue);
    expect(artist.effectiveBookingEmail, 'info@hungarianhardstyle.hu');
    expect(artist.categories.single.slug, 'hardstyle');
    expect(artist.socialLinks.keys, ['facebook']);
    expect(artist.upcomingEvents.single.title, 'Teszt esemény');
    expect(
      artist.upcomingEvents.single.flyerUrl,
      'https://example.com/flyer.jpg',
    );
  });

  test('régi válasznál a hero_image a profilkép tartaléka', () {
    final artist = Artist.fromJson({
      'id': 13,
      'title': 'Legacy DJ',
      'hero_image': 'https://example.com/legacy.jpg',
    });

    expect(artist.profileImageUrl, 'https://example.com/legacy.jpg');
  });

  test('sajat booking cim hasznalhato HUHS szervezes nelkul', () {
    final artist = Artist.fromJson({
      'id': 14,
      'title': 'Booking DJ',
      'booking_email': 'booking@example.com',
      'booking_via_huhs': false,
    });

    expect(artist.effectiveBookingEmail, 'booking@example.com');
  });
}
