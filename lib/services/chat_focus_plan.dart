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
