import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/profile_submission.dart';

void main() {
  test('a DJ bekuldese tovabbitja a kategoriakat es a HUHS booking opciot', () {
    const submission = ArtistSubmission(
      name: ' Teszt DJ ',
      realName: ' Teszt Elek ',
      categories: ['hardstyle'],
      genres: ['Rawstyle'],
      city: ' Budapest ',
      country: ' Magyarorszag ',
      biography: ' Bemutatkozas ',
      contactEmail: ' contact@example.com ',
      bookingEmail: '',
      bookingViaHuhs: true,
      profileImageUrl: ' https://example.com/profile.jpg ',
      socialLinks: {'instagram': ' https://instagram.com/example '},
    );

    final json = submission.toJson();

    expect(json['name'], 'Teszt DJ');
    expect(json['categories'], ['hardstyle']);
    expect(json['genres'], ['Rawstyle']);
    expect(json['booking_via_huhs'], isTrue);
    expect(json['booking_email'], isEmpty);
    expect(json['instagram'], 'https://instagram.com/example');
    expect(json['website_check'], isEmpty);
  });

  test('a szervezo bekuldese megtartja a publikus linkeket', () {
    const submission = OrganizerSubmission(
      name: ' Teszt Szervezo ',
      city: ' Budapest ',
      country: ' Magyarorszag ',
      description: ' Leiras ',
      contactEmail: ' info@example.com ',
      logoUrl: ' https://example.com/logo.png ',
      socialLinks: {'website': ' https://example.com '},
    );

    final json = submission.toJson();

    expect(json['name'], 'Teszt Szervezo');
    expect(json['contact_email'], 'info@example.com');
    expect(json['logo_url'], 'https://example.com/logo.png');
    expect(json['website'], 'https://example.com');
    expect(json['website_check'], isEmpty);
  });

  test('a bekuldesi opciok kiszurik az ervenytelen elemeket', () {
    final options = ProfileSubmissionOptions.fromJson({
      'genres': ['Hardstyle', '', 12],
      'artist_categories': [
        {'name': 'Hardstyle', 'slug': 'hardstyle'},
        {'name': '', 'slug': 'hibas'},
      ],
    });

    expect(options.genres, ['Hardstyle']);
    expect(options.artistCategories.single.slug, 'hardstyle');
  });
}
