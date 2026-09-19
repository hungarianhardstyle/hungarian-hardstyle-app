import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/community_post.dart';
import 'package:hungarian_hardstyle_app/services/chat_paging.dart';

/// A chat-lapozás **tiszta** logikája.
///
/// A tulajdonos jelzése: *„chaten kéne valami limit … ha valaki vissza akar
/// olvasni legyen valami lehetőség arra hogy lefele scrollozáskor töltsön be
/// mert ha lesz 5 ezer chat bejegyzés ez lassú lehet"*.
///
/// A mért kiindulás: a chat már csak a legfrissebb 60 üzenetet figyeli, tehát
/// 5000 üzenet nem lassítja — a hiányosság az volt, hogy a 60-nál régebbit nem
/// lehetett elérni. Ezek a tesztek a lapozás két buktatóját mérik:
///  * a **kitűzött** üzenet miatti időugrást,
///  * a **duplikációt** a legfrissebb ablak és a lapok között.
CommunityPost _post(
  String id, {
  required DateTime createdAt,
  bool pinned = false,
}) {
  return CommunityPost(
    id: id,
    authorName: 'Teszt',
    authorId: 'uid-1',
    isAnonymous: false,
    authorImageUrl: '',
    authorRole: 'partygoer',
    authorAccessRole: 'none',
    text: 'Üzenet $id',
    replyToText: '',
    replyToName: '',
    imageUrl: '',
    pinned: pinned,
    reactions: const <String, int>{},
    createdAt: createdAt,
  );
}

void main() {
  final base = DateTime(2026, 9, 19, 12);

  group('oldestBoundary', () {
    test('a legrégebbi NEM kitűzött üzenetet adja', () {
      final posts = [
        _post('a', createdAt: base),
        _post('b', createdAt: base.subtract(const Duration(hours: 2))),
        _post('c', createdAt: base.subtract(const Duration(hours: 1))),
      ];

      expect(
        ChatPaging.oldestBoundary(posts),
        base.subtract(const Duration(hours: 2)),
      );
    });

    test('a KITŰZÖTT üzenetet kihagyja (különben időugrás lenne)', () {
      // Ha egy hete kitűzött üzenetet beszámítanánk, a következő lap a HÉT
      // napja előttről jönne, és a közte lévő beszélgetés kimaradna.
      final posts = [
        _post('pin', createdAt: base.subtract(const Duration(days: 7)), pinned: true),
        _post('a', createdAt: base),
        _post('b', createdAt: base.subtract(const Duration(minutes: 30))),
      ];

      expect(
        ChatPaging.oldestBoundary(posts),
        base.subtract(const Duration(minutes: 30)),
        reason: 'a kitűzött üzenet kora nem lehet a lapozás határa',
      );
    });

    test('ha CSAK kitűzött üzenet van, azok közül a legrégebbit adja', () {
      final posts = [
        _post('pin1', createdAt: base, pinned: true),
        _post('pin2', createdAt: base.subtract(const Duration(days: 3)), pinned: true),
      ];

      expect(
        ChatPaging.oldestBoundary(posts),
        base.subtract(const Duration(days: 3)),
      );
    });

    test('üres listánál null (nem indít felesleges kérést)', () {
      expect(ChatPaging.oldestBoundary(const <CommunityPost>[]), isNull);
    });
  });

  group('newOlderPosts', () {
    test('csak az ÚJ üzeneteket adja vissza, legfrissebbel elöl', () {
      final newest = [_post('n1', createdAt: base)];
      final already = [_post('o1', createdAt: base.subtract(const Duration(hours: 1)))];
      final incoming = [
        _post('o2', createdAt: base.subtract(const Duration(hours: 2))),
        _post('o3', createdAt: base.subtract(const Duration(hours: 3))),
      ];

      final fresh = ChatPaging.newOlderPosts(
        incoming: incoming,
        newest: newest,
        alreadyOlder: already,
      );

      expect(fresh.map((p) => p.id), ['o2', 'o3']);
    });

    test('a legfrissebb ablakkal NEM duplikál', () {
      // Az élő ablak közben elmozdulhat: ami már látszik, azt nem tesszük be
      // mégegyszer a lista végére.
      final newest = [_post('n1', createdAt: base)];
      final incoming = [
        _post('n1', createdAt: base),
        _post('o1', createdAt: base.subtract(const Duration(hours: 1))),
      ];

      final fresh = ChatPaging.newOlderPosts(
        incoming: incoming,
        newest: newest,
        alreadyOlder: const <CommunityPost>[],
      );

      expect(fresh.map((p) => p.id), ['o1']);
    });

    test('a már betöltött lapokat sem ismétli (ismételt görgetés)', () {
      final already = [_post('o1', createdAt: base.subtract(const Duration(hours: 1)))];
      final incoming = [
        _post('o1', createdAt: base.subtract(const Duration(hours: 1))),
      ];

      final fresh = ChatPaging.newOlderPosts(
        incoming: incoming,
        newest: const <CommunityPost>[],
        alreadyOlder: already,
      );

      expect(fresh, isEmpty);
    });

    test('a lapon belüli sorrend csökkenő (legfrissebb elöl)', () {
      final incoming = [
        _post('régi', createdAt: base.subtract(const Duration(hours: 5))),
        _post('új', createdAt: base.subtract(const Duration(hours: 1))),
      ];

      final fresh = ChatPaging.newOlderPosts(
        incoming: incoming,
        newest: const <CommunityPost>[],
        alreadyOlder: const <CommunityPost>[],
      );

      expect(fresh.map((p) => p.id), ['új', 'régi']);
    });
  });

  group('reachedStart', () {
    test('kevesebb találat, mint a lapméret: elfogyott', () {
      expect(ChatPaging.reachedStart(received: 4, pageSize: 30), isTrue);
      expect(ChatPaging.reachedStart(received: 0, pageSize: 30), isTrue);
    });

    test('pontosan tele lap: MÉG lehet régebbi', () {
      expect(ChatPaging.reachedStart(received: 30, pageSize: 30), isFalse);
    });
  });
}
