import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A háttér-lejátszó **ismétlődő hibájának** bizonyítéka és a javítás őre.
///
/// A tulajdonos telefonján ez jelent meg a „Megvásárolt zenéim" képernyőn:
///
/// > You cannot add items while items are being added from addStream
///
/// és a zene **el sem indult**. A gyökér (mérve, a csomagok forrásában):
///
///  * `BaseAudioHandler.playbackState` egy **rxdart `BehaviorSubject`**
///    (`audio_service-0.18.19/lib/audio_service.dart:2982`);
///  * a `Stream.pipe(consumer)` a `consumer.addStream(...)`-et hívja, az rxdart
///    `Subject.addStream` pedig **egyszer s mindenkorra** beállítja az
///    `_isAddingStreamItems` jelzőt, és **csak akkor engedi el, ha a forrás
///    lezárul** (`rxdart-0.28.0/lib/src/subjects/subject.dart:104-132`);
///  * a lejátszó eseménystreamje **soha nem zárul le**, ezért a jelző örökre
///    bekapcsolva marad, és **minden további `playbackState.add(...)` dob**
///    (`subject.dart:135-142`).
///
/// Ezért a `MusicAudioHandler`-ben a `.pipe(playbackState)` **tilos**; helyette
/// kézi `listen(...)` kell, ami `add()`-dal írja ki az eseményeket.
void main() {
  /// A termelő stream, ami **soha nem zárul le** — pontosan mint a lejátszó
  /// `playbackEventStream`-je.
  Stream<PlaybackState> endlessStates() =>
      Stream<PlaybackState>.periodic(
        const Duration(milliseconds: 5),
        (_) => PlaybackState(),
      );

  test('a .pipe(playbackState) UTÁN az add() dob (ez volt az éles hiba)', () {
    final handler = _ProbeHandler();
    // A hibás minta: a pipe addStream-et indít, ami sosem fejeződik be.
    unawaited(endlessStates().pipe(handler.playbackState));

    expect(
      () => handler.playbackState.add(PlaybackState()),
      throwsA(
        isA<StateError>().having(
          (error) => error.message.toString(),
          'üzenet',
          contains('You cannot add items while items are being added'),
        ),
      ),
      reason: 'ez az üzenet jelent meg a tulajdonos képernyőjén',
    );
  });

  test('a kézi listen(...) + add() minta MŰKÖDIK (ez a javítás)', () {
    final handler = _ProbeHandler();
    // A javított minta: nincs addStream, ezért az add() szabad.
    final subscription = endlessStates().listen(handler.playbackState.add);
    addTearDown(subscription.cancel);

    expect(
      () => handler.playbackState.add(
        handler.playbackState.value.copyWith(queueIndex: 3),
      ),
      returnsNormally,
    );
    expect(handler.playbackState.value.queueIndex, 3);
  });

  test('a queue és a mediaItem is szabadon írható (nincs addStream rajtuk)', () {
    final handler = _ProbeHandler();
    final subscription = endlessStates().listen(handler.playbackState.add);
    addTearDown(subscription.cancel);

    expect(
      () => handler.queue.add(const [MediaItem(id: 'a', title: 'A')]),
      returnsNormally,
    );
    expect(handler.queue.value.length, 1);
    expect(
      () => handler.mediaItem.add(const MediaItem(id: 'a', title: 'A')),
      returnsNormally,
    );
    expect(handler.mediaItem.value?.id, 'a');
  });

  // --- FORRÁS-LINT: a valódi kód ne térjen vissza a hibás mintához ----------
  group('forrás-lint: a lejátszó bekötése', () {
    late String handler;
    late String screen;

    setUpAll(() {
      // ⚠️ A **kommenteket kivesszük**: a hibás minta a fájl fejlécében,
      // dokumentációként szerepel („NEM `.pipe(...)`"), és a nyers szövegre
      // illesztő lint ettől hamisan elhasalt volna.
      handler = _withoutComments(
        File('lib/services/music_audio_handler.dart').readAsStringSync(),
      );
      screen = _withoutComments(
        File('lib/screens/more/my_music_screen.dart').readAsStringSync(),
      );
    });

    test('a szolgáltatás NEM használ pipe-ot (ez volt az éles hiba)', () {
      expect(
        handler,
        isNot(contains('.pipe(playbackState)')),
        reason:
            'a pipe addStream-et indít, ami véglegesen letiltja az add()-ot — '
            'élesben ez némította el a lejátszót',
      );
      expect(handler, contains('listen(playbackState.add'));
      expect(
        handler,
        contains('_stateSubscription?.cancel()'),
        reason: 'a feliratkozást el kell engedni a lejátszó lezárásakor',
      );
    });

    test('a hangforrás beállítása MEGELŐZI a lejátszást (és a közzététel hibát nyelve fut)', () {
      // A sorrend szabálya megmaradt, csak a helye változott: a hangforrást a
      // **sor** állítja be (`MusicQueuePlayer.playAt`), a közzététel pedig a
      // szolgáltatásban történik — mindkettő saját hibakezeléssel, hogy a
      // megjelenítés hibája **soha** ne némítsa el a lejátszást.
      final player = _withoutComments(
        File('lib/services/music_queue_player.dart').readAsStringSync(),
      );
      final body = _functionBody(player, 'playAt');
      final sourceIndex = body.indexOf('setAudioSource(');
      final playIndex = body.indexOf('player.play()');
      expect(sourceIndex, isNonNegative);
      expect(playIndex, isNonNegative);
      expect(
        sourceIndex < playIndex,
        isTrue,
        reason: 'előbb a hangforrás, csak azután indul a lejátszás',
      );
    });

    test('a metaadat-közzététel saját hibakezelésben van', () {
      // A **sor** oldalán…
      final player = _withoutComments(
        File('lib/services/music_queue_player.dart').readAsStringSync(),
      );
      final publish = _functionBody(player, '_publishPlan');
      expect(publish, contains('catch'));
      expect(publish, contains('debugPrint'));
      // …és a **szolgáltatás** oldalán is (az értesítés/zárképernyő).
      final servicePublish = _functionBody(handler, '_publishSession');
      expect(servicePublish, contains('catch'));
      expect(servicePublish, contains('debugPrint'));
    });

    test('sikertelen indításnál a kijelölés visszaáll és magyar üzenet jön', () {
      // ⚠️ A hibaág a **sorban** van (a képernyő elhagyása után is le kell
      // állnia, és vissza kell adnia a hangot a rádiónak).
      final player = _withoutComments(
        File('lib/services/music_queue_player.dart').readAsStringSync(),
      );
      final body = _functionBody(player, 'playAt');
      expect(body, contains('previousKey'));
      expect(
        body,
        contains('_plan.moveToKey(previousKey)'),
        reason: 'ne maradjon „ez szól" állapotban egy néma lejátszó',
      );
      expect(body, contains('playbackErrorMessage(error)'));
      expect(
        body,
        isNot(contains('userFacingError(error)')),
        reason: 'a lejátszó hibájára magyar, célzott üzenet kell',
      );
    });

    test('a sorrend keverés nélkül MINDIG a valósághoz igazodik', () {
      // A pásztázás **mindig** átadja az alap-sorrendet (nincs feltételes ág,
      // amiben egy félkész sorrend beragadhat — élesben „1/1 · 15 letöltve"
      // látszott). A keverés stabilitását a sor oldja meg: változatlan alapnál
      // nem kever újra.
      final body = _functionBody(screen, '_scanDownloads');
      expect(
        body,
        contains('_pushBaseOrder(paths)'),
        reason: 'minden pásztázás átadja a szolgáltatásnak a valós sorrendet',
      );
      final player = _withoutComments(
        File('lib/services/music_queue_player.dart').readAsStringSync(),
      );
      expect(
        _functionBody(player, 'setBaseOrder'),
        contains('_shuffle && unchanged'),
        reason: 'keverésnél csak változáskor kever újra (nem ugrál a következő)',
      );
    });
  });
}

