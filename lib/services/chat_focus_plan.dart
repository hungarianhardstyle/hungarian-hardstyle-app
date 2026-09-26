/// A Chat-értesítésre való **odaugrás** tiszta szabályai.
///
/// A tulajdonos kérése (2026-09-24): *„a chatnél meg odaugorhatna arra az
/// üzenetre amit lájkoltak, ha a notifyre nyomok"*.
///
/// MIÉRT külön modul: a chat **ablakos** — a legfrissebb üzenetek élő ablakban
/// vannak (`communityPostsProvider`), a régebbiek pedig lapozva, 30-asával
/// (`_olderPosts`). Az odaugrás ezért nem egy egyszerű `scrollTo`: meg kell
/// keresni az üzenetet az **ismert** listában, és ha nincs meg, **lapozni kell**
/// — de nem a végtelenségig. Ez a döntés itt, hálózat és UI nélkül mérhető.
library;

/// Meddig lapozzunk, hogy megtaláljuk az értesítésben megjelölt üzenetet.
///
/// 10 lap × 30 üzenet = 300 régebbi üzenet. Ez bőven elég arra, hogy egy
/// lájkolt üzenet előkerüljön, ugyanakkor nem indít korlátlan olvasást.
const int chatFocusMaxPages = 10;

/// Az odaugrás állapota.
enum ChatFocusStatus {
  /// Az üzenet megvan a betöltött listában — [ChatFocusPlan.index] a helye.
  found,

  /// Még nincs meg, de van mit betölteni (lapozz tovább).
  keepLoading,

  /// **Az élő ablak még nem érkezett meg** (a stream első képe nincs itt):
  /// ilyenkor nem lapozunk, és **nem fogyasztjuk a lap-keretet** — megvárjuk az
  /// adatot, mert a képernyő a lista megérkezésekor úgyis újraszámolja a tervet.
  ///
  /// ⚠️ MIÉRT KÜLÖN ÁLLAPOT (mért hiba, 2026-09-25): a tulajdonos jelezte, hogy
  /// a chat-értesítés *„néha a megfelelő helyre dob, néha nem"*. A gyökér az
  /// volt, hogy az üres ablak `keepLoading`-ot adott, ezért a képernyő
  /// **lapozásnak számolta** azokat a köröket is, amelyekben nem volt mit
  /// lapozni (a betöltés közbeni képkockák miatt ez másodpercenként többször
  /// lefutott) — így a 10 lapos keret **még az adat megérkezése előtt elfogyott**,
  /// és az odaugrás feladta. Hideg indításnál (amikor a Chat még nem volt nyitva
  /// ebben a munkamenetben) ezért nem ugrott oda, meleg indításnál viszont igen.
  waiting,

  /// Nem érdemes tovább keresni (nincs azonosító, elfogytak az üzenetek,
  /// vagy elértük a lap-korlátot).
  giveUp,
}

/// Az odaugrás terve: megtaláltuk-e, lapozzunk-e tovább, vagy adjuk fel.
class ChatFocusPlan {
  const ChatFocusPlan({required this.status, this.index});

  final ChatFocusStatus status;

  /// A megtalált üzenet indexe a **megjelenített** listában (a legfrissebbel
  /// kezdődik, utána a régebbiek) — csak `found` esetén értelmezett.
  final int? index;

  @override
  String toString() => 'ChatFocusPlan(${status.name}, index: $index)';
}

/// A terv kiszámítása.
///
/// [newestIds] az élő ablak (legfrissebb elöl), [olderIds] a lapozott régebbi
/// üzenetek (szintén a legfrissebbel kezdve), a megjelenített sorrend pedig
/// `newestIds` után `olderIds`.
ChatFocusPlan chatFocusPlan({
  required String focusId,
  required List<String> newestIds,
  required List<String> olderIds,
  required bool reachedStart,
  required int loadedPages,
  int maxPages = chatFocusMaxPages,
}) {
  final id = focusId.trim();
  if (id.isEmpty) return const ChatFocusPlan(status: ChatFocusStatus.giveUp);

  final inNewest = newestIds.indexOf(id);
  if (inNewest >= 0) {
    return ChatFocusPlan(status: ChatFocusStatus.found, index: inNewest);
  }
  final inOlder = olderIds.indexOf(id);
  if (inOlder >= 0) {
    return ChatFocusPlan(
      status: ChatFocusStatus.found,
      index: newestIds.length + inOlder,
    );
  }
  if (reachedStart) return const ChatFocusPlan(status: ChatFocusStatus.giveUp);
  if (loadedPages >= maxPages) {
    return const ChatFocusPlan(status: ChatFocusStatus.giveUp);
  }
  // ⚠️ Az élő ablak még üres: NEM lapozunk és nem fogyasztjuk a keretet. Ez az
  // ág azért van a lap-korlát UTÁN, hogy a korlát akkor is érvényes maradjon,
  // ha az adat soha nem érkezik meg.
  if (newestIds.isEmpty && olderIds.isEmpty) {
    return const ChatFocusPlan(status: ChatFocusStatus.waiting);
  }
  return const ChatFocusPlan(status: ChatFocusStatus.keepLoading);
}

