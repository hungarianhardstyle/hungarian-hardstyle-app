/// A **jelentés** (report) mezőinek tiszta összeállítása.
///
/// MIÉRT KÜLÖN FÁJL: a `chat_reports` kollekciót a szerver
/// (`functions/index.js` → `handleChatReportNotification`) **mezőnéven** olvassa
/// (`reporterName`, `reason`), és a biztonsági szabály `postId is string`
/// feltételt kér. A privát chat jelentése ugyanezeket a mezőket írja — így a
/// meglévő admin-értesítés és a meglévő admin-lista **változtatás nélkül**
/// működik. Ez a szerződés itt, egy helyen, tesztelhetően él.
library;

/// A választható indokok **kódjai** (a nyelvfüggetlen, tárolt értékek).
///
/// A megjelenítés fordítja őket (`_reportReasonLabel` az admin-listában); a
/// szerveroldali értesítés a nyers kódot írja ki (`{name}: {reason}`).
const List<String> chatReportReasons = <String>[
  'harassment',
  'hate_speech',
  'spam',
  'other',
];

/// A **rendszer** által írt jelentések indok-kódjai.
///
/// ⚠️ 2026-09-27: a gyermekbiztonsági jelzőrendszer (`functions/child-safety-plan.js`)
/// `systemFlag: true` jelöléssel ír a `chat_reports`-ba, `reason: 'child_safety'`
/// kóddal. Ez **nem** választható indok a felületen (ezért nincs a fenti
/// listában), a megjelenítés viszont ismeri — különben a kódot írná ki nyersen.
const List<String> systemChatReportReasons = <String>['child_safety'];

/// Ismeretlen/üres indokra a semleges `other`.
///
/// ⚠️ A **rendszer**-kódokat (`child_safety`) érintetlenül hagyja: azokat nem a
/// felhasználó választja, ezért nem eshetnek a `other`-be.
String normalizeChatReportReason(String? value) {
  final code = value?.trim().toLowerCase() ?? '';
  if (systemChatReportReasons.contains(code)) return code;
  return chatReportReasons.contains(code) ? code : 'other';
}

/// Az indokok **magyar címkéi** — a felület ezeket fordítja (`AppText`/`tr`),
/// a tárolt érték viszont a fenti kód marad (nyelvfüggetlen).
const Map<String, String> chatReportReasonLabels = <String, String>{
  'harassment': 'Zaklatás',
  'hate_speech': 'Gyűlöletbeszéd',
  'spam': 'Spam',
  'other': 'Egyéb',
  // A rendszer jelzése (nem választható, csak megjelenik az admin-listában).
  'child_safety': 'Gyermekbiztonsági jelzés',
};

/// Egy indok megjelenítendő címkéje (ismeretlen kódra maga a kód).
String chatReportReasonLabel(String? code) {
  final normalized = normalizeChatReportReason(code);
  return chatReportReasonLabels[normalized] ?? normalized;
}

/// A privát beszélgetésből indított jelentés dokumentuma.
///
/// * a `postId` **üres szöveg** — privát beszélgetésnél nincs chat-bejegyzés, a
///   szabály viszont stringet kér; így az admin felület nem próbál nem létező
///   `live_feed_posts` dokumentumot megnyitni, és a „üzenet törlése" művelet sem
///   fut le véletlenül;
/// * az idézet (`reportedText`) **csak akkor** a másik fél üzenete, ha tényleg ő
///   írta az utolsót (`lastSenderId`) — különben üres marad, nem tulajdonítunk
///   neki olyan szöveget, amit nem ő írt;
/// * a `createdAt`-et a hívó teszi bele (`FieldValue.serverTimestamp()`), ezért
///   ez a függvény **időtől független** és összehasonlítható.
Map<String, dynamic> privateChatReportFields({
  required String reporterId,
  required String reporterName,
  required String reportedUserId,
  required String reportedUserName,
  required String reason,
  String conversationId = '',
  String lastSenderId = '',
  String lastMessage = '',
}) {
  final reported = reportedUserId.trim();
  final quoted = lastSenderId.trim() == reported && reported.isNotEmpty
      ? lastMessage.trim()
      : '';
  final conversation = conversationId.trim();
  return <String, dynamic>{
    'postId': '',
    'reporterId': reporterId.trim(),
    'reporterName': reporterName.trim(),
    'reason': normalizeChatReportReason(reason),
    'reportedUserId': reported,
    'reportedUserName': reportedUserName.trim(),
    'reportedText': quoted,
    'source': 'private_chat',
    if (conversation.isNotEmpty) 'conversationId': conversation,
    'status': 'open',
  };
}