/// Kiveszi a **soros kommenteket** a forrásból.
///
/// MIÉRT: a forrás-lint a kódra kérdez, nem a dokumentációra — a fájl fejlécében
/// szándékosan szerepel a hibás minta („NEM `.pipe(...)`"), és a nyers
/// szövegkeresés ettől hamisan piros lenne.
String _withoutComments(String source) => source
    .split('\n')
    .where((line) {
      final trimmed = line.trimLeft();
      return !trimmed.startsWith('//');
    })
    .join('\n');

/// Kiveszi egy Dart-metódus törzsét a nyitó kapcsos zárójel bezárásáig.
///
/// A paraméterlistát átugorja, és a kulcsszavakat kizárja a visszatérési típus
/// helyéről (különben a hívási helyet is eltalálná).
String _functionBody(String source, String name) {
  final match = RegExp(
    '\\n\\s*(?!await\\b|unawaited\\b|return\\b|if\\b|while\\b|for\\b|switch\\b|assert\\b)'
    '[A-Za-z_][\\w<>, ?]*\\s${RegExp.escape(name)}\\(',
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'nincs ilyen tag: $name');
  final openParen = source.indexOf('(', match!.start);
  expect(
    openParen,
    isNonNegative,
    reason: '$name paraméterlistája nem található',
  );
  var parens = 0;
  var afterParams = -1;
  for (var i = openParen; i < source.length; i++) {
    final char = source[i];
    if (char == '(') parens++;
    if (char == ')') {
      parens--;
      if (parens == 0) {
        afterParams = i;
        break;
      }
    }
  }
  expect(
    afterParams,
    isNonNegative,
    reason: '$name paraméterlistája nem záródik le',
  );
  final open = source.indexOf('{', afterParams);
  expect(open, isNonNegative, reason: '$name törzse nem található');
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  fail('$name törzse nem záródik le');
}

/// Üres próba-szolgáltatás: a `BaseAudioHandler` minden metódusára van
/// alapértelmezés, ezért elég belőle származni (a platform-csatornát nem érinti).
class _ProbeHandler extends BaseAudioHandler {}
