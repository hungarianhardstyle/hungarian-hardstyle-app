import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/providers/twitch_chat_provider.dart';
import 'package:hungarian_hardstyle_app/screens/twitch/twitch_chat.dart';
import 'package:hungarian_hardstyle_app/services/twitch_chat.dart';

/// A **stream-chat** (a Twitch-oldal alatti chat) tiszta része és a valódi
/// kirajzolása.
///
/// MIÉRT (a tulajdonos jelzése, 2026-10-02): *„a twitch oldal alatti chatr ha
/// írok, valamiért a fő chatre is kikerül...”* — vagyis a stream alatti üzenet
/// a **fő chat** gyűjteményébe ment. Ez a kör a **külön szálat** méri: a tiszta
/// szöveg-kezelést, a kimenő mezőket, a gyűjtemény nevét, a szabályt — és a
/// widget **valódi kirajzolását** (hamis átjáróval, Firestore nélkül).
void main() {
  group('tiszta: a kimenő szöveg', () {
    test('üres vagy csak szóköz → nem küldhető', () {
      expect(twitchChatOutgoingText(''), isNull);
      expect(twitchChatOutgoingText('   '), isNull);
      expect(twitchChatOutgoingText('\n\t '), isNull);
    });

    test('a széleket levágja', () {
      expect(twitchChatOutgoingText('  szia  '), 'szia');
    });

    test('500 karakternél hosszabb nem küldhető (a szabály így zár)', () {
      final fits = 'a' * twitchChatMaxLength;
      final tooLong = 'a' * (twitchChatMaxLength + 1);
      expect(twitchChatOutgoingText(fits), fits);
      expect(twitchChatOutgoingText(tooLong), isNull);
    });

    test('a korlát KARAKTER, nem bájt — az ékezetes szöveg is belefér', () {
      // ⚠️ ÉLES MÉRÉS (2026-10-02): a rules `string.size()` karaktert számol. A
      // 300 ékezetes betű (UTF-8-ban 600 bájt) **átment** az éles szabályon,
      // ezért a kliens is karaktert mér — a bájt-alapú korlát szükségtelenül
      // elutasította volna a hosszú magyar üzeneteket.
      final accented = 'á' * 300;
      expect(accented.length, 300);
      expect(twitchChatOutgoingText(accented), accented);
      expect(twitchChatOutgoingText('á' * twitchChatMaxLength), isNotNull);
      expect(twitchChatOutgoingText('á' * (twitchChatMaxLength + 1)), isNull);
    });
  });

  group('tiszta: a kimenő mezők', () {
    test('pontosan a szabályban engedett kulcsok mennek ki', () {
      final payload = twitchChatMessagePayload(
        authorId: 'uid-1',
        authorName: 'Teszt Elek',
        authorImageUrl: '',
        text: 'szia',
      );
      expect(payload.keys.toSet(), {
        'authorId',
        'authorName',
        'authorImageUrl',
        'text',
        'createdAt',
      });
      expect(payload['authorId'], 'uid-1');
      expect(payload['text'], 'szia');
      expect(payload['createdAt'], isA<FieldValue>());
    });

    test('üres név helyett „Vendég” megy ki (a szabály megköveteli a nem üres nevet)', () {
      final payload = twitchChatMessagePayload(
        authorId: 'uid-1',
        authorName: '   ',
        authorImageUrl: '',
        text: 'szia',
      );
      expect(payload['authorName'], 'Vendég');
    });
  });

  group('tiszta: az üzenet olvasása', () {
    test('a dokumentumból minden mezőt kiolvas', () {
      final created = DateTime(2026, 10, 2, 20, 15);
      final message = TwitchChatMessage.fromDocument('m1', {
        'authorId': 'uid-1',
        'authorName': 'Teszt Elek',
        'authorImageUrl': 'https://res.cloudinary.com/fjxo93em/image/upload/a.jpg',
        'text': 'hajrá!',
        'createdAt': Timestamp.fromDate(created),
      });
      expect(message.id, 'm1');
      expect(message.authorName, 'Teszt Elek');
      expect(message.text, 'hajrá!');
      expect(message.createdAt, created);
      expect(message.displayName, 'Teszt Elek');
    });

    test('a hiányos sor nem töri el a listát', () {
      final message = TwitchChatMessage.fromDocument('m2', const {});
      expect(message.authorName, '');
      expect(message.text, '');
      expect(message.displayName, 'Vendég');
      expect(message.createdAt, isA<DateTime>());
    });
  });

  group('a gyűjtemény KÜLÖN szál (ez a lényegi ígéret)', () {
    test('a stream-chat gyűjteménye nem a fő chat gyűjteménye', () {
      expect(twitchChatCollection, 'twitch_chat');
      expect(twitchChatCollection, isNot(twitchChatForbiddenCollection));
      expect(twitchChatForbiddenCollection, 'live_feed_posts');
    });

    test('FORRÁS-LINT: a szolgáltatás nem ír a fő chatbe, és élőben, fordítva olvas', () {
      final source = File('lib/services/twitch_chat.dart').readAsStringSync();
      expect(source.contains("collection(twitchChatCollection)"), isTrue);
      expect(source.contains("collection('live_feed_posts')"), isFalse,
          reason: 'a stream-chat a fő chat gyűjteményébe írna');
      expect(source.contains("orderBy('createdAt', descending: true)"), isTrue);
      expect(source.contains('.limit(limit)'), isTrue);
      expect(source.contains('signInAnonymously'), isTrue,
          reason: 'vendégként nem lehetne írni');
      expect(source.contains("collection('community_profiles')"), isTrue,
          reason: 'a név/avatár a profilból jön');
    });

    test('FORRÁS-LINT: a Twitch-oldal a stream-chatet használja, nem a fő chatet', () {
      final screen = File('lib/screens/twitch/twitch_screen.dart').readAsStringSync();
      expect(screen.contains('chat: const TwitchStreamChat()'), isTrue);
      expect(screen.contains('LiveFeedScreen'), isFalse,
          reason: 'ez volt a hiba: a Twitch-oldal a fő chat widgetjét használta');
      expect(screen.contains("import '../community/community_screen.dart';"), isFalse,
          reason: 'a fő chat importja sem maradhat bent');
    });

    test('FORRÁS-LINT: a Firestore-szabály tartalmazza a külön gyűjteményt', () {
      final rules = File('firestore.rules').readAsStringSync();
      final start = rules.indexOf('match /twitch_chat/');
      expect(start, greaterThan(0), reason: 'nincs szabály a stream-chatre');
      final block = rules.substring(start, rules.indexOf('match /community_profiles/', start));
      expect(block.contains('allow read: if true;'), isTrue);
      expect(block.contains('allow create: if request.auth != null'), isTrue);
      expect(block.contains("'authorId', 'authorName', 'authorImageUrl', 'text', 'createdAt'"),
          isTrue);
      expect(block.contains('request.resource.data.authorId == request.auth.uid'), isTrue);
      // ⚠️ MÉRT SAJÁT HIBA (a mutációs bizonyíték fogta el): a `contains('… <= 500')`
      // minta a **fellazított** `<= 5000`-re is illeszkedett (a rövidebb szöveg a
      // hosszabb eleje), ezért a kapu zölden átengedte a mutációt. Mostantól a
      // minta **számszerűen** zár: a `500` után nem állhat számjegy.
      final limitPattern = RegExp(r'request\.resource\.data\.text\.size\(\) <= 500(?![0-9])');
      expect(limitPattern.hasMatch(block), isTrue,
          reason: 'a szabály ne engedjen 500 bájtnál hosszabb üzenetet');
      expect(block.contains('<= 5000'), isFalse);
      expect(block.contains('allow update: if false;'), isTrue);
      expect(block.contains('request.auth.uid == resource.data.authorId'), isTrue,
          reason: 'a szerző a saját üzenetét törölhesse');
    });
  });

  group('a widget valódi kirajzolása (hamis átjáróval)', () {
    testWidgets('az üzenetek megjelennek (név + szöveg)', (tester) async {
      final gateway = _FakeGateway([
        TwitchChatMessage(
          id: 'm1',
          authorId: 'uid-1',
          authorName: 'Teszt Elek',
          authorImageUrl: '',
          text: 'szia stream!',
          createdAt: DateTime(2026, 10, 2, 20, 15),
        ),
      ]);
      await tester.pumpWidget(_wrap(gateway));
      await tester.pumpAndSettle();

      expect(find.text('Teszt Elek'), findsOneWidget);
      expect(find.text('szia stream!'), findsOneWidget);
      expect(find.text('20:15'), findsOneWidget);
      // A fejléc kimondja, hogy ez külön szál (a tulajdonos jelzésére).
      expect(find.text('Stream-chat'), findsOneWidget);
      expect(find.text('külön szál — a fő chat nem kapja meg'), findsOneWidget);
    });

    testWidgets('üres szálnál semmi nem látszik, csak a felhívás', (tester) async {
      await tester.pumpWidget(_wrap(_FakeGateway(const [])));
      await tester.pumpAndSettle();

      expect(find.text('Még nincs üzenet a stream alatt — írj te először!'), findsOneWidget);
    });

    testWidgets('a „Küldés” átadja a szöveget az átjárónak, és üríti a mezőt', (tester) async {
      final gateway = _FakeGateway(const []);
      await tester.pumpWidget(_wrap(gateway));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  hajrá HUHS  ');
      await tester.tap(find.text('Küldés'));
      await tester.pumpAndSettle();

      expect(gateway.sent, ['hajrá HUHS'], reason: 'a széleket levágva küldi');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    });

    testWidgets('üres mezővel nem küld, hanem szól', (tester) async {
      final gateway = _FakeGateway(const []);
      await tester.pumpWidget(_wrap(gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Küldés'));
      await tester.pumpAndSettle();

      expect(gateway.sent, isEmpty);
      expect(find.text('Írj egy rövid üzenetet (legfeljebb 500 karakter).'), findsOneWidget);
    });

    testWidgets('hiba esetén megmondja, hogy nem ment el', (tester) async {
      final gateway = _FakeGateway(const [], failOnSend: true);
      await tester.pumpWidget(_wrap(gateway));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'szia');
      await tester.tap(find.text('Küldés'));
      await tester.pumpAndSettle();

      expect(find.text('Az üzenet nem ment el. Próbáld újra.'), findsOneWidget);
    });
  });
}

Widget _wrap(TwitchChatGateway gateway) => ProviderScope(
      overrides: [twitchChatServiceProvider.overrideWithValue(gateway)],
      child: const MaterialApp(
        home: Scaffold(body: TwitchStreamChat()),
      ),
    );

/// Hamis átjáró — **nincs Firestore** a tesztben.
class _FakeGateway implements TwitchChatGateway {
  _FakeGateway(this.messages, {this.failOnSend = false});

  final List<TwitchChatMessage> messages;
  final bool failOnSend;
  final List<String> sent = <String>[];

  @override
  Stream<List<TwitchChatMessage>> watchMessages({int limit = twitchChatWindow}) =>
      Stream<List<TwitchChatMessage>>.value(messages);

  @override
  Future<void> send(String text) async {
    if (failOnSend) throw StateError('nincs hálózat');
    sent.add(text);
    // A valódi út a Firestore-írás után az élő streamből rajzol — a teszt nem
    // vár listafrissítésre, ezért itt nem adunk vissza új üzenetet.
  }
}
