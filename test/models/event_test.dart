import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/event.dart';

void main() {
  test('megőrzi a kapcsolt fellépő és szervező azonosítóját', () {
    final event = HuhsEvent.fromJson({
      'organizer': {'id': 12, 'name': 'Teszt Szervező'},
      'artists': [
        {'id': 34, 'name': 'Teszt DJ'},
      ],
    });

    expect(event.organizer.id, 12);
    expect(event.organizer.name, 'Teszt Szervező');
    expect(event.artists.single.id, 34);
    expect(event.artists.single.name, 'Teszt DJ');
  });

  test('beolvassa az esemény stílusait', () {
    final event = HuhsEvent.fromJson({
      'genres': ['Hardstyle', 'Hardcore'],
    });

    expect(event.genres, ['Hardstyle', 'Hardcore']);
  });
}
