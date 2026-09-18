import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/notification_service.dart';

/// Az „összes törlése" a LÁTHATÓ fülre vonatkozik.
///
/// **A tulajdonos jelzése:** *„Notifyt lehet archiválni és átrakja az
/// archiváltba — de ha az aktív fülön nyomok egy összes törlését, töröl mindent
/// még az archiváltat is, ezt külön kéne választani: aktívban az aktívat
/// törölje, archivban az archiváltakat"*.
///
/// A gyökér: a `NotificationService.deleteAll()` **feltétel nélkül** az összes
/// rekordot törölte, a képernyő pedig mindig ezt hívta, tekintet nélkül arra,
/// melyik fül van kiválasztva. Ezért az Aktív fülről indítva az archívum is
/// eltűnt.
///
/// A teszt kézzel írt Firestore-hasznot használ (nem új csomagot): a valódi
/// osztályokat `implements`-szel valósítja meg, ezért a szolgáltatás a VALÓDI
/// `deleteAll()` kódját futtatja, és csak a tárhely hamis.
class _RegisteredUser extends Fake implements User {
  @override
  bool get isAnonymous => false;

  @override
  String get uid => 'test-uid';
}

class _AnonymousUser extends Fake implements User {
  @override
  bool get isAnonymous => true;

  @override
  String get uid => 'anon-uid';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this._user);

  final User? _user;

  @override
  User? get currentUser => _user;
}

class _FakeRef extends Fake implements DocumentReference<Map<String, dynamic>> {
  _FakeRef(this.id);

  @override
  final String id;
}

class _FakeDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;

  @override
  DocumentReference<Map<String, dynamic>> get reference => _FakeRef(id);
}

class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _FakeQuery extends Fake
    implements Query<Map<String, dynamic>> {
  _FakeQuery(this._docs);

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _FakeQuerySnapshot(_docs);
}

class _FakeCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this._docs);

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    // A szolgaltatas egyetlen szuroje a `recipientUid`.
    final filtered = _docs.where((doc) {
      if (field != 'recipientUid') return true;
      return doc.data()['recipientUid'] == isEqualTo;
    }).toList();
    return _FakeQuery(filtered);
  }
}

/// A batch csak a törlést naplózza; a lényeg, hogy MELYIK dokumentumokra hívták.
class _FakeBatch extends Fake implements WriteBatch {
  _FakeBatch(this.deleted);

  final List<String> deleted;

  @override
  void delete(DocumentReference<dynamic> documentRef) {
    deleted.add(documentRef.id);
  }

  @override
  Future<void> commit() async {}
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  _FakeFirestore(this._docs);

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;
  final List<String> deleted = [];

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _FakeCollection(_docs);

  @override
  WriteBatch batch() => _FakeBatch(deleted);

  /// A törlés UTAN megmaradt rekordok azonositoi.
  Set<String> get remaining => _docs
      .map((doc) => doc.id)
      .where((id) => !deleted.contains(id))
      .toSet();
}

_FakeDoc _doc(String id, Map<String, dynamic> data) =>
    _FakeDoc(id, {'recipientUid': 'test-uid', ...data});

_FakeFirestore _seed() {
  return _FakeFirestore([
    _doc('active-1', {'title': 'Aktív egy'}),
    _doc('active-2', {
      'title': 'Aktív kettő (olvasott)',
      'readAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    }),
    _doc('archived-1', {
      'title': 'Archivált egy',
      'archivedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    }),
    _doc('archived-2', {
      'title': 'Archivált kettő',
      'readAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      'archivedAt': Timestamp.fromDate(DateTime(2026, 9, 2)),
    }),
    // Egy MÁS felhasználó értesítése: soha nem szabad hozzányúlni.
    _FakeDoc('other-1', {'recipientUid': 'mas-uid', 'title': 'Másé'}),
  ]);
}

NotificationService _service(_FakeFirestore firestore) =>
    NotificationService(auth: _FakeAuth(_RegisteredUser()), firestore: firestore);

void main() {
  test('aktív törlés: az aktívak eltűnnek, az ARCHIVÁLTAK MEGMARADNAK', () async {
    final firestore = _seed();

    await _service(firestore).deleteAll(archived: false);

    expect(
      firestore.deleted..sort(),
      ['active-1', 'active-2'],
      reason: 'az archivált fül tartalma nem törölhető az aktív fülről',
    );
    expect(firestore.remaining, {'archived-1', 'archived-2', 'other-1'});
  });

  test('archivált törlés: az archiváltak eltűnnek, az AKTÍVAK MEGMARADNAK', () async {
    final firestore = _seed();

    await _service(firestore).deleteAll(archived: true);

    expect(
      firestore.deleted..sort(),
      ['archived-1', 'archived-2'],
      reason: 'az aktív fül tartalma nem törölhető az archivált fülről',
    );
    expect(firestore.remaining, {'active-1', 'active-2', 'other-1'});
  });

  test('a más felhasználó értesítését egyik fül sem törli', () async {
    final firestore = _seed();
    final service = _service(firestore);

    await service.deleteAll(archived: false);
    await service.deleteAll(archived: true);

    expect(firestore.remaining, {'other-1'});
  });

  test('olvasott, de nem archivált értesítés az AKTÍV fülhöz tartozik', () async {
    // Az „aktív" jelentése: nincs `archivedAt`. Az olvasottság (`readAt`) ezt
    // nem valtoztatja meg — kulonben egy olvasott ertesites atcsuszna a masik
    // fulre, es a torles a rossz helyen hatna.
    final firestore = _seed();

    await _service(firestore).deleteAll(archived: false);

    expect(firestore.deleted.contains('active-2'), isTrue);
    expect(firestore.deleted.contains('archived-2'), isFalse);
  });

  test('vendég fióknál nem töröl semmit', () async {
    final firestore = _seed();
    final service = NotificationService(
      auth: _FakeAuth(_AnonymousUser()),
      firestore: firestore,
    );

    await service.deleteAll(archived: false);
    await service.deleteAll(archived: true);

    expect(firestore.deleted, isEmpty);
  });

  test('üres fülön a törlés nem hiba', () async {
    final firestore = _FakeFirestore([
      _doc('active-1', {'title': 'Aktív'}),
    ]);

    await _service(firestore).deleteAll(archived: true);

    expect(firestore.deleted, isEmpty);
    expect(firestore.remaining, {'active-1'});
  });
}
