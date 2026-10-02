/// **A Twitch-stream alatti chat** — a fő chattól KÜLÖN szálon.
///
/// ## Miért külön (a tulajdonos jelzése, 2026-10-02)
///
/// *„+ a twitch oldal alatti chatr ha írok, valamiért a fő chatre is kikerül...”*
///
/// **A mért gyökér:** a Twitch-oldal a **fő chat** widgetjét használta
/// (`LiveFeedScreen`), ezért ugyanabba a `live_feed_posts` gyűjteménybe írt —
/// vagyis a stream alatt írt üzenet **törvényszerűen** megjelent a Chat fülön is.
/// Ez nem hiba volt, hanem a 385-ös döntés („az app saját chatje”) következménye.
///
/// **A megoldás:** a stream alatti chat **saját gyűjteménybe** megy
/// ([twitchChatCollection]), ezért a fő chat tiszta marad. A stream-chat
/// szándékosan **egyszerű**: szöveg, név, kép, időpont — nincs reakció, emoji,
/// hivatkozás, kép-melléklet és **nincs push** (egy stream alatti beszélgetés
/// nem hívhat fel 1000 embert).
///
/// ⚠️ A gyűjtemény szabálya (`firestore.rules` → `match /twitch_chat/...`)
/// **pontosan** ezt a kulcshalmazt engedi, ezért a kimenő mezőket itt, egy
/// helyen építjük ([twitchChatMessagePayload]).
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'community_service.dart';


/// A stream-chat gyűjteménye — **egy helyen** (a szabály, a teszt és a mérés is
/// ezt a nevet használja).
const String twitchChatCollection = 'twitch_chat';

/// A fő chat gyűjteménye — azért van itt, hogy a kettő **szétcsúszását** mérni
/// lehessen (a stream-chat soha nem írhat ide).
const String twitchChatForbiddenCollection = 'live_feed_posts';

/// Az üzenet felső korlátja — **karakterben**, mert a Firestore-szabály is
/// karaktert mér.
///
/// ⚠️ **MÉRT RÉSZLET (2026-10-02, ÉLES próba):** a rules `string.size()` **nem
/// bájtot** számol. A `tmp/verify-twitch-chat-rules.mjs` élesben elküldött egy
/// **300 ékezetes betűs** üzenetet (UTF-8-ban **600 bájt**), és a szabály
/// **átengedte** — a `<= 500` tehát a karakterekre vonatkozik. Ezért a kliens is
/// karaktert mér; a Dart `.length` UTF-16 egységet számol, ami ékezeteknél
/// ugyanaz, emojinál pedig **szigorúbb** a szabálynál — soha nem enged át olyat,
/// amit a szerver elutasítana.
const int twitchChatMaxLength = 500;

/// A megjelenített (legfrissebb) üzenetek száma.
const int twitchChatWindow = 60;

/// A stream-chat egy üzenete.
class TwitchChatMessage {
  const TwitchChatMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorImageUrl,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorImageUrl;
  final String text;
  final DateTime createdAt;

  /// Egy Firestore-dokumentumból — **toleránsan**: a hiányzó vagy hibás típusú
  /// mezők alapértékre esnek, hogy egy régi/hibás sor ne törje el a listát.
  static TwitchChatMessage fromDocument(String id, Map<String, dynamic> data) {
    final rawCreated = data['createdAt'];
    return TwitchChatMessage(
      id: id,
      authorId: '${data['authorId'] ?? ''}',
      authorName: '${data['authorName'] ?? ''}',
      authorImageUrl: '${data['authorImageUrl'] ?? ''}',
      text: '${data['text'] ?? ''}',
      createdAt: rawCreated is Timestamp
          ? rawCreated.toDate()
          : rawCreated is DateTime
              ? rawCreated
              : DateTime.now(),
    );
  }

  /// Firestore-pillanatképből (a `watchMessages` ezt használja).
  static TwitchChatMessage fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      fromDocument(doc.id, doc.data() ?? const <String, dynamic>{});

  /// A megjelenítendő név — üresen „Vendég” (a fő chat is így viselkedik).
  String get displayName => authorName.trim().isEmpty ? 'Vendég' : authorName.trim();
}

/// A kimenő üzenet szövege, vagy `null`, ha nem küldhető el.
///
/// **Tiszta függvény**, ezért teszttel mérhető: levágja a széleket, elutasítja az
/// üreset és a [twitchChatMaxLength]-nél hosszabbat.
String? twitchChatOutgoingText(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (text.length > twitchChatMaxLength) return null;
  return text;
}

