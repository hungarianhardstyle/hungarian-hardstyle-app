// A Firestore/Auth osztalyok `sealed`-ek, ezert az `implements` jelzest a lint
// kifogasolja. Itt SZANDEKOS: a lehető legkisebb felületet utánozzuk, hogy a
// képernyő VALÓDI kódja fusson.
// ignore_for_file: subtype_of_sealed_class

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/community_post.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/screens/community/community_screen.dart';
import 'package:hungarian_hardstyle_app/services/community_service.dart';

/// A VÁLASZ-IDÉZET KOPPINTÁSA — a tulajdonos jelzése (2026-09-26):
/// *„ez mi? nem azt kértem, hogy egy ablakot dobjon fel, hanem, hogy ugorjon oda
/// a chaten"*.
///
/// Ez a fájl a **felületen** méri:
///  1. a koppintás **odaugrik** az eredeti üzenetre (az látszik a képernyőn),
///  2. **nem** nyílik fel ablak,
///  3. az új válasz kérése **hordozza** a hivatkozott üzenet azonosítóját
///     (`replyToId`), mert ebből lesz a szerveren a tárolt hivatkozás.
void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpChat(
    WidgetTester tester, {
    required List<CommunityPost> posts,
    CommunityService? service,
    String focusId = '',
  }) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityServiceProvider.overrideWithValue(
            service ?? _FakeChatService(),
          ),
          communityPostsProvider.overrideWith((ref) => Stream.value(posts)),
          communityAuthProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: MaterialApp(home: LiveFeedScreen(focusPostId: focusId)),
      ),
    );
    await settle(tester);
  }

  void expectOnScreen(WidgetTester tester, String text) {
    final finder = find.text(text);
    expect(finder, findsWidgets, reason: 'a(z) „$text" kártya fel sem épült');
    final rect = tester.getRect(finder.first);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      rect.top >= 0 && rect.bottom <= screen.height,
      isTrue,
      reason: 'a(z) „$text" a látható területen kell legyen (rect: $rect)',
    );
  }

  testWidgets('az idézetre koppintva ODAUGRUNK az eredeti üzenetre', (
    tester,
  ) async {
    // A válasz a lista elején van, a hivatkozott üzenet mélyen — így az ugrás
    // tényleg görgetést igényel.
    final posts = <CommunityPost>[
      _post(
        'reply',
        'Ez egy válasz',
        minutesAgo: 0,
        replyToText: 'Üzenet 24',
        replyToName: 'Unknown User 1',
      ),
      for (var i = 0; i < 40; i++) _post('p$i', 'Üzenet $i', minutesAgo: i + 1),
    ];
    await pumpChat(tester, posts: posts);

    // Kezdetben a hivatkozott üzenet fel sem épült (mélyen van) — így a mérés
    // bizonyítja, hogy az ugráshoz tényleg görgetni kellett.
    expect(
      find.text('Üzenet 24'),
      findsNothing,
      reason: 'a kiindulás legyen mélyen (különben nem mérünk semmit)',
    );

    await tester.tap(find.textContaining('üzenetére').first);
    await settle(tester);

    expectOnScreen(tester, 'Üzenet 24');
    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'a tulajdonos NEM ablakot kért, hanem odaugrást',
    );
  });

  testWidgets('a 200 karakterre vágott, azonosító nélküli RÉGI idézet is ugrik', (
    tester,
  ) async {
    // Régi üzenet: nincs `replyToId`, csak a (vágott) szöveg — a hosszabb
    // eredeti kezdetével kell egyeznie.
    final original = 'Ez egy nagyon hosszú eredeti üzenet ' * 12;
    final posts = <CommunityPost>[
      _post(
        'reply',
        'Válasz egy régi üzenetre',
        minutesAgo: 0,
        replyToText: original.substring(0, 200),
        replyToName: 'Unknown User 1',
      ),
      for (var i = 0; i < 40; i++) _post('p$i', 'Töltelék $i', minutesAgo: i + 1),
      _post('old', original, minutesAgo: 60),
    ];
    await pumpChat(tester, posts: posts);

    // ⚠️ A feltétel az EREDETI (teljes) szövegre szűr: az idézet 200 karakterre
    // vágott, ezért csak az eredeti kártya tartalmazza a teljes szöveget.
    expect(
      find.textContaining(original),
      findsNothing,
      reason: 'a hivatkozott üzenet kezdetben nincs a betöltött ablakban',
    );

    await tester.tap(find.textContaining('üzenetére').first);
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    final matches = find.textContaining(original);
    expect(matches, findsWidgets, reason: 'az eredeti üzenet nem épült fel');
    final rect = tester.getRect(matches.first);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      rect.top >= 0 && rect.bottom <= screen.height,
      isTrue,
      reason: 'az eredeti üzenet a látható területen kell legyen (rect: $rect)',
    );
  });

  testWidgets('a válasz kérése hordozza a hivatkozott üzenet azonosítóját', (
    tester,
  ) async {
    final service = _FakeChatService();
    final posts = <CommunityPost>[
      _post('p0', 'Eredeti üzenet', minutesAgo: 0),
    ];
    await pumpChat(tester, posts: posts, service: service);

    // „Válasz" a kártyán → a beviteli mezőbe írunk → küldés.
    await tester.tap(find.text('Válasz').first);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Ez a válaszom');
    await settle(tester);
    await tester.tap(find.text('Küldés').first);
    await settle(tester);

    expect(
      service.lastReplyToId,
      'p0',
      reason:
          'a küldött válasznak hordoznia kell a hivatkozott üzenet azonosítóját '
          '(ebből lesz az odaugrás a következő üzeneteknél)',
    );
    expect(service.lastReplyToText, 'Eredeti üzenet');
  });
}

CommunityPost _post(
  String id,
  String text, {
  required int minutesAgo,
  String replyToText = '',
  String replyToName = '',
}) {
  return CommunityPost(
    id: id,
    authorName: 'Unknown User 1',
    authorId: '',
    isAnonymous: false,
    authorImageUrl: '',
    authorRole: 'partygoer',
    authorAccessRole: 'none',
    text: text,
    replyToText: replyToText,
    replyToName: replyToName,
    imageUrl: '',
    pinned: false,
    reactions: const <String, int>{},
    createdAt: DateTime(2026, 9, 26, 12).subtract(Duration(minutes: minutesAgo)),
  );
}

/* ------------------------------------------------------------------ */
/* Hamis szolgáltatások                                                */
/* ------------------------------------------------------------------ */

class _FakeChatService extends CommunityService {
  _FakeChatService()
    : super(auth: _FakeAuth(), firestore: _FakeFirestore());

  String? lastReplyToId;
  String? lastReplyToText;

  @override
  Future<({int dropped, int everyoneNotified, int everyonePushed})> publishPost({
    required String text,
    Uint8List? imageBytes,
    bool pinned = false,
    String? replyToText,
    String? replyToName,
    String? replyToAuthorId,
    String? replyToId,
    List<Map<String, Object>> mentions = const <Map<String, Object>>[],
  }) async {
    lastReplyToText = replyToText;
    lastReplyToId = replyToId;
    return (dropped: 0, everyoneNotified: 0, everyonePushed: 0);
  }

  @override
  Future<List<CommunityPost>> loadOlderPosts({
    required DateTime before,
    int limit = 30,
  }) async => const <CommunityPost>[];

  @override
  String resolveProfileImage(Map<String, dynamic> data, [String fallback = '']) =>
      fallback;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> userChanges() => Stream<User?>.value(null);
}

class _FakeFirestore extends Fake implements FirebaseFirestore {}
