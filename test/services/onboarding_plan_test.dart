import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/onboarding_plan.dart';

typedef _Item = ({String name, List<String> genres});

List<String> _genresOf(_Item item) => item.genres;

void main() {
  test(
    'a műfajok a DJ-kből jönnek, a leggyakoribb elöl, duplikáció nélkül',
    () {
      final genres = availableGenres([
        ['Rawstyle', 'Hardstyle'],
        ['hardstyle', ' Hardstyle '],
        ['Hardcore'],
        ['Hardstyle', ''],
      ]);
      expect(genres, ['Hardstyle', 'Hardcore', 'Rawstyle']);
      expect(availableGenres(const []), isEmpty);
    },
  );

  test('DJ-rangsor: illeszkedés szerint, azonos súlynál stabil sorrend', () {
    final items = <_Item>[
      (name: 'A', genres: ['Hardcore']),
      (name: 'B', genres: ['Rawstyle', 'Hardstyle']),
      (name: 'C', genres: ['Euphoric']),
      (name: 'D', genres: ['rawstyle']),
    ];
    final ranked = rankByGenres(items, _genresOf, {'Rawstyle', 'Hardstyle'});
    expect(ranked.map((i) => i.name), ['B', 'D', 'A', 'C']);
    expect(rankByGenres(items, _genresOf, const {}).map((i) => i.name), [
      'A',
      'B',
      'C',
      'D',
    ]);
  });

  test('főoldal: a stílusodhoz illő bulik előnyt kapnak, de időrendben', () {
    final events = <_Item>[
      for (var i = 0; i < 12; i++)
        (name: 'E$i', genres: i == 7 || i == 9 ? ['Hardcore'] : ['Hardstyle']),
    ];
    final picked = personalizedUpcoming(events, _genresOf, {'Hardcore'});
    expect(picked.map((e) => e.name), ['E0', 'E1', 'E2', 'E7', 'E9']);
  });

  test('főoldal: stílus nélkül pontosan a régi viselkedés (az első 5)', () {
    final events = <_Item>[
      for (var i = 0; i < 8; i++) (name: 'E$i', genres: ['Hardstyle']),
    ];
    expect(
      personalizedUpcoming(events, _genresOf, const {}).map((e) => e.name),
      ['E0', 'E1', 'E2', 'E3', 'E4'],
    );
  });

  test('főoldal: az ablakon túli (távoli) buli nem ugrik előre', () {
    final events = <_Item>[
      for (var i = 0; i < 15; i++)
        (name: 'E$i', genres: i == 14 ? ['Hardcore'] : ['Hardstyle']),
    ];
    expect(
      personalizedUpcoming(events, _genresOf, {'Hardcore'}).map((e) => e.name),
      ['E0', 'E1', 'E2', 'E3', 'E4'],
    );
  });

  test('kevés esemény mellett sem dob', () {
    final events = <_Item>[
      (name: 'E0', genres: ['Hardcore']),
    ];
    expect(personalizedUpcoming(events, _genresOf, {'Hardcore'}).length, 1);
    expect(personalizedUpcoming(<_Item>[], _genresOf, {'Hardcore'}), isEmpty);
  });
}
