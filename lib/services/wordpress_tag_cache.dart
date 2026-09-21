/// A hír-címkék (tag) neveinek gyorsítótára — tiszta, mérhető segédfüggvények.
///
/// **MÉRT OK (a tulajdonos panasza: „Wordpress api lekérős dolgok nagyon lassan
/// töltenek be"):** a WordPress REST minden kérése 0,4–2,0 s
/// időt-az-első-bájtig, a válasz méretétől függetlenül (egy 264 bájtos válasz is
/// 2,2 s volt). A `_hydratePostTags` ezért minden hírlista-, keresés- és
/// cikk-lekérdezéshez hozzátett egy **második** kört, pusztán azért, mert a
/// hír-végpont a címkéket azonosítóként adja vissza.
///
/// A címkenév **nem időfüggő** adat (egy cikk címkéje nem változik percenként),
/// ezért elég egyszer lekérdezni: a mentett választ a kért azonosítók halmaza
/// szerint tároljuk. A kulcs **sorba rendezett**, hogy ugyanaz a halmaz más
/// sorrendben is ugyanazt a kulcsot adja — különben a találat elmaradna, és a
/// felesleges kör visszatérne.
library;

/// A kért címke-azonosítók sorba rendezett, duplikáció nélküli listája.
///
/// Az érvénytelen (0 vagy negatív) azonosítókat kihagyjuk: a WordPress úgysem
/// adna rájuk választ, a kulcs viszont eltérne a valóditól.
List<int> sortedPostTagIds(Iterable<int> ids) =>
    ids.where((id) => id > 0).toSet().toList()..sort();

/// A címke-név gyorsítótár kulcsa a kért azonosítók halmazából.
String postTagCacheKey(Iterable<int> ids) =>
    'huhs.wp.tagnames.v1.${sortedPostTagIds(ids).join(',')}';

/// A lemezre írt alak (`azonosító -> nevek`), String kulcsokkal.
///
/// A kulcs szándékosan String: a `jsonDecode` minden objektum-kulcsot Stringgé
/// alakít, ezért a körút így stabil (nem kell tippelni, mi jön vissza).
Map<String, List<String>> encodePostTagNames(Map<int, List<String>> byId) => {
  for (final entry in byId.entries) '${entry.key}': entry.value,
};

/// A mentett JSON visszaolvasása `azonosító -> nevek` térképpé.
///
/// Az értelmezhetetlen bejegyzéseket **kihagyjuk** (nem tippelünk): egy hibás
/// sor nem eredményezhet rossz címkenevet a felületen.
Map<int, List<String>> decodePostTagNames(Object? stored) {
  if (stored is! Map) return const {};
  final result = <int, List<String>>{};
  stored.forEach((key, value) {
    final id = int.tryParse('$key');
    if (id == null || id <= 0 || value is! List) return;
    final names = value
        .whereType<String>()
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) return;
    result[id] = names;
  });
  return result;
}

/// A `tag_names` beírása a bejegyzésekbe.
///
/// Csak azt írjuk át, amiről **van** név: a hiányzó bejegyzés marad, ahogy a
/// szerver adta — így a hívó a hiba (vagy a részleges válasz) esetén is
/// változatlan listát kap vissza.
List<Map<String, dynamic>> applyPostTagNames(
  List<Map<String, dynamic>> posts,
  Map<int, List<String>> byId,
) {
  int readId(Map<String, dynamic> post) {
    final value = post['id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  return posts
      .map((post) {
        final names = byId[readId(post)];
        return names == null ? post : {...post, 'tag_names': names};
      })
      .toList(growable: false);
}
