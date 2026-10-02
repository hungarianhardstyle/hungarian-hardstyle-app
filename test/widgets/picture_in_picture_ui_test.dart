import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/picture_in_picture.dart';

/// A **kis képernyő (PiP) felületi viselkedése** — a tulajdonos jelzései
/// (2026-10-02, képpel a telefonról):
///
/// *„ez a kis ablak a PIP is elég FOSCSI, a rádió gomb dominál”*,
/// *„a pip gomb se megy amúgy a twitch oldalon, az egész egy katyvasz”*.
///
/// A mért gyökér: a PiP-ablak az **egész felületet** mutatta (chat, támogatás
/// gomb, rádiósáv), és a gomb kudarcát a felület **nem mondta meg**. Ez a kör a
/// kirajzolást és a natív jelet méri.
void main() {
  tearDown(() => pictureInPicture.active.value = false);

  group('a keret elrejtése PiP-ben', () {
    testWidgets('a rádiósáv (és minden, ami a burokban van) eltűnik PiP-ben', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('tartalom'),
            bottomNavigationBar: HiddenInPictureInPicture(child: Text('rádiósáv')),
          ),
        ),
      );
      expect(find.text('rádiósáv'), findsOneWidget);

      pictureInPicture.active.value = true;
      await tester.pumpAndSettle();
      expect(find.text('rádiósáv'), findsNothing,
          reason: 'PiP-ben a rádiósáv nem dominálhat (ez volt a panasz)');
      expect(find.text('tartalom'), findsOneWidget,
          reason: 'a tartalom (a videó) marad');

      pictureInPicture.active.value = false;
      await tester.pumpAndSettle();
      expect(find.text('rádiósáv'), findsOneWidget,
          reason: 'kilépés után minden visszatér');
    });
  });

  group('a natív állapot bekötése', () {
    test('a szolgáltatás figyeli a natív „changed" jelzést', () {
      final source = File('lib/services/picture_in_picture.dart').readAsStringSync();
      expect(source.contains('final ValueNotifier<bool> active'), isTrue);
      expect(source.contains("case 'changed':"), isTrue);
      expect(source.contains('active.value = call.arguments == true'), isTrue);
      expect(source.contains('void bind()'), isTrue);
    });

    test('az app indulásakor bekötjük (különben nem lenne állapot)', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main.contains('pictureInPicture.bind();'), isTrue);
    });

    test('FORRÁS-LINT: a Twitch-oldal PiP-ben CSAK a videót rajzolja', () {
      final screen = File('lib/screens/twitch/twitch_screen.dart').readAsStringSync();
      expect(screen.contains('pictureInPicture.active'), isTrue,
          reason: 'a képernyő nem figyeli a PiP-állapotot');
      final pipBranch = RegExp(
        r'if \(inPictureInPicture\) \{([\s\S]*?)\n        \}',
      ).firstMatch(screen)?.group(1);
      expect(pipBranch, isNotNull, reason: 'nincs külön PiP-ág');
      expect(pipBranch, contains('AspectRatio(aspectRatio: 16 / 9'),
          reason: 'PiP-ben a videó 16:9-ben legyen');
      expect(pipBranch, isNot(contains('TwitchStreamChat')),
          reason: 'PiP-ben nem lehet chat');
      expect(pipBranch, isNot(contains('_infoColumn')),
          reason: 'PiP-ben nem lehet támogatás gomb / adatsáv');
      expect(pipBranch, isNot(contains('AppBar')),
          reason: 'PiP-ben nem lehet fejléc');
    });

    test('FORRÁS-LINT: a burok (rádiósáv, menü) el van rejtve PiP-ben', () {
      final shell = File('lib/screens/main_navigation.dart').readAsStringSync();
      // ⚠️ MÉRT SAJÁT HIBA (a mutációs bizonyíték fogta el): az első minta
      // („szerepel-e a fájlban a `HiddenInPictureInPicture(` és a
      // `child: RadioPlayerBar()`”) **gyenge** volt — a burok elvétele után is
      // mindkettő bent maradt (a `child:` a `SafeArea`-ban). Mostantól a pontos
      // szerkezetet mérjük: az alsó sáv **egy** burokban van, és a bal oldali
      // sáv is külön burokban.
      expect(shell.contains('bottomNavigationBar: HiddenInPictureInPicture('), isTrue,
          reason: 'az alsó sáv (rádió + menü) nincs PiP-burokban');
      expect(
        shell.contains('HiddenInPictureInPicture(child: _landscapeNavigationRail())'),
        isTrue,
        reason: 'a fekvő bal oldali sáv nincs PiP-burokban',
      );
      final wrapped = RegExp(r'bottomNavigationBar: HiddenInPictureInPicture\(([\s\S]*?)\n            \),')
          .firstMatch(shell)
          ?.group(1);
      expect(wrapped, isNotNull);
      expect(wrapped, contains('RadioPlayerBar()'),
          reason: 'a rádiósáv az elrejtett burkon belül van');
    });

    test('FORRÁS-LINT: a natív oldal jelzi az állapotot, és megengedi az auto-belépést', () {
      final activity = File(
        'android/app/src/main/kotlin/hu/hungarianhardstyle/app/MainActivity.kt',
      ).readAsStringSync();
      // A `changed` üzenet a PiP-állapotváltáskor megy ki.
      final changedBody = RegExp(
        r'override fun onPictureInPictureModeChanged\(([\s\S]*?)\n    \}',
      ).firstMatch(activity)?.group(1);
      expect(changedBody, isNotNull, reason: 'nincs PiP-állapotfigyelő');
      expect(changedBody, contains('pictureInPictureActive = isInPictureInPictureMode'));
      expect(changedBody, contains('invokeMethod("changed"'));
      // Android 12+: a rendszer magától belép, amikor a felhasználó elhagyja az appot.
      final paramsBody = RegExp(
        r'private fun pictureInPictureParams\(\): PictureInPictureParams \{([\s\S]*?)\n    \}',
      ).firstMatch(activity)?.group(1);
      expect(paramsBody, isNotNull, reason: 'nincs PiP-paraméter-építő');
      expect(paramsBody, contains('setAspectRatio(Rational(16, 9))'));
      expect(paramsBody, contains('setAutoEnterEnabled(pictureInPictureEnabled)'));
      expect(paramsBody, contains('Build.VERSION_CODES.S'));
      expect(activity.contains('"state" -> result.success(pictureInPictureActive)'), isTrue,
          reason: 'a felület induláskor nem tudja megkérdezni az állapotot');
    });
  });
}
