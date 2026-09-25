import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/chat_mention_source.dart';
import 'package:hungarian_hardstyle_app/services/community_service.dart';

/// A hivatkozás **jogosultsági kapuja** (tiszta függvény).
///
/// A tulajdonos döntése: *„A személyre/userre hivatkozás legyen elérhető
/// mindenkinek, többi csak admin/moderátornak."* A kliens-oldali kapu csak a
/// felületet kíméli (ne kínáljon lehetetlent) — a **hiteles** szűrés a
/// szerveren van (`functions/chat-mention-plan.js`). Ezért ez a teszt azt
/// méri, hogy a kapu pontosan a két jogosultságra nyílik, és hogy egy hiányos
/// vagy hibás érték **nem** nyitja ki véletlenül.
void main() {
  group('mentionPrivileged', () {
    test('admin és moderátor: igaz', () {
      expect(mentionPrivileged(CommunityService.accessAdmin), isTrue);
      expect(mentionPrivileged(CommunityService.accessModerator), isTrue);
    });

    test('none, üres és hiányzó érték: hamis', () {
      expect(mentionPrivileged(CommunityService.accessNone), isFalse);
      expect(mentionPrivileged(''), isFalse);
      expect(mentionPrivileged(null), isFalse);
      expect(mentionPrivileged('   '), isFalse);
    });

    test('a fiók-szerepkör (dj/partygoer) NEM hozzáférési jog', () {
      expect(mentionPrivileged('dj'), isFalse);
      expect(mentionPrivileged('partygoer'), isFalse);
      expect(mentionPrivileged('organizer'), isFalse);
    });

    test('a whitespace és a nagybetű nem téveszti meg', () {
      expect(mentionPrivileged(' Admin '), isTrue);
      expect(mentionPrivileged('MODERATOR'), isTrue);
      expect(mentionPrivileged('adminisztrator'), isFalse);
    });
  });
}
