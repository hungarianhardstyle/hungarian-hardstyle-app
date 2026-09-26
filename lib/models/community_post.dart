import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/chat_mention_plan.dart';

class CommunityPost {
  final String id;
  final String authorName;
  final String authorId;
  final bool isAnonymous;
  final String authorImageUrl;
  final String authorRole;
  final String authorAccessRole;
  final String text;
  final String replyToText;
  final String replyToName;

  /// A **hivatkozott** üzenet azonosítója (`replyToId`) — az ugráshoz.
  ///
  /// ⚠️ MIÉRT (a tulajdonos jelzése, 2026-09-26): *„nem azt kértem, hogy egy
  /// ablakot dobjon fel, hanem hogy ugorjon oda a chaten"*. Az ugráshoz a
  /// hivatkozott üzenet azonosítója kell; a **régi** üzeneteknél ez nincs meg
  /// (a mezőt a 365-ös szerver vezette be), ezért ott a tiszta
  /// [chatReplyTargetId] szöveg-egyezéssel keres.
  final String replyToId;
  final String imageUrl;
  final bool pinned;
  final Map<String, int> reactions;

  /// Ki mivel reagált (`{uid: emoji}`) — a szerver írja (`toggleChatReaction`).
  ///
  /// MIÉRT kell a felületnek: a `reactions` csak **darabszám**, abból nem derül
  /// ki, hogy a saját reakciónk ott van-e. A tulajdonos jelzése: *„ha valaki
  /// lájkol egy chat üzenetet, valahogy jelezhetné hogy az adott user lájkolta
  /// mert nem egyértelmű, nevet ne írjon oda, csak lássa hogy már lájkolta"*.
  /// Ebből a térképből **kizárólag a saját** UID-ot olvassuk ki, és **nevet nem
  /// írunk ki** — a felület csak azt jelzi, hogy TE reagáltál.
  final Map<String, String> reactionBy;
  final DateTime createdAt;

  /// A Chat-`@`hivatkozásai (`{type, id, label}`) — a **kattintható** részekhez.
  ///
  /// MIÉRT kell a modellben: a kattintás nem szöveg-parse, hanem a tárolt
  /// **azonosító** alapján megy (uid / WordPress-azonosító), ezért a
  /// megjelenítéshez pontosan ezt a listát kell ismerni. A szerver
  /// (`publishChatPost`) szűri és korlátozza (max. [mentionMaxCount]), a
  /// feldolgozás pedig a tiszta [ChatMentionTarget.listFrom] — a hibás vagy
  /// ismeretlen elemek **kimaradnak**, nem törnek el egy üzenetet.
  final List<ChatMentionTarget> mentions;

  /// Mikor szerkesztette a szerzo (vagy egy admin) az uzenetet.
  ///
  /// `null`, ha az uzenet meg soha nem volt szerkesztve — a felulet ilyenkor
  /// nem irja ki a „szerkesztve" jelzest.
  final DateTime? editedAt;

  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorId,
    required this.isAnonymous,
    required this.authorImageUrl,
    required this.authorRole,
    required this.authorAccessRole,
    required this.text,
    required this.replyToText,
    required this.replyToName,
    this.replyToId = '',
    required this.imageUrl,
    required this.pinned,
    required this.reactions,
    this.reactionBy = const <String, String>{},
    this.mentions = const <ChatMentionTarget>[],
    required this.createdAt,
    this.editedAt,
  });

  factory CommunityPost.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final timestamp = data['createdAt'];
    final edited = data['editedAt'];
    return CommunityPost(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Unknown User',
      isAnonymous:
          data['isAnonymous'] == true ||
          (data['authorName'] as String? ?? '').startsWith('Unknown User '),
      authorImageUrl: data['authorImageUrl'] as String? ?? '',
      authorRole: data['authorRole'] as String? ?? '',
      authorAccessRole: data['authorAccessRole'] as String? ?? '',
      text: data['text'] as String? ?? '',
      replyToText: data['replyToText'] as String? ?? '',
      replyToName: data['replyToName'] as String? ?? '',
      replyToId: data['replyToId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      pinned: data['pinned'] == true,
      reactions: data['reactions'] is Map
          ? (data['reactions'] as Map).map(
              (key, value) =>
                  MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
            )
          : const <String, int>{},
      reactionBy: data['reactionBy'] is Map
          ? (data['reactionBy'] as Map).entries
                .where((entry) => entry.value is String)
                .fold(<String, String>{}, (map, entry) {
                  map[entry.key.toString()] = entry.value as String;
                  return map;
                })
          : const <String, String>{},
      mentions: ChatMentionTarget.listFrom(data['mentions']),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      editedAt: edited is Timestamp ? edited.toDate() : null,
    );
  }

  /// A **saját** reakcióm ezen az üzeneten (`''`, ha nincs ilyen).
  ///
  /// Szándékosan csak a saját UID-ot nézi: a felület nem listáz neveket, csak
  /// azt jelzi, hogy a bejelentkezett felhasználó már reagált.
  String myReaction(String? uid) {
    final key = (uid ?? '').trim();
    if (key.isEmpty) return '';
    return reactionBy[key] ?? '';
  }
}