/// Egy válasz-idézet jelöltje: a betöltött üzenet azonosítója, szövege és szerzője.
typedef ChatReplyCandidate = ({String id, String text, String authorName});

/// A válasz-idézet **cél-üzenetének azonosítója** a betöltött listákból.
///
/// ⚠️ MIÉRT (a tulajdonos jelzése, 2026-09-26): az idézetre koppintva eddig egy
/// **ablak** nyílt meg a szöveggel — a tulajdonos viszont ezt kérte: *„nem azt
/// kértem, hogy egy ablakot dobjon fel, hanem hogy ugorjon oda a chaten"*.
///
/// Az ugráshoz a hivatkozott üzenet **azonosítója** kell:
///  * az **új** válaszok hordozzák (`replyToId`, a szerver írja a
///    `publishChatPost`-ban),
///  * a **régi** idézetek viszont csak szöveget és nevet
///    (`replyToText`/`replyToName`) — ezért ott **szöveg-egyezéssel** keressük ki
///    a betöltött üzenetek közül (a tárolt idézet 200 karakterre vágott, ezért a
///    hosszabb eredeti **azzal kezdődik**; fordítva sosem egyezünk).
///
/// A lista a **legfrissebbel kezdődik** (a chat így épül fel), ezért az első
/// egyezés a legvalószínűbb cél. Ha nincs egyezés, `null` — ilyenkor a hívó
/// tovább lapozhat, vagy jelzi, hogy az üzenet nincs a betöltött beszélgetésben.
String? chatReplyTargetId({
  required String replyToId,
  required String replyToText,
  required String replyToName,
  required List<ChatReplyCandidate> messages,
}) {
  final id = replyToId.trim();
  if (id.isNotEmpty && messages.any((message) => message.id == id)) {
    return id;
  }
  final quote = _normalizeChatQuote(replyToText);
  if (quote.isEmpty) return null;
  final name = _normalizeChatQuote(replyToName);
  for (final message in messages) {
    final text = _normalizeChatQuote(message.text);
    if (text.isEmpty) continue;
    if (text != quote && !text.startsWith(quote)) continue;
    if (name.isNotEmpty && _normalizeChatQuote(message.authorName) != name) {
      continue;
    }
    return message.id;
  }
  return null;
}

/// A whitespace összevonása az egyezéshez (a tárolt idézet tördelése eltérhet).
String _normalizeChatQuote(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

/// A cél kártya **becsült** görgetési pozíciója (logikai képpontban).
///
/// ⚠️ MIÉRT KELL (mért hiba, 2026-09-25): a `ListView` **csak a látható**
/// elemeket építi fel, ezért egy mélyen lévő (vagy épp még fel nem épült)
/// megjelölt üzenet kártyájának **nincs kontextusa**, a
/// `Scrollable.ensureVisible` pedig pontosan azt kéri. A korábbi kód ilyenkor a
/// lista **végére** ugrott (`maxScrollExtent`) — az a **legrégebbi** üzeneteket
/// mutatja, nem a megjelöltet, ezért a tulajdonos azt látta, hogy *„régebbi chat
/// üzivel nem megy, újabba igen"* (és a legfrissebbel is csak akkor, ha a kártya
/// már fel volt épülve).
///
/// A híd: a lista **átlagos sormagasságából** becsüljük meg a célt
/// (`maxScrollExtent / (itemCount - 1)`), oda ugrunk, és onnan már pontosít a
/// `ensureVisible`. Több kör is kellhet, mert a `maxScrollExtent` maga is
/// becslés (a Flutter a felépített gyerekekből számolja) — ezért a képernyő
/// legfeljebb néhányszor ismétli.
double chatScrollEstimateForIndex({
  required int index,
  required int itemCount,
  required double maxScrollExtent,
}) {
  if (index <= 0) return 0;
  if (itemCount <= 1) return 0;
  if (!maxScrollExtent.isFinite || maxScrollExtent <= 0) return 0;
  final average = maxScrollExtent / (itemCount - 1);
  final estimate = index * average;
  if (estimate <= 0) return 0;
  return estimate > maxScrollExtent ? maxScrollExtent : estimate;
}
