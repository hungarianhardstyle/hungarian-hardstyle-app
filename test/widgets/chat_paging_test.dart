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

/// A chat lapozása a FELÜLETEN.
///
/// A tulajdonos jelzése: *„chaten kéne valami limit, … ha valaki vissza akar
/// olvasni legyen valami lehetőség arra hogy lefele scrollozáskor töltsön be"*.
///
/// A logika (határ, duplikáció, „elfogyott") a `ChatPaging` tiszta tesztekben
/// van lefedve; itt az számít, hogy a **képernyő tényleg betölti** a régebbi
/// lapot görgetésre, és hogy a betöltött üzenet meg is jelenik.
void main() {
  testWidgets('lefelé görgetve betölti a régebbi üzeneteket', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeChatService();
    await tester.pumpWidget(_app(service, _newestPosts()));
    await tester.pumpAndSettle();

    expect(find.text('Legfrissebb üzenet'), findsOneWidget);
    expect(find.text('Régebbi üzenet'), findsNothing);

    // Lefelé görgetünk: a chat a legfrissebbel kezdődik, tehát az időben
    // visszafelé haladunk.
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(
      service.loadOlderCalls,
      1,
      reason: 'görgetésre el kell indulnia a régebbi lap kérésének',
    );
    expect(find.text('Régebbi üzenet'), findsOneWidget);
  });

  testWidgets('ha elfogyott a régebbi üzenet, jelzi (nem kér újra)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeChatService(olderPosts: const <CommunityPost>[]);
    await tester.pumpWidget(_app(service, _newestPosts()));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(
      service.loadOlderCalls,
      1,
      reason: 'ha nincs több üzenet, nem kérünk feleslegesen újra',
    );
    expect(find.text('Ez a beszélgetés eleje.'), findsOneWidget);
  });
}

Widget _app(CommunityService service, List<CommunityPost> newest) {
  return ProviderScope(
    overrides: [
      communityServiceProvider.overrideWithValue(service),
      communityPostsProvider.overrideWith((ref) => Stream.value(newest)),
      communityAuthProvider.overrideWith((ref) => Stream<User?>.value(null)),
    ],
    child: const MaterialApp(home: LiveFeedScreen()),
  );
}

List<CommunityPost> _newestPosts() => [
  _post('newest-1', 'Legfrissebb üzenet', minutesAgo: 1),
  // A lista legyen hosszabb, mint a nézet: különben nincs mit görgetni, és a
  // lapozás a görgetésre indul.
  for (var i = 2; i <= 9; i++)
    _post('newest-$i', 'Üzenet $i', minutesAgo: i),
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
    createdAt: DateTime(2026, 9, 19, 12).subtract(Duration(minutes: minutesAgo)),
  );
}

/* ------------------------------------------------------------------ */
/* Hamis szolgáltatások                                                */
/* ------------------------------------------------------------------ */

class _FakeChatService extends CommunityService {
  _FakeChatService({List<CommunityPost>? olderPosts})
    : _olderPosts = olderPosts ?? [_post('older-1', 'Régebbi üzenet', minutesAgo: 600)],
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
