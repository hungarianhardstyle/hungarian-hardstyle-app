import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/now_playing.dart';
import 'package:hungarian_hardstyle_app/services/radio_remote.dart';

/// A **zárképernyő / fejhallgató / értesítés távvezérlője**.
///
/// A tulajdonos jelzése (2026-10-03): *„kéne egy pause gomb is az értesítési és a
/// zártképernyős rádió vezérlőre”* — és a mérés szerint az iOS-oldalon eddig
/// **senki** nem hallgatta a rendszer parancsait (a `just_audio` 0.10.6 `darwin`
/// forrásaiban nincs `MPRemoteCommandCenter`, az `AppDelegate.swift` pedig csak a
/// „Most szól” panel tartalmát írta).
///
/// Ez a kör három szinten méri ugyanazt:
///  1. **tiszta** értelmezés (`parseRadioRemoteCommand`) — minden parancsnévre;
///  2. **végrehajtás** injektált hívásokkal (`runRadioRemoteCommand`), a
///     `toggle` ág a pillanatnyi állapotból dönt;
///  3. a **valódi bekötés**: egy platformtól érkező üzenetet adunk át a
///     `hu_hs/now_playing` csatornán, és azt mérjük, hogy a kezelő lefut-e.
void main() {
  // ⚠️ A csatorna kezelőjének a bekötéséhez (és a bejövő üzenet átadásához) kell
  // a kötés — a `test()` önmagában nem inicializálja.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a parancs értelmezése (tiszta)', () {
    test('a négy valódi gomb', () {
      expect(parseRadioRemoteCommand('play'), RadioRemoteCommand.play);
      expect(parseRadioRemoteCommand('pause'), RadioRemoteCommand.pause);
      expect(parseRadioRemoteCommand('stop'), RadioRemoteCommand.stop);
      expect(parseRadioRemoteCommand('toggle'), RadioRemoteCommand.toggle);
    });

    test('kis/nagybetű és szóköz nem számít (a platform így is küldheti)', () {
      expect(parseRadioRemoteCommand('PAUSE'), RadioRemoteCommand.pause);
      expect(parseRadioRemoteCommand(' Play '), RadioRemoteCommand.play);
      expect(parseRadioRemoteCommand('togglePlayPause'), RadioRemoteCommand.toggle);
    });

    test('ismeretlen vagy nem szöveges parancs: nem tippelünk', () {
      expect(parseRadioRemoteCommand(null), RadioRemoteCommand.unknown);
      expect(parseRadioRemoteCommand(42), RadioRemoteCommand.unknown);
      expect(parseRadioRemoteCommand(''), RadioRemoteCommand.unknown);
      expect(parseRadioRemoteCommand('rewind'), RadioRemoteCommand.unknown);
    });
  });

  group('a parancs végrehajtása', () {
    late List<String> calls;
    late bool playing;

    Future<void> run(RadioRemoteCommand command) => runRadioRemoteCommand(
          command,
          play: () async => calls.add('play'),
          pause: () async => calls.add('pause'),
          stop: () async => calls.add('stop'),
          isPlaying: () async => playing,
        );

    setUp(() {
      calls = [];
      playing = true;
    });

    test('a szünet NEM állítja le a rádiót (a vezérlő megmarad)', () async {
      await run(RadioRemoteCommand.pause);
      expect(calls, ['pause']);
    });

    test('a lejátszás és a leállítás a saját útjára megy', () async {
      await run(RadioRemoteCommand.play);
      await run(RadioRemoteCommand.stop);
      expect(calls, ['play', 'stop']);
    });

    test('a váltó gomb szólás közben szüneteltet', () async {
      playing = true;
      await run(RadioRemoteCommand.toggle);
      expect(calls, ['pause']);
    });

    test('a váltó gomb álló rádiót elindít', () async {
      playing = false;
      await run(RadioRemoteCommand.toggle);
      expect(calls, ['play']);
    });

    test('ismeretlen parancsra SEMMI nem történik', () async {
      await run(RadioRemoteCommand.unknown);
      expect(calls, isEmpty);
    });
  });

  group('a bekötés (valódi csatorna, bejövő üzenet)', () {
    late List<String> calls;
    late bool playing;

    void bind() => bindRadioRemoteChannel(
          NowPlayingReporter.appleChannel,
          play: () async => calls.add('play'),
          pause: () async => calls.add('pause'),
          stop: () async => calls.add('stop'),
          isPlaying: () async => playing,
        );

    /// Egy **platformtól érkező** üzenet átadása ugyanúgy, ahogy az iOS teszi.
    Future<void> deliver(Object? arguments, {String method = radioRemoteMethodName}) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        NowPlayingReporter.appleChannel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
    }

    setUp(() {
      calls = [];
      playing = true;
      bind();
    });

    tearDown(() {
      NowPlayingReporter.appleChannel.setMethodCallHandler(null);
    });

    test('a „pause” parancs a szünetet hívja (ez volt a hiányzó gomb)', () async {
      await deliver('pause');
      expect(calls, ['pause']);
    });

    test('a „toggle” a pillanatnyi állapotból dönt', () async {
      await deliver('toggle');
      playing = false;
      await deliver('toggle');
      expect(calls, ['pause', 'play']);
    });

    test('más metódusnév nem indít rádió-műveletet (a csatorna kétirányú)', () async {
      await deliver('pause', method: 'metadata');
      expect(calls, isEmpty);
    });

    test('szemét argumentum nem dob és nem indít semmit', () async {
      await deliver(42);
      await deliver(null);
      expect(calls, isEmpty);
    });
  });

  group('FORRÁS-LINT: a platform és a felület ugyanezt használja', () {
    String read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

    test('az iOS beköti a négy rendszerparancsot és átadja a Dart-oldalnak', () {
      final swift = read('ios/Runner/AppDelegate.swift');
      expect(swift, contains('MPRemoteCommandCenter.shared()'),
          reason: 'kezelő nélkül a zárképernyő gombja hatástalan');
      for (final command in const [
        'center.playCommand',
        'center.pauseCommand',
        'center.togglePlayPauseCommand',
        'center.stopCommand',
      ]) {
        expect(swift, contains(command), reason: '$command hiányzik');
      }
      expect(swift, contains('invokeMethod("remoteCommand"'),
          reason: 'a parancs így érkezik meg a Dart-oldalra');
      expect(swift, contains('MPNowPlayingInfoPropertyPlaybackRate'),
          reason: 'a zárképernyő gombja ebből rajzolja az állapotot');
      expect(swift, contains('bindRemoteCommands()'),
          reason: 'a bekötés a csatorna létrehozásakor fut');
    });

    test('a Dart-oldal a valódi rádió-életciklushoz köti a parancsokat', () {
      final bar = read('lib/widgets/radio_player_bar.dart');
      expect(bar, contains('bindRadioRemoteChannel('));
      expect(bar, contains('play: resumeRadioPlayback'));
      expect(bar, contains('pause: pauseRadioPlayback'));
      expect(bar, contains('stop: stopRadioPlayback'));
      expect(bar, contains('isPlaying: isRadioPlaybackActive'),
          reason: 'a váltó gomb a valódi állapotból döntsön');
      // A szünet NEM törli a rendszer felületét (különben eltűnne a vezérlő).
      final pause = bar.substring(
        bar.indexOf('Future<void> pauseRadioPlayback()'),
        bar.indexOf('/// A **távvezérlő**'),
      );
      expect(pause, contains('radioPlayback.pause()'));
      expect(pause.contains('nowPlayingReporter.stop()'), isFalse,
          reason: 'a szünetnek meg kell tartania az értesítést és a zárképernyőt');
    });

    test('az indulás beköti a távvezérlőt (enélkül néma maradna)', () {
      final main = read('lib/main.dart');
      expect(main, contains('bindRadioRemoteCommands();'));
    });

    test('az Android-oldal is kapott szünet-utat (nem csak az iOS)', () {
      final service = read('lib/services/radio_playback.dart');
      expect(service, contains("invokeMethod<void>('pause')"),
          reason: 'az Android natív szolgáltatása ezt a nevet várja');
    });
  });
}
