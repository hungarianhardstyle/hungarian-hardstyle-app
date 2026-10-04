import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/now_playing.dart';
import 'package:hungarian_hardstyle_app/services/radio_metadata.dart';

/// A „most szól” kiírása az **értesítésbe és a zárképernyőre** (2026-10-01).
///
/// A tulajdonos kérése: *„kiírhatná itt is a zenét ami szól + zárképernyőn is
/// lehessen látni a radio a real hardstyle fm logóval”*.
///
/// ⚠️ A mérés két rétegből áll: (1) a **Dart** oldal (mi megy ki, mikor), és
/// (2) a **platform-oldali bekötés** (forrás-lint: a natív kód tényleg a
/// médiakártyát és a logót használja-e). Az utóbbi nem helyettesíthető
/// egység-teszttel, ezért a kapu a konkrét sorokat méri.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a kimenő üzenet', () {
    test('a címet, a következőt és az előadót viszi', () {
      final payload = NowPlayingReporter.nowPlayingPayload(
        const RadioMetadata(title: 'LNY TNZ & Nyanda - Light Up Your Life', next: 'Rogue Zero - Walk Away'),
      );
      expect(payload['title'], 'LNY TNZ & Nyanda - Light Up Your Life');
      expect(payload['next'], 'Rogue Zero - Walk Away');
      expect(payload['artist'], 'Real Hardstyle FM');
    });

    test('üres címet NEM küldünk ki (a rádió nem küld metaadatot)', () {
      expect(
        NowPlayingReporter.shouldReport(
          const RadioMetadata(),
          const RadioMetadata(next: 'Valami'),
        ),
        isFalse,
      );
    });

    test('változatlan címet nem küldünk ki újra', () {
      const track = RadioMetadata(title: 'Sub Zero Project - The Project');
      expect(NowPlayingReporter.shouldReport(track, track), isFalse);
    });

    test('az új cím viszont kimegy', () {
      expect(
        NowPlayingReporter.shouldReport(
          const RadioMetadata(title: 'Régi szám'),
          const RadioMetadata(title: 'Új szám'),
        ),
        isTrue,
      );
    });
  });

  group('a kör (Dart-oldal)', () {
    late List<MethodCall> androidCalls;
    late List<MethodCall> appleCalls;

    setUp(() {
      androidCalls = [];
      appleCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NowPlayingReporter.androidChannel, (call) async {
        androidCalls.add(call);
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NowPlayingReporter.appleChannel, (call) async {
        appleCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NowPlayingReporter.androidChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NowPlayingReporter.appleChannel, null);
    });

    test('az első olvasás kimegy MINDKÉT platformra', () async {
      var calls = 0;
      final reporter = NowPlayingReporter(fetch: (_) async {
        calls++;
        return const RadioMetadata(title: 'Hardstyle Masterz');
      });
      await reporter.refresh();
      expect(calls, 1);
      expect(androidCalls.length, 1);
      expect(appleCalls.length, 1);
      expect(androidCalls.first.method, 'metadata');
      expect((androidCalls.first.arguments as Map)['title'], 'Hardstyle Masterz');
    });

    test('a változatlan cím nem megy ki másodszor (nincs felesleges kiírás)', () async {
      final reporter = NowPlayingReporter(
        fetch: (_) async => const RadioMetadata(title: 'Ugyanaz a szám'),
      );
      await reporter.refresh();
      await reporter.refresh();
      expect(androidCalls.length, 1);
    });

    test('a leállítás törli a képernyőn maradt címet', () async {
      final reporter = NowPlayingReporter(
        fetch: (_) async => const RadioMetadata(title: 'Szám'),
      );
      await reporter.refresh();
      await reporter.stop();
      expect(reporter.isRunning, isFalse);
      expect(androidCalls.last.method, 'clear');
      expect(appleCalls.last.method, 'clear');
    });

    test('hálózati hiba nem dob és nem ír ki semmit', () async {
      final reporter = NowPlayingReporter(fetch: (_) async => null);
      await reporter.refresh();
      expect(androidCalls, isEmpty);
      expect(appleCalls, isEmpty);
    });

    test('a frissítési ütem 15 másodperc (a rádió ~4 másodperces blokkjaihoz)', () {
      expect(NowPlayingReporter.refreshInterval, const Duration(seconds: 15));
    });

    test('az állapot-üzenet a helyes nevet és csatornát használja', () async {
      // Az iOS `playbackState`-et ez az üzenet állítja — a névnek egyeznie kell a
      // Swift-oldallal (`case "playing":` stb.).
      //
      // ⚠️ SZÁNDÉKOSAN csatorna nélkül hívjuk (a valódi út!): a 399-ben a
      // `reportState` a **megadott** paraméterekből épített listát, ezért a
      // valódi hívás egyetlen csatornára sem küldött — a teszt viszont explicit
      // csatornával hívott, így **zölden átengedte** a hibát. Most a hívó nem
      // tud csatorna nélkül hívni.
      await NowPlayingReporter.reportState(NowPlayingPlaybackState.paused);
      expect(appleCalls.last.method, 'state');
      expect((appleCalls.last.arguments as Map)['state'], 'paused');
      // Androidon a csatornán nincs `state` kezelő: oda nem küldünk.
      expect(androidCalls.where((call) => call.method == 'state'), isEmpty);
    });

    test('a huzal-nevek stabilak (a Swift ezeket olvassa)', () {
      expect(NowPlayingPlaybackState.playing.wireName, 'playing');
      expect(NowPlayingPlaybackState.paused.wireName, 'paused');
      expect(NowPlayingPlaybackState.stopped.wireName, 'stopped');
    });
  });

  group('a platform-oldali bekötés (forrás-lint)', () {
    test('az Android-szolgáltatás médiakártyát és munkamenetet használ', () {
      final source = File(
        'android/app/src/main/kotlin/hu/hungarianhardstyle/app/RadioPlaybackService.kt',
      ).readAsStringSync();
      expect(source.contains('MediaSession('), isTrue, reason: 'nincs MediaSession');
      expect(source.contains('Notification.MediaStyle()'), isTrue, reason: 'nincs MediaStyle');
      expect(source.contains('setLargeIcon'), isTrue, reason: 'nincs nagy ikon (logó)');
      expect(source.contains('R.drawable.realhardstyle_logo'), isTrue, reason: 'nincs logó-hivatkozás');
      expect(source.contains('MediaMetadata.METADATA_KEY_TITLE'), isTrue, reason: 'nincs cím a metaadatban');
      expect(source.contains('ACTION_METADATA'), isTrue, reason: 'nincs felületi cím-út');
      expect(source.contains('trackTitle.ifBlank { "Real Hardstyle FM" }'), isTrue,
          reason: 'a cím nem a szóló szám (vagy nem esik vissza a rádió nevére)');
    });

    test('a natív olvasó a stream metaadatát kéri (ICY)', () {
      final source = File(
        'android/app/src/main/kotlin/hu/hungarianhardstyle/app/RadioMetadataReader.kt',
      ).readAsStringSync();
      expect(source.contains('Icy-MetaData'), isTrue);
      expect(source.contains('icy-metaint'), isTrue);
      expect(source.contains('StreamTitle'), isTrue);
    });

    test('a MainActivity továbbadja a felületről jövő címet', () {
      final source =
          File('android/app/src/main/kotlin/hu/hungarianhardstyle/app/MainActivity.kt').readAsStringSync();
      expect(source.contains('"metadata" ->'), isTrue);
      expect(source.contains('RadioPlaybackService.ACTION_METADATA'), isTrue);
    });

    test('az iOS „Most szól” panelje be van kötve, a logóval', () {
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(source.contains('MPNowPlayingInfoCenter'), isTrue);
      expect(source.contains('MPMediaItemPropertyTitle'), isTrue);
      expect(source.contains('UIImage(named: "RealHardstyleLogo")'), isTrue);
      expect(source.contains('hu_hs/now_playing'), isTrue);
    });

    test('az iOS a zárképernyő GOMBJÁHOZ az állapotot is beállítja (playbackState)', () {
      // ⚠️ MÉRT HIÁNY (2026-10-03, a tulajdonos jelzése: *„azt mondtad van pause
      // gomb a zárképernyőn és az értesítési sávban a rádió vezérlőn, de nem,
      // nincs”*): a `nowPlayingInfo` (cím + `playbackRate`) önmagában **nem**
      // elég — iOS 13 óta a panel a `playbackState`-ből dönti el, melyik gombot
      // rajzolja. Enélkül a zárképernyőn nem jelenik meg a pause gomb.
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(source.contains('MPNowPlayingInfoCenter.default().playbackState'), isTrue,
          reason: 'a zárképernyő gombja az állapotból rajzolódik');
      expect(source.contains('applyPlaybackState(.playing)'), isTrue);
      expect(source.contains('applyPlaybackState(.paused)'), isTrue);
      expect(source.contains('applyPlaybackState(.stopped)'), isTrue);
      // A Dart-oldal ezen a metóduson küldi az állapotot.
      expect(source.contains('case "state":'), isTrue,
          reason: 'a Dart-oldal állapot-üzenete nem érkezik meg');
      expect(source.contains("case \"playing\":"), isTrue);
    });

    test('a zárképernyő „beragadt play gombja” ellen: rate + szívverés', () {
      // ⚠️ MÉRT GYÖKÉR (2026-10-04, a tulajdonos jelzése: *„play van meg stop és
      // ha rányomok a playre, egy pillre pause lesz belőle aztán visszaáll … és
      // szól a rádió”*): a zárképernyő a `playbackRate`-ből rajzol, és az
      // **beleragadt 0-ba**, mert a `metadata` megőrizte a szótár régi értékét;
      // a „szól” állapot pedig csak egyszer, a kattintáskor ment ki — a hang
      // viszont a stream betöltése után indul.
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(
        source.contains('MPNowPlayingInfoPropertyPlaybackRate: rate(for: lastPlaybackState)'),
        isTrue,
        reason: 'a rate a régi értéket őrzi meg → a play gomb beragad',
      );
      expect(
        source.contains('info[MPNowPlayingInfoPropertyPlaybackRate] = rate(for: lastPlaybackState)'),
        isTrue,
      );
      expect(source.contains('private func rate(for state: MPNowPlayingPlaybackState) -> Double'), isTrue);
      // …a régi „megőrzés” ág pedig eltűnt.
      expect(source.contains('existing[MPNowPlayingInfoPropertyPlaybackRate]'), isFalse,
          reason: 'a megőrző ág hozta vissza a beragadt 0-t');
      // Szívverés: álló rádiónál nincs, szólónál/szüneteltnél 5 másodpercenként ismétel.
      expect(source.contains('Timer.scheduledTimer(withTimeInterval: 5, repeats: true)'), isTrue);
      expect(source.contains('guard lastPlaybackState != .stopped else { return }'), isTrue);
    });

    test('az iOS NEM jelöli élő adásnak (az élő gombkészletben nincs pause)', () {
      // ⚠️ MÉRT GYÖKÉR (2026-10-04, a telefonról olvasott napló): a
      // `MPNowPlayingInfoPropertyIsLiveStream: true` mellett az iOS az **élő adás
      // gombkészletét** rajzolja (play + stop, pause nélkül) — ezért nem is
      // jelenhetett meg pause gomb; ráadásul az iOS a `playbackState`-et eldobja
      // (`Ignoring setPlaybackState because application does not contain
      // entitlement com.apple.mediaremote.set-playback-state`), tehát a
      // zárképernyő gombját a `playbackRate` és ez a jelző dönti el.
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(source.contains('MPNowPlayingInfoPropertyIsLiveStream: true'), isFalse,
          reason: 'az élő jelzővel az iOS nem rajzol pause gombot');
      expect(source.contains('MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0'), isTrue);
      // A diagnosztika `os_log` (az `NSLog` sorai nem jelentek meg a naplóban).
      expect(source.contains('import os'), isTrue);
      expect(source.contains('os_log("HUHS mostszol'), isTrue);
      expect(source.contains('NSLog('), isFalse,
          reason: 'az NSLog sorait nem hozza a syslog — használhatatlan diagnosztika');
    });

    test('a logó tényleg a csomagban van (Android + iOS)', () {
      expect(File('android/app/src/main/res/drawable/realhardstyle_logo.jpg').existsSync(), isTrue);
      expect(
        File('ios/Runner/Assets.xcassets/RealHardstyleLogo.imageset/realhardstyle_logo.jpg').existsSync(),
        isTrue,
      );
      expect(
        File('ios/Runner/Assets.xcassets/RealHardstyleLogo.imageset/Contents.json').existsSync(),
        isTrue,
      );
    });
  });

  /// A **zárképernyő / értesítési sáv** play/pause gombja — 2026-10-03.
  ///
  /// A tulajdonos jelzése: *„azt mondtad van pause gomb a zárképernyőn és az
  /// értesítési sávban a rádió vezérlőn, de nem, nincs”* — **mindkét platformon**.
  /// A gyökér mindkettőn ugyanaz az osztály: a rendszer a **saját** állapotából
  /// rajzol (Android: `MediaSession` `PlaybackState`; iOS: `playbackState`), nem
  /// az értesítés akció-sorából.
  group('a rendszer állapota ki van írva (Android + iOS)', () {
    test('a Dart-oldal minden állapotváltást kiír', () {
      final bar =
          File('lib/widgets/radio_player_bar.dart').readAsStringSync().replaceAll('\r\n', '\n');
      expect(bar, contains('NowPlayingPlaybackState.playing'),
          reason: 'indításkor nem megy ki a „szól” állapot');
      expect(bar, contains('NowPlayingPlaybackState.paused'),
          reason: 'szünetnél nem megy ki a „szünetel” állapot');
      expect(bar, contains('NowPlayingPlaybackState.stopped'),
          reason: 'leállításnál nem megy ki a „leállt” állapot');
      // A tényleges leállítás törli a felületet (a `stop()` maga küld `clear`-t).
      expect(bar, contains('_stopMetadataRefresh(clear: true)'));
      // …a szünet viszont NEM törli (különben eltűnne a „Folytatás” gomb).
      expect(bar, contains('_stopMetadataRefresh({bool clear = false})'));
      // ⚠️ A szívverés (2026-10-04): a hang tényleges indulására ÉS 5
      // másodpercenként ismét — enélkül az iOS visszaállítja a play gombot.
      expect(bar, contains('radioAudioPlayingState.addListener(_onRadioAudioStateChanged)'));
      expect(bar, contains('Timer.periodic(const Duration(seconds: 5)'));
      expect(bar, contains('startRadioNowPlayingSync()'));
    });

    test('a lejátszó a VALÓDI hangállapotot is jelzi (nem csak a szándékot)', () {
      final playback =
          File('lib/services/radio_playback.dart').readAsStringSync().replaceAll('\r\n', '\n');
      expect(playback, contains('final ValueNotifier<bool> radioAudioPlayingState'));
      expect(playback, contains('_player.playerStateStream.listen'));
      expect(playback, contains('ProcessingState.ready'),
          reason: 'a pufferelés nem számít „szólásnak”');
    });

    test('a Swift-oldal az enum huzal-neveit olvassa', () {
      final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      for (final name in NowPlayingPlaybackState.values) {
        expect(swift, contains('"${name.wireName}"'),
            reason: 'a(z) ${name.wireName} állapot neve nem egyezik a Dart-oldallal');
      }
    });
  });
}
