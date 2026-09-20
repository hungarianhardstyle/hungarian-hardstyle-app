// A Firestore/Auth osztalyok `sealed`-ek, ezert az `implements` jelzest a lint
// kifogasolja. Itt SZANDEKOS: a lehető legkisebb felületet utánozzuk.
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

/// „Lájkoltam-e már?" — a Chat-reakció **egyértelmű** jelzése.
///
/// A tulajdonos jelzése: *„ha valaki lájkol egy chat üzenetet, valahogy
/// jelezhetné hogy az adott user lájkolta mert nem egyértelmű, nevet ne írjon
/// oda, csak lássa hogy már lájkolta"*.
///
/// A lényeg, amit itt mérünk:
///   1. a **saját** reakcióm jelölve van (pipa + kiemelés + tipp),
///   2. **más** reakciója NEM jelenik meg az enyémként (és **név sincs** kiírva),
///   3. a koppintás **azonnal** látszik (a szerver válaszából, nem várunk a képre).
void main() {
  const myUid = 'me-uid';

  testWidgets('a saját reakcióm jelölve van — és nincs névkiírás', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeReactionService(),
      posts: [
        _post(
          'mine',
          'Az én reakcióm',
          reactions: const {'❤️': 1},
          reactionBy: const {myUid: '❤️'},
        ),
      ],
    );

    expect(
      find.byIcon(Icons.check_circle),
      findsOneWidget,
      reason: 'a saját reakciót jelölni kell (egyetlen chipen)',
    );
    expect(find.byTooltip('Te reagáltál erre'), findsOneWidget);
    expect(find.text('❤️ 1'), findsOneWidget);
  });

  testWidgets('más felhasználó reakciója nem jelenik meg az enyémként', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeReactionService(),
      posts: [
        _post(
          'other',
          'Más reakciója',
          reactions: const {'🔥': 3},
          reactionBy: const {'mas-uid': '🔥'},
        ),
      ],
    );

    expect(
      find.byIcon(Icons.check_circle),
      findsNothing,
      reason: 'más reakcióját nem szabad a sajátomként jelölni',
    );
    expect(find.byTooltip('Te reagáltál erre'), findsNothing);
    expect(find.text('🔥 3'), findsOneWidget, reason: 'a darabszám látszik');
  });

  testWidgets('a koppintás azonnal jelzi a saját reakciót (nem vár a képre)', (
    tester,
  ) async {
    final service = _FakeReactionService();
    await _pump(
      tester,
      service,
      posts: [_post('tap', 'Koppintás', reactions: const {'❤️': 1})],
    );

    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.tap(find.text('❤️ 1'));
    await tester.pump();

    expect(service.toggleCalls, 1);
    expect(
      find.byIcon(Icons.check_circle),
      findsOneWidget,
      reason: 'a szerver válasza (selected) alapján azonnal látszik',
    );
  });

  testWidgets('visszavonáskor eltűnik a jelzés', (tester) async {
    final service = _FakeReactionService(selected: '');
    await _pump(
      tester,
      service,
      posts: [
        _post(
          'back',
          'Visszavonás',
          reactions: const {'❤️': 1},
          reactionBy: const {myUid: '❤️'},
        ),
      ],
    );

    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('❤️ 1'));
    await tester.pump();

    expect(service.toggleCalls, 1);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  test('a myReaction csak a saját UID-ot olvassa (neveket nem)', () {
    final post = _post(
      'pure',
      'Tiszta logika',
      reactionBy: const {'mas-uid': '🔥', myUid: '🙌'},
    );

    expect(post.myReaction(myUid), '🙌');
    expect(post.myReaction('mas-uid'), '🔥');
    expect(post.myReaction('nincs-ilyen'), '');
    expect(
      post.myReaction(null),
      '',
      reason: 'kijelentkezve nincs saját reakció',
    );
    expect(post.myReaction(''), '');
  });

  test('a Firestore-dokumentumból beolvassa a reactionBy térképet', () {
    final post = CommunityPost.fromDocument(
      _FakeSnapshot({
        'authorName': 'Teszt',
        'reactions': {'❤️': 2},
        'reactionBy': {'a': '❤️', 'b': 42, 'c': '🔥'},
      }),
    );

    expect(post.reactionBy, {'a': '❤️', 'c': '🔥'});
    expect(
      post.myReaction('a'),
      '❤️',
      reason: 'a saját UID-hoz tartozó reakció kiolvasható',
    );
    expect(post.reactions['❤️'], 2, reason: 'a darabszám változatlanul megy');
  });

  test('hiányzó reactionBy esetén üres (nem dob, nem hazudik)', () {
    final post = CommunityPost.fromDocument(
      _FakeSnapshot({'authorName': 'Teszt'}),
    );

    expect(post.reactionBy, isEmpty);
    expect(post.myReaction(myUid), '');
  });
}

/* ------------------------------------------------------------------ */
/* Segédek                                                             */
/* ------------------------------------------------------------------ */

Future<void> _pump(
  WidgetTester tester,
  CommunityService service, {
  required List<CommunityPost> posts,
}) async {
  // Valósághű nézet (1200 px / 3x = 400 logikai px), hogy a kártyák
  // túlcsordulás nélkül elférjenek.
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityServiceProvider.overrideWithValue(service),
        communityPostsProvider.overrideWith((ref) => Stream.value(posts)),
        communityAuthProvider.overrideWith(
          (ref) => Stream<User?>.value(_FakeUser()),
        ),
      ],
      child: const MaterialApp(home: LiveFeedScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

CommunityPost _post(
  String id,
  String text, {
  Map<String, int> reactions = const <String, int>{},
  Map<String, String> reactionBy = const <String, String>{},
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
    replyToText: '',
    replyToName: '',
    imageUrl: '',
    pinned: false,
    reactions: reactions,
    reactionBy: reactionBy,
    createdAt: DateTime(2026, 9, 20, 12),
  );
}

class _FakeReactionService extends CommunityService {
  _FakeReactionService({this.selected = '❤️'})
    : super(auth: _FakeAuth(), firestore: _FakeFirestore());

  final String selected;
  int toggleCalls = 0;

  @override
  Future<String> toggleReaction({
    required String postId,
    required String emoji,
  }) async {
    toggleCalls += 1;
    return selected;
  }

  @override
  String resolveProfileImage(
    Map<String, dynamic> data, [
    String fallback = '',
  ]) => fallback;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();

  @override
  Stream<User?> userChanges() => Stream<User?>.value(_FakeUser());
}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'me-uid';

  @override
  bool get isAnonymous => false;

  // A `_PostCard` az admin-jogot az e-mailből is nézi (`isAdmin`), ezért ezeket
  // meg kell adni — enélkül a `Fake` „UnimplementedError"-t dob a build közben.
  @override
  String? get email => 'me@example.com';

  @override
  String? get displayName => 'Teszt Elek';

  @override
  String? get photoURL => null;
}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

/// A `CommunityPost.fromDocument` bemenete (csak a `data()` és az `id` kell).
class _FakeSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeSnapshot(this._data);

  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  String get id => 'fake-post';
}
