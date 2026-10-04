import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/now_playing.dart';
import 'package:hungarian_hardstyle_app/services/radio_playback.dart';
import 'package:hungarian_hardstyle_app/widgets/radio_player_bar.dart';

/// A **zárképernyő állapot-szinkronja** — valódi viselkedéssel mérve.
///
/// A tulajdonos jelzése (2026-10-04): *„play van meg stop és ha rányomok a
/// playre, egy pillre pause lesz belőle aztán visszaáll … és szól a rádió”*.
///
/// A mért gyökér: az állapot **egyszer** ment ki (a kattintás pillanatában), a
/// hang viszont csak a stream betöltése után indul — az iOS pedig közben
/// visszaállította a play gombot, a `playbackRate` pedig beleragadt a 0-ba.
///
/// Ez a kör négy dolgot mér:
///  1. minden állapotváltás azonnal kimegy,
///  2. a hang **tényleges** indulása (a betöltés után) is kivált egy kiírást,
///  3. 5 másodpercenként ismétlődik (szívverés),
///  4. leállítás után **nem** ismétlődik tovább (és nem marad időzítő).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> appleCalls;

  setUp(() {
    appleCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NowPlayingReporter.appleChannel, (call) async {
      appleCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NowPlayingReporter.appleChannel, null);
    radioAudioPlayingState.value = false;
    radioPlayingState.value = false;
  });

  List<String> states() => [
        for (final call in appleCalls)
          if (call.method == 'state') (call.arguments as Map)['state'] as String,
      ];

  testWidgets('a hang indulása és a szívverés is kiírja a „szól” állapotot', (tester) async {
    startRadioNowPlayingSync();
    radioPlayingState.value = true;

    // 1) Az állapotváltás azonnal kimegy.
    await reportRadioNowPlayingState(NowPlayingPlaybackState.playing);
    expect(states(), ['playing']);

    // 2) A hang TÉNYLEGES indulása (a stream betöltése után) újabb kiírás.
    radioAudioPlayingState.value = true;
    await tester.pump();
    expect(states().length, 2,
        reason: 'a hang indulása nem váltott ki állapot-kiírást');

    // 3) Szívverés: 5 másodpercenként ismétlődik (az iOS visszaállítja a gombot).
    await tester.pump(const Duration(seconds: 5));
    expect(states().length, 3, reason: 'nincs 5 másodperces szívverés');
    await tester.pump(const Duration(seconds: 10));
    expect(states().length, 5);
    expect(states().last, 'playing');

    // 4) Leállítás után a szívverés megáll (és nem marad időzítő).
    await reportRadioNowPlayingState(NowPlayingPlaybackState.stopped);
    expect(states().last, 'stopped');
    final afterStop = states().length;
    await tester.pump(const Duration(seconds: 30));
    expect(states().length, afterStop,
        reason: 'leállított rádióhoz nem szabad tovább ismételni');
  });

  testWidgets('szüneteltetéskor a „szünetel” állapot megy ki (és a szívverés ismétli)',
      (tester) async {
    startRadioNowPlayingSync();
    radioPlayingState.value = false;
    await reportRadioNowPlayingState(NowPlayingPlaybackState.paused);
    expect(states(), ['paused']);

    await tester.pump(const Duration(seconds: 5));
    expect(states(), ['paused', 'paused'],
        reason: 'szüneteltetett rádiónál is kell a szívverés (a gomb visszaválthat)');

    // A kör végén leállítjuk, hogy ne maradjon időzítő.
    await reportRadioNowPlayingState(NowPlayingPlaybackState.stopped);
  });

  testWidgets('újracsatlakozás közben NEM vált play gombra (a szándék „szól”)', (tester) async {
    // ⚠️ Szándékos viselkedés: a hang átmeneti elhallgatása (pufferelés,
    // újracsatlakozás, fókusz-vesztés) nem jelenti azt, hogy a felhasználó
    // megállította a rádiót — ezért ilyenkor is „szól” állapot megy ki, különben
    // a zárképernyő play gombra váltana egy folyamatosan szóló rádió mellett.
    startRadioNowPlayingSync();
    radioPlayingState.value = true;
    await reportRadioNowPlayingState(NowPlayingPlaybackState.playing);
    radioAudioPlayingState.value = true;
    await tester.pump();
    radioAudioPlayingState.value = false;
    await tester.pump();
    expect(states().last, 'playing',
        reason: 'a pufferelés nem válthatja play gombra a zárképernyőt');

    // …ha viszont a felhasználó szüneteltet (a szándék is elmegy), az állapot vált.
    radioPlayingState.value = false;
    await reportRadioNowPlayingState(NowPlayingPlaybackState.paused);
    radioAudioPlayingState.value = true;
    await tester.pump();
    expect(states().last, 'paused');

    await reportRadioNowPlayingState(NowPlayingPlaybackState.stopped);
  });
}