/// A kimenő üzenet mezői — **pontosan** az, amit a szabály enged.
Map<String, dynamic> twitchChatMessagePayload({
  required String authorId,
  required String authorName,
  required String authorImageUrl,
  required String text,
}) =>
    <String, dynamic>{
      'authorId': authorId,
      'authorName': authorName.trim().isEmpty ? 'Vendég' : authorName.trim(),
      'authorImageUrl': authorImageUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };

/// A stream-chat műveletei — a felület ezen a határon keresztül szól hozzá,
/// ezért a widget-teszt **hamis átjárót** tud adni (nincs Firestore a tesztben).
abstract class TwitchChatGateway {
  Stream<List<TwitchChatMessage>> watchMessages({int limit = twitchChatWindow});

  Future<void> send(String text);
}

/// A projekt **néves** Firestore-adatbázisa.
///
/// ⚠️ **MÉRT HIBA (2026-10-02, a tulajdonos jelzése):** *„üzenet azért nem
/// küldhető a twitch chates részre mert a stream nem live?”* — **nem** a stream
/// állapota volt az ok: a stream-chat szolgáltatás a **`FirebaseFirestore.instance`**-t
/// használta, ami a **`(default)`** adatbázisra mutat, miközben az app minden más
/// szolgáltatása (és a szerveroldali függvények is) a **`hungarian-hardstyle`**
/// néves adatbázist használja. A `(default)`-ban **nincs** `twitch_chat` szabály,
/// ezért az írás `permission-denied`-del elhalt, az olvasás pedig üres listát adott.
///
/// Ezért itt **egy helyen** dől el az adatbázis, és a teszt megköveteli, hogy
/// minden Firestore-t használó szolgáltatás ezt (vagy a `CommunityService`
/// ugyanilyen konstansát) használja.
FirebaseFirestore huHsFirestore() => FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: CommunityService.firestoreDatabaseId,
    );

/// A valódi (Firestore-alapú) megvalósítás.
class TwitchChatService implements TwitchChatGateway {
  TwitchChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? huHsFirestore(),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// A legfrissebb üzenetek — élőben (a lista a fő chathez hasonlóan a
  /// legfrissebbel kezd, a felület fordítva rajzolja ki).
  @override
  Stream<List<TwitchChatMessage>> watchMessages({int limit = twitchChatWindow}) =>
      _firestore
          .collection(twitchChatCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map(TwitchChatMessage.fromSnapshot)
              .toList(growable: false));

  /// Üzenet küldése. A szerző nevét/avatárját a **saját** profilból olvassuk
  /// (ugyanaz a forrás, mint a fő chatnél), hogy a stream alatt is a valódi név
  /// látszódjon; profil nélkül „Vendég” megy ki.
  @override
  Future<void> send(String text) async {
    final outgoing = twitchChatOutgoingText(text);
    if (outgoing == null) {
      // ⚠️ Fejlesztői hibaág (a felület ezt előre kiszűri) — ezért **angol**:
      // egy magyar szöveg a felületi i18n-kapun akadna el (mért eset: 385).
      throw ArgumentError('twitch chat message is empty or too long');
    }
    final user = await _ensureUser();
    final profile = await _readProfile(user.uid);
    await _firestore.collection(twitchChatCollection).add(
          twitchChatMessagePayload(
            authorId: user.uid,
            authorName: profile.$1,
            authorImageUrl: profile.$2,
            text: outgoing,
          ),
        );
  }

  /// A saját üzenet törlése (elgépelés) — a szabály a szerzőnek is engedi.
  Future<void> deleteOwnMessage(String messageId) =>
      _firestore.collection(twitchChatCollection).doc(messageId).delete();

  Future<User> _ensureUser() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  /// `(displayName, imageUrl)` a `community_profiles/{uid}` sorból.
  Future<(String, String)> _readProfile(String uid) async {
    try {
      final doc = await _firestore.collection('community_profiles').doc(uid).get();
      final data = doc.data() ?? const <String, dynamic>{};
      return (
        '${data['displayName'] ?? ''}'.trim(),
        '${data['imageUrl'] ?? ''}'.trim(),
      );
    } catch (_) {
      // A profil kimaradhat (jogosultság, hálózat) — az üzenet attól mehet.
      return ('', '');
    }
  }
}
