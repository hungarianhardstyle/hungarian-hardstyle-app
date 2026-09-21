import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/label_playback_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A „folytatás ott, ahol abbahagytad" emlékezetének bizonyítása.
///
/// MIÉRT FONTOS: a lejátszási pont **személyes adat** (ki mit hallgatott), ezért
/// a legfontosabb állítás az, hogy **másik fiók nem örökli**. Emellett a hibás
/// bejegyzés nem akadályozhatja a lejátszást, és vendégként nem írunk/olvasunk.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  LabelPlaybackMemory memory() => LabelPlaybackMemory();

  const point = LabelPlaybackPoint(
    releaseId: 12345,
    variant: 'radio_wav',
    positionMs: 83000,
  );

  group('mentés és visszaolvasás', () {
    test('a mentett pont visszaolvasható', () async {
      await memory().save('uid-A', point);
      final loaded = await memory().load('uid-A');
      expect(loaded, isNotNull);
      expect(loaded!.releaseId, 12345);
      expect(loaded.variant, 'radio_wav');
      expect(loaded.positionMs, 83000);
      expect(loaded.entryKey, '12345:radio_wav');
    });

    test('a legutóbbi mentés felülírja a korábbit (nem gyűlik szemét)', () async {
      await memory().save('uid-A', point);
      await memory().save(
        'uid-A',
        const LabelPlaybackPoint(
          releaseId: 999,
          variant: 'mp3_128',
          positionMs: 1000,
        ),
      );
      final loaded = await memory().load('uid-A');
      expect(loaded!.releaseId, 999);
    });

    test('a törlés eltünteti a pontot', () async {
      await memory().save('uid-A', point);
      await memory().clear('uid-A');
      expect(await memory().load('uid-A'), isNull);
    });
  });

  group('fiók-szétválasztás (adatvédelem)', () {
    test('a másik fiók NEM látja az első pontját', () async {
      await memory().save('uid-A', point);
      expect(await memory().load('uid-B'), isNull);
    });

    test('a másik fiók a sajátját látja, nem az elsőt', () async {
      await memory().save('uid-A', point);
      await memory().save(
        'uid-B',
        const LabelPlaybackPoint(
          releaseId: 777,
          variant: 'extended_mp3_320',
          positionMs: 5000,
        ),
      );
      expect((await memory().load('uid-A'))!.releaseId, 12345);
      expect((await memory().load('uid-B'))!.releaseId, 777);
    });

    test('az egyik fiók törlése nem törli a másikét', () async {
      await memory().save('uid-A', point);
      await memory().save(
        'uid-B',
        const LabelPlaybackPoint(
          releaseId: 777,
          variant: 'radio_wav',
          positionMs: 1000,
        ),
      );
      await memory().clear('uid-A');
      expect(await memory().load('uid-A'), isNull);
      expect((await memory().load('uid-B'))!.releaseId, 777);
    });

    test('a szóközök nem hoznak létre külön fiókot', () async {
      await memory().save(' uid-A ', point);
      expect((await memory().load('uid-A'))!.releaseId, 12345);
    });
  });

  group('vendég és hibás adat', () {
    test('üres UID-nál nem írunk és nem olvasunk', () async {
      final store = memory();
      expect(store.keyFor(''), isNull);
      expect(store.keyFor('   '), isNull);
      await store.save('', point);
      expect(await store.load(''), isNull);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), isEmpty);
    });

    test('hibás JSON esetén null-t ad, és a hibás bejegyzést törli', () async {
      SharedPreferences.setMockInitialValues({
        'huhs.music.last.uid-A': 'ez nem json',
      });
      expect(await memory().load('uid-A'), isNull);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('huhs.music.last.uid-A'), isNull);
    });

    test('hiányzó/érvénytelen mezőknél nem tippelünk', () async {
      SharedPreferences.setMockInitialValues({
        'huhs.music.last.uid-A': '{"variant":"radio_wav","positionMs":10}',
      });
      expect(await memory().load('uid-A'), isNull);

      SharedPreferences.setMockInitialValues({
        'huhs.music.last.uid-A': '{"releaseId":305,"variant":"  "}',
      });
      expect(await memory().load('uid-A'), isNull);

      SharedPreferences.setMockInitialValues({
        'huhs.music.last.uid-A': '{"releaseId":0,"variant":"radio_wav"}',
      });
      expect(await memory().load('uid-A'), isNull);
    });

    test('a negatív pozíció 0-ra szorul (nem lesz mínusz az órán)', () {
      final loaded = LabelPlaybackPoint.fromJson({
        'releaseId': 305,
        'variant': 'radio_wav',
        'positionMs': -5000,
      });
      expect(loaded!.positionMs, 0);
    });

    test('a tizedes pozíció egészre kerekedik (JSON-tűrés)', () {
      final loaded = LabelPlaybackPoint.fromJson({
        'releaseId': 305,
        'variant': 'radio_wav',
        'positionMs': 1234.7,
      });
      expect(loaded!.positionMs, 1234);
    });
  });
}
