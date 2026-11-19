import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/event.dart';
import 'package:hungarian_hardstyle_app/services/people_suggestions.dart';
import 'package:hungarian_hardstyle_app/services/timetable_artists.dart';
import 'package:hungarian_hardstyle_app/services/tonight_plan.dart';

HuhsEvent _event({
  int id = 1,
  String start = '2026-11-21',
  String startTime = '22:00',
  String end = '2026-11-22',
  String endTime = '05:00',
  List<Map<String, dynamic>> artists = const [],
}) => HuhsEvent.fromJson({
  'id': id,
  'title': 'Buli $id',
  'start_date': start,
  'start_time': startTime,
  'end_date': end,
  'end_time': endTime,
  'artists': artists,
});

void main() {
  group('időbeosztás → DJ', () {
    final e = _event(artists: [
      {'id': 11731, 'name': 'Höfstätters'},
      {'id': 11727, 'name': 'Dr Skull'},
    ]);

    test('ékezet- és írásjel-független névegyezés', () {
      expect(timetableArtistId(e, 'Höfstatters'), 11731);
      expect(timetableArtistId(e, 'Dr. Skull'), 11727);
      expect(timetableArtistId(e, ' dr  skull '), 11727);
    });

    test('ismeretlen vagy üres név nem ad azonosítót', () {
      expect(timetableArtistId(e, 'Ismeretlen DJ'), isNull);
      expect(timetableArtistId(e, ''), isNull);
      expect(timetableArtistId(_event(), 'Dr Skull'), isNull);
    });
  });

  group('mai bulik', () {
    final now = DateTime(2026, 11, 21, 12);

    test('ma kezdődő és éjfél után is tartó bulik, kezdés szerint', () {
      final later = _event(id: 2, startTime: '23:00');
      final sooner = _event(id: 1, startTime: '20:00');
      final tomorrow = _event(id: 3, start: '2026-11-22', end: '2026-11-23');
      expect(todaysEvents([later, tomorrow, sooner], now).map((e) => e.id), [1, 2]);
      // Éjfél után az előző napi, még tartó buli is „ma esti".
      expect(todaysEvents([later], DateTime(2026, 11, 22, 3)).map((e) => e.id), [2]);
    });

    test('a vége után már nem, dátum nélkül sosem', () {
      expect(todaysEvents([_event()], DateTime(2026, 11, 22, 5, 1)), isEmpty);
      expect(todaysEvents([_event(start: '')], now), isEmpty);
    });
  });

  group('kit ismerhetek', () {
    test('közös buliszám szerint csökkenő, magad és a kizártak nélkül', () {
      final ranked = rankSuggestions(
        {
          1: ['me', 'a', 'b', 'friend'],
          2: ['a', 'c', 'friend'],
          3: ['a', 'b', 'b'],
        },
        me: 'me',
        exclude: {'friend'},
      );
      expect(ranked.map((r) => r.uid), ['a', 'b', 'c']);
      expect(ranked.map((r) => r.shared), [3, 2, 1]);
    });

    test('a limit szab határt, üres bemenetre üres lista', () {
      expect(
        rankSuggestions({1: ['a', 'b', 'c']}, me: 'x', limit: 2).length,
        2,
      );
      expect(rankSuggestions({}, me: 'x'), isEmpty);
    });
  });
}
