import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/event_submission.dart';

void main() {
  test('az eseménybeküldés API mezőneveit és műfajait küldi', () {
    const submission = EventSubmission(
      title: ' Teszt esemény ',
      startDate: '2026-08-15',
      startTime: '22:00',
      venueName: ' Stenk ',
      venueCity: ' Budapest ',
      organizerName: ' HUHS ',
      genres: ['Hardstyle', 'Rawstyle'],
      contactEmail: ' test@example.com ',
      eventUrl: ' https://example.com/event ',
      description: ' Leírás ',
    );

    expect(submission.toJson(), {
      'title': 'Teszt esemény',
      'start_date': '2026-08-15',
      'start_time': '22:00',
      'end_date': '',
      'end_time': '',
      'venue_name': 'Stenk',
      'venue_city': 'Budapest',
      'venue_address': '',
      'organizer_name': 'HUHS',
      'organizer_id': 0,
      'genres': ['Hardstyle', 'Rawstyle'],
      'contact_email': 'test@example.com',
      'event_url': 'https://example.com/event',
      'description': 'Leírás',
      'flyer_url': '',
      'website': '',
    });
  });
}
