// A Firestore osztalyok (`DocumentSnapshot`, `CollectionReference`, ...) `sealed`-ek,
// ezert az `implements` jelzest a lint kifogasolja. Itt SZANDEKOS: nem uj csomagot
// akarunk behuzni (`fake_cloud_firestore`), hanem a lehető legkisebb felületet
// utánozzuk, hogy a szolgáltatás VALÓDI kódja fusson.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/community_service.dart';

/// A tulajdonos jelzése: *„adminként nem törli az usert, googleval regelt"*.
///
/// Élő mérés (függvénynapló, 2026-09-19 06:39): a `deleteCommunityUser`
/// **lefutott** (HTTP 200, az Auth-fiók és a `community_profiles` sor is
/// eltűnt), a képek háttértakarítása maradt függőben. A Google-fiókkal
/// regisztrált felhasználó viszont **ugyanazzal a UID-dal újra létrejön**, amikor
/// újra bejelentkezik — ezért a törlést nem az Auth hibája jelzi, hanem a
/// szerveroldali `deleted_user_ids` jelző.
///
/// Ezek a tesztek azt mérik, hogy az app ezt a jelzőt **helyesen** olvassa:
/// létező jelzőnél igazat, hiányzó jelzőnél hamisat, hálózati hiba esetén pedig
/// **hamisat** — azaz egy átmeneti hiba soha nem zárhat ki egy legitim
/// felhasználót.
void main() {
  test('létező törlés-jelzőnél igazat ad (a visszatérő Google-fiók esete)', () async {
    final service = CommunityService(
      auth: _FakeAuth(),
      firestore: _FakeFirestore(deletedUids: {'uid-deleted'}),
    );

    expect(
      await service.isAccountMarkedDeleted('uid-deleted'),
      isTrue,
      reason: 'a törölt fiók jele a szerveren van, ezt fel kell ismerni',
    );
  });

  test('jelző nélkül hamisat ad (normál felhasználó)', () async {
    final service = CommunityService(auth: _FakeAuth(), firestore: _FakeFirestore());

    expect(await service.isAccountMarkedDeleted('uid-normal'), isFalse);
  });

  test('más felhasználó jelzője nem téveszti meg', () async {
    final service = CommunityService(
      auth: _FakeAuth(),
      firestore: _FakeFirestore(deletedUids: {'mas-uid'}),
    );

    expect(
      await service.isAccountMarkedDeleted('sajat-uid'),
      isFalse,
      reason: 'csak a saját sor számít',
    );
  });

  test('hiba esetén hamisat ad — átmeneti hiba nem zárhat ki senkit', () async {
    final service = CommunityService(auth: _FakeAuth(), firestore: _FakeFirestore(failing: true));

    expect(await service.isAccountMarkedDeleted('uid-barmi'), isFalse);
  });

  test('üres UID-ra nem indít kérést', () async {
    final firestore = _FakeFirestore(deletedUids: {'uid-x'});

    expect(
      await CommunityService(auth: _FakeAuth(), firestore: firestore).isAccountMarkedDeleted('   '),
      isFalse,
    );
    expect(firestore.reads, 0, reason: 'üres UID-ra felesleges olvasni');
  });
}

/* ------------------------------------------------------------------ */
/* Minimál Firestore-hamis                                             */
/* ------------------------------------------------------------------ */

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth();
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  _FakeFirestore({this.deletedUids = const {}, this.failing = false});

  final Set<String> deletedUids;
  final bool failing;
  int reads = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _FakeCollection(this, path);
}

class _FakeCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this._firestore, this._path);

  final _FakeFirestore _firestore;
  final String _path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _FakeDocument(_firestore, _path, path ?? '');
}

class _FakeDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocument(this._firestore, this._collection, this.id);

  final _FakeFirestore _firestore;
  final String _collection;
  @override
  final String id;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    _firestore.reads++;
    if (_firestore.failing) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'szimulált hálózati hiba',
      );
    }
    final exists =
        _collection == 'deleted_user_ids' &&
        _firestore.deletedUids.contains(id);
    return _FakeSnapshot(exists);
  }
}

class _FakeSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeSnapshot(this.exists);

  @override
  final bool exists;
}
