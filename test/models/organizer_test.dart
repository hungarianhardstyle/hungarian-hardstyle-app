import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/organizer.dart';

void main() {
  test('beolvassa a szervező logóját, linkjeit és eseményeit', () {
    final organizer = OrganizerProfile.fromJson({
      'id': 21,
      'title': 'Hungarian Hardstyle',
      'city': 'Budapest',
      'country': 'Magyarország',
      'logo': 'https://example.com/logo.png',
      'genres': ['Hardstyle', 'Hardcore'],
      'social_links': {
        'website': 'https://example.com',
        'facebook': 'https://facebook.com/example',
        'tiktok': '',
      },
      'upcoming_events': [
        {
          'id': 31,
          'title': 'Teszt esemény',
          'description': '<p>Teljes eseményleírás.</p>',
          'start_date': '2026-09-12',
          'facebook_event_url': 'https://facebook.com/events/31',
        },
      ],
    });

    expect(organizer.logoUrl, 'https://example.com/logo.png');
    expect(organizer.genres, ['Hardstyle', 'Hardcore']);
    expect(organizer.location, 'Budapest, Magyarország');
    expect(organizer.socialLinks.length, 2);
    expect(organizer.upcomingEvents.single.id, 31);
    expect(organizer.upcomingEvents.single.description, contains('Teljes'));
    expect(organizer.upcomingEvents.single.hasFacebookEvent, isTrue);
  });
}
