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

  group('FORRÁS-LINT: a képernyő és a szolgáltatás bekötése', () {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    test('a képernyőn van kijelölés mód, és a koppintás JELÖL', () {
      final source = read(
        'lib/screens/notifications/notification_center_screen.dart',
      );
      expect(source.contains('bool _selecting = false;'), isTrue);
      expect(source.contains('final Set<String> _selected'), isTrue);
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
      // Fület váltva a kijelölés törlődik (másik lista).
      expect(source.contains('_selected.clear();\n                        _selecting = false;'), isTrue);
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
