import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/event.dart';
import 'package:hungarian_hardstyle_app/services/event_checkin_service.dart';
import 'package:hungarian_hardstyle_app/services/referral_link_service.dart';
import 'package:hungarian_hardstyle_app/services/tonight_plan.dart';

HuhsEvent _event({
  int id = 1,
  String start = '2026-11-21',
  String startTime = '22:00',
  String end = '2026-11-22',
  String endTime = '05:00',
  bool checkin = true,
  Map<String, dynamic> extra = const {},
}) => HuhsEvent.fromJson({
  'id': id,
  'title': 'Buli $id',
  'start_date': start,
  'start_time': startTime,
  'end_date': end,
  'end_time': endTime,
  'checkin_enabled': checkin,
  'organizer': {'id': 11673, 'name': 'Hungarian Hardstyle'},
  ...extra,
});

void main() {
  test('a buli napján a nap folyamán megjelenik, előtte nem', () {
    final events = [_event()];
    expect(tonightEvent(events, DateTime(2026, 11, 21, 9, 0)), isNotNull);
    expect(tonightEvent(events, DateTime(2026, 11, 20, 20, 0)), isNull);
  });

  test('az éjfél utáni órákban is látszik, a vége után már nem', () {
    final events = [_event()];
    expect(tonightEvent(events, DateTime(2026, 11, 22, 3, 0)), isNotNull);
    expect(tonightEvent(events, DateTime(2026, 11, 22, 5, 1)), isNull);
  });

  test('záró idő nélkül a kezdéstől 10 óráig tart', () {
    final e = _event(end: '', endTime: '');
    expect(eventEndAt(e), DateTime(2026, 11, 22, 8, 0));
  });

  test('több buli közül a korábban kezdődőt mutatja', () {
    final events = [
      _event(id: 2, start: '2026-11-21', startTime: '23:00'),
      _event(id: 1, start: '2026-11-21', startTime: '20:00'),
    ];
    expect(tonightEvent(events, DateTime(2026, 11, 21, 12, 0))!.id, 1);
  });

  test('csak a Hungarian Hardstyle által szervezett buli kerül a kártyára', () {
    final now = DateTime(2026, 11, 21, 12);
    final other = _event(id: 3, extra: {'organizer': {'id': 12079, 'name': 'Noise Conference'}});
    final none = _event(id: 4, extra: {'organizer': {'id': 0, 'name': ''}});
    expect(tonightEvent([other, none], now), isNull);
    expect(tonightEvent([other, _event(id: 5, startTime: '23:00')], now)!.id, 5);
    final byName = _event(id: 6, extra: {'organizer': {'id': 0, 'name': 'Hungarian Hardstyle'}});
    expect(tonightEvent([byName], now)!.id, 6);
  });

  test('dátum nélküli esemény nem jelenik meg', () {
    expect(tonightEvent([_event(start: '')], DateTime(2026, 11, 21, 12)), isNull);
  });

  test('a becsekkolás ablaka: a kezdéskor nyílik, a végén zár', () {
    final e = _event();
    expect(checkinWindowFor(e, DateTime(2026, 11, 21, 21, 30)), CheckinWindow.notYet);
    expect(checkinWindowFor(e, DateTime(2026, 11, 21, 22, 0)), CheckinWindow.open);
    expect(checkinWindowFor(e, DateTime(2026, 11, 22, 4, 59)), CheckinWindow.open);
    expect(checkinWindowFor(e, DateTime(2026, 11, 22, 5, 1)), CheckinWindow.closed);
  });

  test('a nyitás ideje a szerver adata nélkül a buli kezdete', () {
    expect(checkinOpensAtFor(_event()), DateTime(2026, 11, 21, 22));
  });

  test('QR nélküli (kikapcsolt) eseménynél nincs becsekkolás', () {
    expect(
      checkinWindowFor(_event(checkin: false), DateTime(2026, 11, 21, 23)),
      CheckinWindow.none,
    );
  });

  test('az időbeosztás beolvasása; hibás sor kimarad', () {
    final e = _event(extra: {
      'timetable': [
        {'time': '22:00 - 23:30', 'artist': 'Denoiser'},
        {'time': '', 'artist': ''},
        'hibás',
      ],
    });
    expect(e.timetable.length, 1);
    expect(e.timetable.first.artist, 'Denoiser');
    expect(e.hasTimetable, isTrue);
    expect(_event().hasTimetable, isFalse);
  });

  test('a QR felismerése: csak a saját becsekkolási link', () {
    expect(looksLikeCheckinQr('https://hungarianhardstyle.hu/checkin/12/abcdef1234567890'), isTrue);
    for (final bad in [
      'http://hungarianhardstyle.hu/checkin/12/abcdef',
      'https://evil.example/checkin/12/abcdef',
      'https://hungarianhardstyle.hu/news/12',
      'szöveg',
    ]) {
      expect(looksLikeCheckinQr(bad), isFalse, reason: bad);
    }
  });

  test('a becsekkolási link app-linkként is felismerhető (nem takarja el a bemutató)', () {
    final uri = Uri.parse('https://hungarianhardstyle.hu/checkin/12992/abcdef1234567890');
    expect(ReferralLinkService.checkinTargetFromUri(uri), '12992/abcdef1234567890');
    expect(ReferralLinkService.isContentLaunchLink(uri), isTrue);
    expect(ReferralLinkService.checkinTargetFromUri(Uri.parse('https://x.hu/checkin/1/abc')), isNull);
  });

  test('a szolgáltatás a szerver üzenetét adja tovább, és hamis QR-t el sem küld', () async {
    var calls = 0;
    final service = EventCheckinService(caller: (qr) async {
      calls++;
      return {
        'eventId': 12992,
        'title': 'Hard Base',
        'badgeName': 'Hard Base – ott voltam',
        'alreadyCheckedIn': false,
        'points': 30,
      };
    });
    final ok = await service.checkIn('https://hungarianhardstyle.hu/checkin/12992/abcdef1234567890');
    expect(ok.points, 30);
    expect(ok.badgeName, 'Hard Base – ott voltam');
    await expectLater(service.checkIn('https://evil.example/x'), throwsA(isA<EventCheckinException>()));
    expect(calls, 1);
  });
}
