import '../models/community_post.dart';

/// A chat-lapozás **tiszta** logikája: nincs benne hálózat és nincs benne
/// Firestore, ezért önmagában tesztelhető.
///
/// **A tulajdonos jelzése:** *„chaten kéne valami limit, hogy pl be töltsön be
/// hetekkel ezelőtti üzenetet, ha valaki vissza akar olvasni legyen valami
/// lehetőség arra hogy lefele scrollozáskor töltsön be mert ha lesz 5 ezer chat
/// bejegyzés ez lassú lehet"*.
///
/// **A mért kiindulás:** a chat már **nem** tölti le az összeset — élőben csak a
/// **legfrissebb 60** üzenetet figyeli (`watchPosts()`). A valódi hiányosság az
/// volt, hogy a 60-nál régebbit **nem lehetett elérni**. Ezért a lista
/// lefelé görgetve (a chat a legfrissebbel kezdődik, tehát lefelé haladunk az
/// időben) 30-asával tölti a régebbieket.
///
/// **Amit ez az osztály eldönt:**
///  * **honnan** folytassuk (`oldestBoundary`) — és a **kitűzött** üzeneteket
///    kihagyjuk, mert azok a lista elejére kerülnek, a koruk viszont régi:
///    ha beszámítanánk, egy hete kitűzött üzenet miatt **átugranánk** a közte
///    lévő beszélgetést;
///  * **hogyan** illesszük be a régebbi lapot úgy, hogy se a legfrissebb
///    ablakkal, se a már betöltött lapokkal **ne duplikálódjon**.
class ChatPaging {
  const ChatPaging._();

  /// A régebbi lap lekérdezésének határa: ennél **régebbi** üzenetek jönnek.
  ///
  /// A kitűzött (pinned) üzeneteket szándékosan kihagyja — lásd a fenti
  /// indoklást. Ha csak kitűzött üzenet van, azok közül a legrégebbit adja.
  static DateTime? oldestBoundary(Iterable<CommunityPost> posts) {
    DateTime? oldest;
    for (final post in posts) {
      if (post.pinned) continue;
      if (oldest == null || post.createdAt.isBefore(oldest)) {
        oldest = post.createdAt;
      }
    }
    if (oldest != null) return oldest;
    for (final post in posts) {
      if (oldest == null || post.createdAt.isBefore(oldest)) {
        oldest = post.createdAt;
      }
    }
    return oldest;
  }

  /// A régebbi lap beillesztése.
  ///
  /// [newest] az élő ablak (a legfrissebb üzenetek), [alreadyOlder] a korábban
  /// már betöltött régebbi lapok, [incoming] az új lap. A visszaadott lista a
  /// **csak új** elemeket tartalmazza, időrendben (legfrissebb elöl), hogy a
  /// hívó egyszerűen a végére fűzhesse.
  static List<CommunityPost> newOlderPosts({
    required Iterable<CommunityPost> incoming,
    required Iterable<CommunityPost> newest,
    required Iterable<CommunityPost> alreadyOlder,
  }) {
    final known = <String>{
      for (final post in newest) post.id,
      for (final post in alreadyOlder) post.id,
    };
    final fresh = <CommunityPost>[];
    for (final post in incoming) {
      if (known.contains(post.id)) continue;
      known.add(post.id);
      fresh.add(post);
    }
    fresh.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return fresh;
  }

  /// Elfogyott-e a régebbi üzenet: ha a kért lapnál kevesebb jött vissza, akkor
  /// nincs több régebbi üzenet.
  static bool reachedStart({required int received, required int pageSize}) =>
      received < pageSize;
}
