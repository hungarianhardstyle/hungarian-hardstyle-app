import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Az **optimista felület** bizonyítása két lassú műveletre.
///
/// A tulajdonos panasza (szó szerint): *„Ismerősnek jelölés, chat like,
/// 600 év volt mire sikerült, nagyon LASSSÚ, nem úgy kéne, hogy az appban már
/// végrehajtódik, de közben megy ki a kérés a szerver felé?"*
///
/// A mért gyökér: mindkét művelet **előbb** megvárta a Firebase callable-t
/// (Cloud Function hideg indulás + WordPress kör = 1–3 s), és csak utána nyúlt
/// a helyi állapothoz. A jó minta a repóban már megvan: a privát üzenet szíve
/// (`lib/screens/community/private_messages_screen.dart` `_toggleHeart`) —
/// helyi felülírás + `setState` a `await` ELŐTT, hiba esetén visszaállás +
/// SnackBar, a darabszám pedig **deltával** követi a képet.
///
/// Amit itt mérünk (forrás-lint, Firebase és eszköz nélkül):
///  1. a helyi állapot írása a `await` **előtt** van (különben nincs optimista
///     felület, csak egy lassú gomb);
///  2. a hiba **visszaállít** ÉS **látszik** (nem néma `catch (_) {}`);
///  3. van busy-kapu, ezért egy dupla koppintás nem indít két callable-t;
///  4. a szolgáltatás-hívás változatlan (nem tűnt el, nem lett más a neve);
///  5. a saját reakció jelzése (`Icons.check_circle` + „Te reagáltál erre")
///     megmaradt, és a darabszám a deltából számol.
void main() {
  final communityScreen = File(
    'lib/screens/community/community_screen.dart',
  ).readAsStringSync();
  final usersScreen = File(
    'lib/screens/more/community_users_screen.dart',
  ).readAsStringSync();

  group('chat reakció (community_screen.dart)', () {
    test('a helyi állapot a szolgáltatás-hívás ELŐTT íródik', () {
      final body = _functionBody(communityScreen, '_react');
      expect(
        body.indexOf('setState'),
        isNonNegative,
        reason: 'a törzsben nincs helyi állapotírás',
      );
      expect(
        body.indexOf('setState') < body.indexOf('await'),
        isTrue,
        reason:
            'az optimista setState-nek az `await` ELŐTT kell lennie, '
            'különben a felület a callable-re vár (ez volt a panasz)',
      );
    });

    test('a szolgáltatás-hívás változatlan', () {
      final body = _functionBody(communityScreen, '_react');
      expect(body, contains('toggleReaction'));
      expect(body, contains('postId: widget.post.id'));
    });

    test('van busy-kapu a dupla koppintás ellen', () {
      final body = _functionBody(communityScreen, '_react');
      expect(body, contains('if (_reactionBusy) return;'));
      expect(body, contains('_reactionBusy = true'));
    });

    test('hibánál visszaáll ÉS szól (nem néma catch)', () {
      final body = _functionBody(communityScreen, '_react');
      expect(body, contains('catch (error)'));
      expect(
        body,
        isNot(contains('catch (_)')),
        reason: 'a néma catch pont a panasz egyik oka volt',
      );
      expect(body, contains('_optimisticActive = previousActive'));
      expect(body, contains('_optimisticReaction = previousReaction'));
      expect(
        body,
        contains('_chatError(error)'),
        reason: 'a hibaüzenet a fájl megszokott hibasegédjével megy ki',
      );
      expect(body, contains('SnackBar'));
    });

    test('a darabszám lokális deltával mozdul, és a kép beérésénél eltűnik', () {
      final delta = _functionBody(communityScreen, '_reactionDelta');
      expect(delta, contains('before == emoji'));
      expect(delta, contains('delta -= 1'));
      expect(delta, contains('delta += 1'));
      expect(
        delta,
        contains('if (before == after) return 0;'),
        reason: 'ha beért a kép, a delta nem korrigál semmit',
      );
      expect(
        communityScreen,
        contains('_reactionDelta(emoji)'),
        reason: 'a chip a szerver-képet a deltával korrigálja',
      );
      expect(communityScreen, contains('post.reactions[emoji] ?? 0'));
      final didUpdate = _functionBody(communityScreen, 'didUpdateWidget');
      expect(
        didUpdate,
        contains('_optimisticActive = false'),
        reason: 'a beérkező Firestore-kép az úr, az optimista érték elenged',
      );
    });

    test('a saját reakció jelzése megmaradt (név nélkül)', () {
      expect(communityScreen, contains('Icons.check_circle'));
      expect(communityScreen, contains('Te reagáltál erre'));
    });
  });

  group('ismerősnek jelölés (community_users_screen.dart)', () {
    test('_requestConnection: optimista pending + busy + rollback', () {
      final body = _functionBody(usersScreen, '_requestConnection');
      expect(
        body.indexOf('setState') < body.indexOf('await'),
        isTrue,
        reason: 'a „pending" állapot a callable ELŐTT jelenik meg',
      );
      expect(body, contains('requestConnection'));
      expect(body, contains("Future.value('pending')"));
      expect(body, contains('if (_connectionBusy) return;'));
      expect(body, contains('catch (error)'));
      expect(body, isNot(contains('catch (_)')));
      expect(body, contains('_connectionStatus = previousStatus'));
      expect(body, contains('Az ismerősnek jelölés nem sikerült.'));
      expect(body, contains('SnackBar'));
    });

    test('_respondConnection: elfogadás/elutasítás optimistán + rollback', () {
      final body = _functionBody(usersScreen, '_respondConnection');
      expect(
        body.indexOf('setState') < body.indexOf('await'),
        isTrue,
        reason: 'a döntés azonnal látszik, nem a callable után',
      );
      expect(body, contains('respondConnection'));
      expect(body, contains('if (_connectionBusy) return;'));
      expect(body, contains('catch (error)'));
      expect(body, isNot(contains('catch (_)')));
      expect(body, contains('_connectionStatus = previousStatus'));
      expect(body, contains('SnackBar'));
    });

    test('a felkérés-csempe (_ConnectionRequestTile) is optimista', () {
      final body = _functionBody(usersScreen, '_respond');
      expect(
        body.indexOf('setState') < body.indexOf('await'),
        isTrue,
        reason: 'a csempe a koppintásra azonnal vált',
      );
      expect(
        body,
        contains('await widget.service.respondConnection('),
        reason: 'korábban nem vártuk meg a hívást (kezeletlen hiba)',
      );
      expect(body, contains('if (_busy) return;'));
      expect(body, contains('catch (error)'));
      expect(body, isNot(contains('catch (_)')));
      expect(body, contains('_handled = previousHandled'));
      expect(body, contains('SnackBar'));
      expect(usersScreen, contains('_ConnectionRequestTileState'));
    });
  });
}

/// Kiveszi egy Dart-metódus törzsét a nyitó kapcsos zárójel bezárásáig.
///
/// A minta a **definícióra** illeszkedik (sortörés + visszatérési típus + név +
/// `(`), nem a puszta névre: a `_advance(` alak a **hívási helyet** is eltalálná
/// (`unawaited(_advance())`), és akkor rossz kapcsos zárójelet párosítana.
String _functionBody(String source, String name) {
  final match = RegExp(
    '\\n\\s*[A-Za-z_][\\w<>, ?]*\\s${RegExp.escape(name)}\\(',
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'nincs ilyen tag: $name');
  final open = source.indexOf('{', match!.start);
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
