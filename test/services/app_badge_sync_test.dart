// A Firestore/Auth osztalyok `sealed`-ek, ezert az `implements` jelzest a lint
// kifogasolja. Itt SZANDEKOS: a lehető legkisebb felületet utánozzuk.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/app_notification.dart';
import 'package:hungarian_hardstyle_app/services/app_badge_sync.dart';
import 'package:hungarian_hardstyle_app/services/notification_service.dart';

/// Az **app-ikon jelvénye**: az olvasatlan értesítések száma.
///
/// A tulajdonos kérése: *„Az app ikon jelezze mennyi notifyd meg pushod van,
/// olvasatlan, egybe számolva"*.
///
/// A lényeg, amit itt mérünk: a jelvény az **olvasatlan** bejegyzések számát
/// kapja; a már olvasott és az archivált nem számít; csak **változáskor** hívjuk
/// a jelvény-API-t; 0-nál is frissítünk (eltűnik a jelvény); és egy hiba nem
/// állítja meg a figyelést.
void main() {
  late StreamController<List<AppNotification>> controller;
  late List<int> applied;

  setUp(() {
    controller = StreamController<List<AppNotification>>.broadcast();
    applied = [];
  });

  tearDown(() async {
    await controller.close();
  });

  AppBadgeSync build() => AppBadgeSync(
    notifications: _FakeNotificationService(controller.stream),
    setBadge: (value) async => applied.add(value),
  );

  test('az olvasatlanok számát küldi ki', () async {
    final sync = build();
    controller.add([
      _notification('a', read: false),
      _notification('b', read: false),
      _notification('c', read: true),
      _notification('d', read: false, archived: true),
    ]);
    await pumpEventQueue();

    expect(applied, [2], reason: 'olvasott és archivált nem számít');
    sync.dispose();
  });

  test('csak VÁLTOZÁSKOR hívja a jelvényt (nem minden képnél)', () async {
    final sync = build();
    controller.add([_notification('a', read: false), _notification('b', read: false)]);
    await pumpEventQueue();
    controller.add([_notification('a', read: false), _notification('b', read: false)]);
    await pumpEventQueue();
    controller.add([_notification('a', read: false), _notification('b', read: false)]);
    await pumpEventQueue();

    expect(applied, [2], reason: 'három azonos kép = egyetlen jelvény-hívás');
    sync.dispose();
  });

  test('olvasatlanná váláskor nő, elolvasáskor csökken', () async {
    final sync = build();
    controller.add([_notification('a', read: false)]);
    await pumpEventQueue();
    controller.add([_notification('a', read: false), _notification('b', read: false)]);
    await pumpEventQueue();
    controller.add([_notification('a', read: true), _notification('b', read: false)]);
    await pumpEventQueue();

    expect(applied, [1, 2, 1]);
    sync.dispose();
  });

  test('ha mindent elolvastak, 0-t küld (eltűnik a jelvény)', () async {
    final sync = build();
    controller.add([_notification('a', read: false)]);
    await pumpEventQueue();
    controller.add([_notification('a', read: true)]);
    await pumpEventQueue();

    expect(applied, [1, 0]);
    sync.dispose();
  });

  test('a jelvény hibája nem állítja meg a figyelést', () async {
    var calls = 0;
    final sync = AppBadgeSync(
      notifications: _FakeNotificationService(controller.stream),
      setBadge: (value) async {
        calls += 1;
        if (calls == 1) throw StateError('launcher hiba');
      },
    );

    controller.add([_notification('a', read: false)]);
    await pumpEventQueue();
    controller.add([_notification('a', read: false), _notification('b', read: false)]);
    await pumpEventQueue();

    expect(calls, 2, reason: 'a hiba után is frissül a jelvény');
    sync.dispose();
  });

  test('a stream hibája nem dob a felületre', () async {
    final sync = build();
    controller.addError(StateError('nincs hálózat'));
    await pumpEventQueue();
    controller.add([_notification('a', read: false)]);
    await pumpEventQueue();

    expect(applied, [1], reason: 'a hiba után is működik');
    sync.dispose();
  });

  test('a dispose után nem frissül a jelvény', () async {
    final sync = build();
    controller.add([_notification('a', read: false)]);
    await pumpEventQueue();
    sync.dispose();
    controller.add([_notification('a', read: false), _notification('b', read: false)]);
    await pumpEventQueue();

    expect(applied, [1]);
  });
}

AppNotification _notification(
  String id, {
  required bool read,
  bool archived = false,
}) {
  final now = DateTime(2026, 9, 20, 12);
  return AppNotification(
    id: id,
    type: 'chat_reaction',
    title: 'Cím',
    body: 'Szöveg',
    targetType: 'chat',
    targetId: 'post-1',
    createdAt: now,
    readAt: read ? now : null,
    archivedAt: archived ? now : null,
  );
}

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService(this._stream)
    : super(auth: _FakeAuth(), firestore: _FakeFirestore());

  final Stream<List<AppNotification>> _stream;

  @override
  Stream<List<AppNotification>> watchNotifications({
    int limit = 50,
    bool includeArchived = false,
  }) => _stream;
}

class _FakeAuth extends Fake implements FirebaseAuth {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}
