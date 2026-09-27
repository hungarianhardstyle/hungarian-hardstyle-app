// A Firestore/Auth osztályok `sealed`-ek, ezért az `implements` jelzést a lint
// kifogásolja. Itt SZÁNDÉKOS: nem új csomagot akarunk behúzni, hanem a lehető
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
import 'package:hungarian_hardstyle_app/services/birth_date.dart';
import 'package:hungarian_hardstyle_app/services/community_service.dart';
import 'package:hungarian_hardstyle_app/widgets/birth_date_field.dart';

/// **A hiányzó születési dátum felszólítása a Chat fülön** (a tulajdonos
/// kérése, 2026-09-27).
///
/// A már regisztrált, dátum nélküli felhasználó a Chat fülön figyelmeztető sávot
/// kap, és **egyszer** fel is ajánljuk a kitöltést. A sáv addig marad, amíg a
/// dátum be nem kerül — ezt méri a teszt a valódi képernyőn.
void main() {
  testWidgets('dátum nélkül sáv + felajánlás, mentés után eltűnik', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeProfileService(<String, dynamic>{
      'displayName': 'Teszt Elek',
    });
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    // 1) A sáv látszik (nem elrejthető), és a felajánlás magától megnyílt.
    expect(find.text('A születési dátumod még nincs megadva.'), findsOneWidget);
    expect(find.text('Hiányzik a születési dátum'), findsOneWidget);

    // 2) „Most nem” — az ablak bezárul, a sáv marad.
    await tester.tap(find.text('Most nem'));
    await tester.pumpAndSettle();
    expect(find.text('Hiányzik a születési dátum'), findsNothing);
    expect(find.text('A születési dátumod még nincs megadva.'), findsOneWidget);

    // 3) „Megadom” — újra megnyílik, dátum választása nélkül a Mentés tiltott.
    await tester.tap(find.text('Megadom'));
    await tester.pumpAndSettle();
    expect(find.text('Hiányzik a születési dátum'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mentés'),
    );
    expect(save.onPressed, isNull, reason: 'dátum nélkül nincs mentés');

    // 4) A dátumválasztó a 2000-01-01 kezdőnapot kínálja (a 16+ korlát alatt).
    await tester.tap(find.text('Dátum kiválasztása'));
    await tester.pumpAndSettle();
    expect(find.text('Születési dátum'), findsWidgets);
    await tester.tap(find.text('Rendben'));
    await tester.pumpAndSettle();

    // 5) Mentés — a szolgáltatás a saját UID-ra, egyetlen dátummal hívódik.
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(service.saved, ['uid-a:2000-01-01']);
    expect(
      find.text('A születési dátumod még nincs megadva.'),
      findsNothing,
      reason: 'a sáv a mentés után eltűnik',
    );
  });

  testWidgets('akinek már van dátuma, nem kap felszólítást', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeProfileService(<String, dynamic>{
      'displayName': 'Teszt Elek',
      'birthDate': '1990-01-31',
    });
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('A születési dátumod még nincs megadva.'), findsNothing);
    expect(find.text('Hiányzik a születési dátum'), findsNothing);
    expect(service.saved, isEmpty);
  });

  testWidgets('a Chat sávjából a VALÓDI dátum is beírható (nincs 16 éves korlát)', (
    tester,
  ) async {
    // A tulajdonos kérése: a **már regisztrált** tagot semmi nem zárja ki, ezért
    // a felszólításban a mai nap a felső határ — egy 15 éves tag is be tudja
    // írni a valódi dátumát (a `saveBirthDate` amúgy sem utasítja el).
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BirthDatePromptDialog())),
    );
    await tester.tap(find.text('Dátum kiválasztása'));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(BirthDate.format(picker.lastDate), BirthDate.format(BirthDate.today()));
    expect(
      BirthDate.format(picker.firstDate),
      BirthDate.format(DateTime(BirthDate.firstYear)),
    );
  });

  testWidgets('a regisztrációs űrlapon ma − 16 év az utolsó választható nap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityProfileBirthDateField(
            value: null,
            registration: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dátum kiválasztása'));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(
      BirthDate.format(picker.lastDate),
      BirthDate.format(BirthDate.lastAllowedPick()),
      reason: 'a 16 év alatti dátum már nem is választható',
    );
  });
}

Widget _app(CommunityService service) => ProviderScope(
  overrides: [
    communityServiceProvider.overrideWithValue(service),
    communityPostsProvider.overrideWith((ref) => Stream.value(_posts())),
    communityAuthProvider.overrideWith(
      (ref) => Stream<User?>.value(_FakeUser()),
    ),
  ],
  child: const MaterialApp(home: LiveFeedScreen()),
);

List<CommunityPost> _posts() => [
  CommunityPost(
    id: 'post-1',
    authorName: 'Teszt Elek',
    // ⚠️ Üres szerző-UID: a kártya így nem kérdezi le a szerző nyilvános
    // profilját (az a valódi Firestore-t hívná, amit ez a teszt nem akar).
    authorId: '',
    isAnonymous: false,
    authorImageUrl: '',
    authorRole: 'partygoer',
    authorAccessRole: 'none',
    text: 'Szia!',
    replyToText: '',
    replyToName: '',
    imageUrl: '',
    pinned: false,
    reactions: const <String, int>{},
    createdAt: DateTime(2026, 9, 27, 12),
  ),
];

/* ------------------------------------------------------------------ */
/* Hamis szolgáltatások                                                */
/* ------------------------------------------------------------------ */

class _FakeProfileService extends CommunityService {
  _FakeProfileService(this._profileData)
    : super(auth: _FakeAuth(), firestore: _FakeFirestore());

  Map<String, dynamic> _profileData;
  final List<String> saved = <String>[];

  @override
  Future<User> ensureAnonymousUser() async => _FakeUser();

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> profile({
    bool forceServer = false,
  }) async => _FakeProfileSnapshot(_profileData);

  @override
  String resolveProfileImage(
    Map<String, dynamic> data, [
    String fallback = '',
  ]) => fallback;

  @override
  Future<void> saveBirthDate(String userId, String birthDate) async {
    saved.add('$userId:$birthDate');
    _profileData = <String, dynamic>{..._profileData, 'birthDate': birthDate};
  }
}

class _FakeProfileSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeProfileSnapshot(this._data);

  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;
}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'uid-a';

  @override
  bool get isAnonymous => false;

  @override
  String? get displayName => 'Teszt Elek';

  @override
  String? get email => 'teszt@example.com';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();

  @override
  Stream<User?> userChanges() => Stream<User?>.value(_FakeUser());
}

class _FakeFirestore extends Fake implements FirebaseFirestore {}
