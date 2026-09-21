import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/label_playlist_membership.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A „kivett a lejátszási listáról" emlékezetének bizonyítása.
///
/// MIÉRT FONTOS: ez az emlékezet **személyes döntés** (ki mit nem akar hallani),
/// ezért a legfontosabb állítás, hogy **másik fiók nem örökli**. Emellett a
/// hibás tároló nem tüntethet el tételeket a listáról (az a biztonságos irány,
/// hogy minden a listán marad).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  LabelPlaylistMembership store() => LabelPlaylistMembership();

  group('mentés és visszaolvasás', () {
    test('a kivett tétel visszaolvasható', () async {
      await store().save('uid-A', {'305:radio_wav'});
      expect(await store().load('uid-A'), {'305:radio_wav'});
    });

    test('több tétel is kivehető, és a visszatétel csak azt veszi ki', () async {
      final target = store();
      await target.save('uid-A', {'305:radio_wav', '200:mp3_128'});
      expect(await target.load('uid-A'), {'305:radio_wav', '200:mp3_128'});
      await target.save('uid-A', {'200:mp3_128'});
      expect(await target.load('uid-A'), {'200:mp3_128'});
    });

    test('az üres halmaz törli a kulcsot (nem marad üres lista)', () async {
      final target = store();
      await target.save('uid-A', {'305:radio_wav'});
      await target.save('uid-A', <String>{});
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('huhs.music.excluded.uid-A'), isNull);
      expect(await target.load('uid-A'), isEmpty);
    });
  });

  group('fiók-szétválasztás (adatvédelem)', () {
    test('a másik fiók NEM látja az első kivételeit', () async {
      await store().save('uid-A', {'305:radio_wav'});
      expect(await store().load('uid-B'), isEmpty);
    });

    test('a másik fiók a sajátját látja', () async {
      await store().save('uid-A', {'305:radio_wav'});
      await store().save('uid-B', {'777:extended_wav'});
      expect(await store().load('uid-A'), {'305:radio_wav'});
      expect(await store().load('uid-B'), {'777:extended_wav'});
    });

    test('az egyik fiók mentése nem törli a másikét', () async {
      await store().save('uid-A', {'305:radio_wav'});
      await store().save('uid-B', {'777:extended_wav'});
      await store().save('uid-A', <String>{});
      expect(await store().load('uid-A'), isEmpty);
      expect(await store().load('uid-B'), {'777:extended_wav'});
    });

    test('a szóközök nem hoznak létre külön fiókot', () async {
      await store().save(' uid-A ', {'305:radio_wav'});
      expect(await store().load('uid-A'), {'305:radio_wav'});
    });
  });

  group('vendég és hibás adat', () {
    test('üres UID-nál nem írunk és nem olvasunk', () async {
      final target = store();
      expect(target.keyFor(''), isNull);
      expect(target.keyFor('   '), isNull);
      await target.save('', {'305:radio_wav'});
      expect(await target.load(''), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), isEmpty);
    });

    test('hibás JSON esetén üres halmaz, és a hibás kulcs törlődik', () async {
      SharedPreferences.setMockInitialValues({
        'huhs.music.excluded.uid-A': 'ez nem json',
      });
      expect(await store().load('uid-A'), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('huhs.music.excluded.uid-A'), isNull);
    });

    test('a nem-lista JSON sem dob hibát', () async {
      SharedPreferences.setMockInitialValues({
        'huhs.music.excluded.uid-A': '{"key":"305:radio_wav"}',
      });
      expect(await store().load('uid-A'), isEmpty);
    });
  });

  group('a lista kézi sorrendje', () {
    test('a mentett sorrend visszaolvasható, a sorrend megmarad', () async {
      await store().saveOrder('uid-A', ['305:radio_wav', '200:mp3_128']);
      expect(await store().loadOrder('uid-A'), [
        '305:radio_wav',
        '200:mp3_128',
      ]);
    });

    test('a másik fiók nem örökli a sorrendet', () async {
      await store().saveOrder('uid-A', ['305:radio_wav']);
      expect(await store().loadOrder('uid-B'), isEmpty);
    });

    test('üres sorrendnél a kulcs eltűnik', () async {
      final target = store();
      await target.saveOrder('uid-A', ['305:radio_wav']);
      await target.saveOrder('uid-A', const []);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('huhs.music.order.uid-A'), isNull);
      expect(await target.loadOrder('uid-A'), isEmpty);
    });

    test('vendégnél nem írunk és nem olvasunk', () async {
      final target = store();
      await target.saveOrder('', ['305:radio_wav']);
      expect(await target.loadOrder(''), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), isEmpty);
    });

    test('hibás JSON esetén üres sorrend, és a kulcs törlődik', () async {
      SharedPreferences.setMockInitialValues({
        'huhs.music.order.uid-A': 'ez nem json',
      });
      expect(await store().loadOrder('uid-A'), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('huhs.music.order.uid-A'), isNull);
    });

    test('a sorrend tisztítása megőrzi a sorrendet, a szemetet eldobja', () {
      expect(
        sanitizeOrderKeys([
          '305:radio_wav',
          'nem-jo',
          '200:mp3_128',
          '305:radio_wav',
          0,
        ]),
        ['305:radio_wav', '200:mp3_128'],
      );
    });

    test('a ki/be kapcsolás és a sorrend NEM ugyanaz a kulcs', () async {
      // Ha ugyanaz lenne, a kivétel felülírná a sorrendet (és fordítva).
      final target = store();
      await target.save('uid-A', {'305:radio_wav'});
      await target.saveOrder('uid-A', ['200:mp3_128']);
      expect(await target.load('uid-A'), {'305:radio_wav'});
      expect(await target.loadOrder('uid-A'), ['200:mp3_128']);
    });
  });

  group('a kulcsok tisztítása (tiszta függvény)', () {    test('csak a kiadvány:változat alak marad meg', () {
      expect(
        sanitizeExcludedKeys([
          '305:radio_wav',
          ' 200:mp3_128 ',
          'nem-jo',
          '305',
          '0:radio_wav',
          '-3:radio_wav',
          '305:',
          ':radio_wav',
          '305:radio_wav:extra',
          12,
          null,
        ]),
        {'305:radio_wav', '200:mp3_128'},
      );
    });

    test('a duplikációt összevonja', () {
      expect(
        sanitizeExcludedKeys(['305:radio_wav', '305:radio_wav']),
        {'305:radio_wav'},
      );
    });

    test('üres bemenetre üres halmaz', () {
      expect(sanitizeExcludedKeys(const []), isEmpty);
    });
  });
}
