// A Firestore/Auth osztalyok `sealed`-ek, ezert az `implements` jelzest a lint
// kifogasolja. Itt SZANDEKOS: nem uj csomagot akarunk behuzni, hanem a lehető
// legkisebb felületet utánozzuk, hogy a képernyő VALÓDI kódja fusson.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/community_post.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/screens/community/community_screen.dart';
import 'package:hungarian_hardstyle_app/services/community_service.dart';

/// Az értesítésből induló odaugrás a FELÜLETEN.
///
/// A tulajdonos jelzése (2026-09-25): *„fentvan és egy régebbi chat like, update
/// előtti, rányomtam és nem dobott a chat üzire … régebbi chat üzivel nem megy,
/// újabba igen"*.
///
/// **A mért gyökér:** a `ListView` csak a látható elemeket építi fel, ezért egy
/// **mélyen lévő** megjelölt üzenet kártyája nem létezik — a `Scrollable.
/// ensureVisible` viszont kártya-kontextust kér. A régi kód ilyenkor a lista
/// **végére** ugrott (`maxScrollExtent`), ami a legrégebbi üzeneteket mutatja,
/// nem a megjelöltet; a friss (legfelül lévő) üzenet viszont már fel volt
/// épülve, ezért az működött.
///
/// Ezek a tesztek azt kérik számon, hogy a megjelölt üzenet **látszik** is a
/// képernyőn, ne csak kiemelve legyen valahol a listában.
void main() {
  /// Az odaugrás legfeljebb néhány 250 ms-os ugrásból és 120 ms-os várakozásból
  /// áll. A `Future.delayed` **nem kelt képkockát**, ezért a `pumpAndSettle`
  /// önmagában nem várná ki — időt kell adni neki, különben a teszt „pending
  /// timer" hibával áll meg.
  Future<void> settleFocus(WidgetTester tester) async {
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpChat(
    WidgetTester tester, {
    required List<CommunityPost> posts,
    required String focusId,
    CommunityService? service,
  }) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(posts, focusId, service: service));
    await settleFocus(tester);
  }

  /// A megadott szöveg a **látható** területen van-e (nem elég, hogy létezik).
  void expectOnScreen(WidgetTester tester, String text) {
    final finder = find.text(text);
    expect(finder, findsOneWidget, reason: 'a(z) „$text" kártya fel sem épült');
    final rect = tester.getRect(finder);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      rect.top >= 0 && rect.bottom <= screen.height,
      isTrue,
      reason:
          'a(z) „$text" a látható területen kell legyen (rect: $rect, képernyő: $screen)',
    );
  }

  testWidgets('a legfrissebb (legfelül lévő) megjelölt üzenethez odagörget', (
    tester,
  ) async {
    await pumpChat(tester, posts: _posts(40), focusId: 'p0');
    expectOnScreen(tester, 'Üzenet 0');
  });

  testWidgets('a MÉLYEN lévő megjelölt üzenethez is odagörget', (tester) async {
    await pumpChat(tester, posts: _posts(40), focusId: 'p24');
    expectOnScreen(tester, 'Üzenet 24');
  });

  testWidgets('a legrégebbi megjelölt üzenethez is odagörget', (tester) async {
    await pumpChat(tester, posts: _posts(40), focusId: 'p39');
    expectOnScreen(tester, 'Üzenet 39');
  });

  testWidgets('egy már betöltött RÉGEBBI lap üzenetéhez is odagörget', (
    tester,
  ) async {
    final service = _FakeChatService(
      olderPosts: [
        for (var i = 40; i < 55; i++) _post('p$i', 'Üzenet $i', minutesAgo: i),
      ],
    );
    await pumpChat(
      tester,
      posts: _posts(40),
      focusId: 'p47',
      service: service,
    );
    expectOnScreen(tester, 'Üzenet 47');
  });
}

Widget _app(
  List<CommunityPost> newest,
  String focusId, {
  CommunityService? service,
}) {
  return ProviderScope(
    overrides: [
      communityServiceProvider.overrideWithValue(service ?? _FakeChatService()),
      communityPostsProvider.overrideWith((ref) => Stream.value(newest)),
      communityAuthProvider.overrideWith((ref) => Stream<User?>.value(null)),
    ],
    child: MaterialApp(home: LiveFeedScreen(focusPostId: focusId)),
  );
}

List<CommunityPost> _posts(int count) => [
  for (var i = 0; i < count; i++) _post('p$i', 'Üzenet $i', minutesAgo: i),
];

CommunityPost _post(String id, String text, {required int minutesAgo}) {
  return CommunityPost(
    id: id,
    authorName: 'Unknown User 1',
    authorId: '',
    isAnonymous: false,
    authorImageUrl: '',
    authorRole: 'partygoer',
    authorAccessRole: 'none',
    text: text,
    replyToText: '',
    replyToName: '',
    imageUrl: '',
    pinned: false,
    reactions: const <String, int>{},
    createdAt: DateTime(2026, 9, 25, 12).subtract(Duration(minutes: minutesAgo)),
  );
}

/* ------------------------------------------------------------------ */
/* Hamis szolgáltatások                                                */
/* ------------------------------------------------------------------ */

class _FakeChatService extends CommunityService {
  _FakeChatService({List<CommunityPost>? olderPosts})
    : _olderPosts = olderPosts ?? const <CommunityPost>[],
      super(auth: _FakeAuth(), firestore: _FakeFirestore());

  final List<CommunityPost> _olderPosts;
  int loadOlderCalls = 0;

  @override
  Future<List<CommunityPost>> loadOlderPosts({
    required DateTime before,
    int limit = 30,
  }) async {
    loadOlderCalls += 1;
    return _olderPosts;
  }

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
