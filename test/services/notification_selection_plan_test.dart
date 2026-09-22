import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/app_notification.dart';
import 'package:hungarian_hardstyle_app/services/notification_selection_plan.dart';

/// Az értesítések **kijelöléssel történő törlésének** bizonyítása.
///
/// A tulajdonos kérése (2026-09-22): *„Notifyt esetleg lehessen kijelölni is
/// törléshez, hogy azt törölhessem amit akarok és még se egyszerre az egészet
/// vagy egyenként lenne úgy."*
void main() {
  AppNotification notification(String id, {String uid = 'me'}) =>
      AppNotification(
        id: id,
        type: 'general',
        title: 'Cím',
        body: 'Szöveg',
        targetType: 'achievement',
        targetId: 'me',
        createdAt: DateTime(2026, 9, 22),
        readAt: null,
        archivedAt: null,
        recipientUid: uid,
      );

  group('kijelölés', () {
    test('a koppintás kijelöl, majd levesz', () {
      var selected = <String>{};
      selected = toggleNotificationSelection(
        selected,
        'a',
        selectedNow: true,
      );
      expect(selected, {'a'});
      selected = toggleNotificationSelection(
        selected,
        'a',
        selectedNow: false,
      );
      expect(selected, isEmpty);
    });

    test('a bemenetet nem módosítja (új halmazt ad)', () {
      final original = {'a'};
      final next = toggleNotificationSelection(
        original,
        'b',
        selectedNow: true,
      );
      expect(original, {'a'});
      expect(next, {'a', 'b'});
    });

    test('üres azonosítót nem jelöl be', () {
      expect(
        toggleNotificationSelection(<String>{}, '   ', selectedNow: true),
        isEmpty,
      );
    });
  });

  group('mi törölhető', () {
    test('csak a KIJELÖLT és csak a SAJÁT sorok', () {
      // A Firestore-szabály is ezt kéri (`recipientUid == request.auth.uid`),
      // ezért idegen azonosító el sem indul.
      final items = [
        notification('a'),
        notification('b'),
        notification('c', uid: 'valaki-mas'),
      ];
      final ids = deletableNotificationIds(
        items: items,
        selected: {'a', 'b', 'c'},
        uid: 'me',
      );
      expect(ids, ['a', 'b']);
    });

    test('a lista sorrendjét tartja, és nem dupláz', () {
      final items = [notification('a'), notification('b'), notification('a')];
      expect(
        deletableNotificationIds(
          items: items,
          selected: {'b', 'a'},
          uid: 'me',
        ),
        ['a', 'b'],
      );
    });

    test('bejelentkezés nélkül semmi nem törölhető', () {
      final items = [notification('a')];
      expect(
        deletableNotificationIds(
          items: items,
          selected: {'a'},
          uid: null,
        ),
        isEmpty,
      );
      expect(
        deletableNotificationIds(items: items, selected: {'a'}, uid: '  '),
        isEmpty,
      );
    });

    test('ismeretlen jogosult (régi rekord) nem törölhető innen', () {
      final items = [notification('a', uid: '')];
      expect(
        deletableNotificationIds(
          items: items,
          selected: {'a'},
          uid: 'me',
        ),
        isEmpty,
      );
    });

    test('a törölt sorok kikerülnek a kijelölésből', () {
      final items = [notification('a'), notification('c', uid: 'mas')];
      expect(pruneNotificationSelection({'a', 'b'}, items), {'a'});
    });
  });

  group('a szövegek', () {
    test('a fejléc és a visszajelzés magyarul, helyesen', () {
      expect(notificationSelectionLabel(0), 'Jelölj ki értesítéseket');
      expect(notificationSelectionLabel(1), 'Kijelölve: 1');
      expect(notificationSelectionLabel(5), 'Kijelölve: 5');
      expect(notificationDeletedLabel(1), '1 értesítés törölve.');
      expect(notificationDeletedLabel(4), '4 értesítés törölve.');
    });
  });

  group('⚠️ a kijelölés ÁLLAPOTA — több sor is kijelölhető (éles hiba volt)', () {
    // A tulajdonos jelzése (2026-09-22): *„a notify kijelölésnél egyszerre csak
    // egyet lehet kijelölni"*, illetve *„csak egyet vagy az összeset"*. A gyökér
    // a képernyő kaszkádja volt (`_selected..clear()..addAll(...)`): a `clear()`
    // előbb futott, ezért a „most kijelölöm?" kérdés már üres halmazon dőlt el,
    // és az eredmény mindig pontosan egy azonosító lett.
    // Ezek a tesztek közvetlenül az ÁLLAPOTOT mérik, ezért ezt elkapják.
    test('két különböző sor kijelölése MEGMARAD egymás mellett', () {
      final selection = NotificationSelection();
      selection.toggle('a');
      expect(selection.ids, {'a'});
      selection.toggle('b');
      expect(
        selection.ids,
        {'a', 'b'},
        reason: 'a második kijelölés nem törölheti az elsőt',
      );
      expect(selection.count, 2);
      selection.toggle('c');
      expect(selection.count, 3);
    });

    test('ugyanannak a sornak a második koppintása leengedi', () {
      final selection = NotificationSelection()
        ..toggle('a')
        ..toggle('b');
      selection.toggle('a');
      expect(selection.ids, {'b'});
      selection.toggle('b');
      expect(selection.isEmpty, isTrue);
    });

    test('az üres azonosító nem jelölhető be (és nem rontja el a többit)', () {
      final selection = NotificationSelection()..toggle('a');
      selection.toggle('   ');
      expect(selection.ids, {'a'});
    });

    test('összes kijelölése, törlése, és a listából eltűnt sor eldobása', () {
      final selection = NotificationSelection()..toggle('x');
      selection.selectAll(['a', 'b', ' ']);
      expect(selection.ids, {'a', 'b'});
      selection.retainOnly([notification('b')]);
      expect(selection.ids, {'b'});
      selection.clear();
      expect(selection.isEmpty, isTrue);
      expect(selection.count, 0);
    });

    test('a fejléc száma csak a LÁTHATÓ sorokat számolja', () {
      final selection = NotificationSelection()
        ..toggle('a')
        ..toggle('rejtett');
      final visible = [notification('a'), notification('b')];
      expect(selection.count, 2, reason: 'az állapot mindkettőt tudja');
      expect(
        selection.countWithin(visible),
        1,
        reason: 'a fejléc csak azt mutatja, ami a listán is látszik',
      );
    });

    test('a kijelölt azonosítók halmaza kívülről nem módosítható', () {
      final selection = NotificationSelection()..toggle('a');
      expect(() => selection.ids.add('b'), throwsUnsupportedError);
    });
  });

  group('FORRÁS-LINT: a képernyő és a szolgáltatás bekötése', () {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    /// Csak a KÓD: a csupa-komment sorok kimaradnak. A fejléc szándékosan
    /// **idézi** a hibás mintát (`_selected..clear()..addAll(...)`), ezért a lint
    /// nem találhatja meg a magyarázatban — ugyanaz a fogás, mint a lejátszó
    /// `pipe`-tesztjénél.
    String codeOnly(String source) => source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    test('a képernyő a TESZTELT állapotot használja, és nem a kaszkád-csapdát', () {
      final source = read(
        'lib/screens/notifications/notification_center_screen.dart',
      );
      expect(source.contains('bool _selecting = false;'), isTrue);
      expect(source.contains('final NotificationSelection _selection'), isTrue);
      expect(source.contains('_selection.toggle('), isTrue);
      expect(source.contains('_selection.contains('), isTrue);
      expect(source.contains('_selection.countWithin('), isTrue);
      expect(source.contains('_selection.selectAll('), isTrue);
      // ⚠️ A kaszkád-csapda a képernyőn: `..clear()..addAll(...)`. Ez volt az
      // éles hiba (a `clear()` előbb fut, mint az argumentum kiértékelése),
      // ezért a képernyőn nem maradhat ilyen minta.
      expect(
        codeOnly(source).contains('..clear()'),
        isFalse,
        reason: 'a kijelölést az állapot-osztály kezeli, nem a képernyő',
      );
      expect(codeOnly(source).contains('_selected'), isFalse);
      expect(
        source.contains('onTap: _selecting'),
        isTrue,
        reason: 'kijelölés módban a sorra koppintás jelöl, nem nyit meg',
      );
      // A fejléc adja a kijelölést/törlést, és megmondja a darabszámot.
      expect(source.contains('notificationSelectionLabel('), isTrue);
      expect(source.contains('Icons.check_circle_outline'), isTrue);
      expect(source.contains('Icons.delete_outline'), isTrue);
      expect(source.contains('Icons.select_all_rounded'), isTrue);
      // A törlés a TISZTA szabályon megy át, nem nyers azonosítókon.
      expect(source.contains('deletableNotificationIds('), isTrue);
      expect(source.contains('deleteIds(ids)'), isTrue);
    });

    test('a szolgáltatás kötegelt törlése csak a saját fióknak dolgozik', () {
      final source = read('lib/services/notification_service.dart');
      final start = source.indexOf('Future<int> deleteIds(');
      expect(start, greaterThan(0), reason: 'nincs deleteIds');
      final body = source.substring(start, start + 1200);
      expect(body.contains('auth.currentUser?.isAnonymous == true'), isTrue);
      expect(body.contains('batch.delete('), isTrue);
      expect(body.contains('await batch.commit();'), isTrue);
    });

    test('a modell hordozza a jogosultat (a szűrés alapja)', () {
      final source = read('lib/models/app_notification.dart');
      expect(source.contains('recipientUid'), isTrue);
      expect(source.contains("data['recipientUid']"), isTrue);
    });
  });
}
