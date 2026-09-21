/// A „Megvásárolt zenéim" lejátszójának **tiszta** döntései: ismétlés, keverés,
/// léptetés és a „folytatás ott, ahol abbahagytad" szabályai.
///
/// MIÉRT TISZTA MODUL: a lejátszó hibái **hallhatók** (ismétlés nem ismétel,
/// keverés ugyanazt a számot adja kétszer, a sor végén nem áll meg). Ezeket a
/// lejátszó és a hálózat nélkül kell tudni mérni — ezért az egész döntés itt van,
/// és a képernyő csak végrehajtja.
///
/// NÉGY SZÁNDÉKOS SZABÁLY:
///  1. **Csak letöltött zene játszható** — ez a szabály **nem** változik: a sorrend
///     mindig a letöltött tételek indexeiből áll.
///  2. **A keverés valódi permutáció**: minden letöltött tétel pontosan **egyszer**
///     szerepel (ezt a teszt ellenőrzi, mert a „keverés" leggyakoribb hibája a
///     kihagyás/duplázás).
///  3. **Az aktuális tétel marad az első** keverés bekapcsolásakor — különben a
///     felhasználó egy koppintásra másik zenét hallana, mint amit épp hallgat.
///  4. **A „folytatás" csak akkor ér valamit**, ha érdemi pozícióról van szó:
///     a szám legelején (5 s előtt) és a legvégén (10 s-en belül) nem ajánlunk
///     folytatást, mert az vagy nem látszik, vagy már vége.
library;

import 'dart:math';

/// Ismétlés módja. A sor végén ez dönti el, hogy megállunk-e.
enum PlaybackRepeat {
  /// A sor végén megáll (ez a korábbi viselkedés).
  none,

  /// Egy szám ismétlése (a végén önmaga indul újra).
  one,

  /// Az egész sor ismétlése (a végén az elsőtől folytatja).
  all,
}

/// A [PlaybackRepeat] körbejárása a gomb megnyomásakor: nincs → mind → egy → nincs.
PlaybackRepeat nextPlaybackRepeat(PlaybackRepeat current) {
  switch (current) {
    case PlaybackRepeat.none:
      return PlaybackRepeat.all;
    case PlaybackRepeat.all:
      return PlaybackRepeat.one;
    case PlaybackRepeat.one:
      return PlaybackRepeat.none;
  }
}

/// Rövid felirat a felületre (a gomb tooltipja és a sáv második sora).
String playbackRepeatLabel(PlaybackRepeat repeat) {
  switch (repeat) {
    case PlaybackRepeat.none:
      return 'Ismétlés kikapcsolva';
    case PlaybackRepeat.all:
      return 'Az egész sor ismétlése';
    case PlaybackRepeat.one:
      return 'Ennek a számnak az ismétlése';
  }
}

/// A **lejátszható** tételek indexei a sor eredeti (könyvtár-) sorrendjében.
///
/// Ez a keverés bemenete: a nem letöltött tételek **bekerülni sem tudnak** a
/// lejátszási sorrendbe, mert nem játszhatók.
///
/// Az [excluded] a **lejátszási listáról kivett** tételek (`kiadvány:változat`):
/// ezek **megvannak a készüléken** (nem töröltük őket), de a felhasználó
/// kivette őket a sorból — ezért a lapozás és a lista is átugorja őket.
List<int> downloadedIndices(
  List<String> keys,
  Set<String> downloaded, {
  Set<String> excluded = const {},
}) {
  final indices = <int>[];
  for (var index = 0; index < keys.length; index++) {
    final key = keys[index];
    if (!downloaded.contains(key)) continue;
    if (excluded.contains(key)) continue;
    indices.add(index);
  }
  return indices;
}

/// Fisher–Yates keverés — **permutáció**, nem „válogatás".
///
/// A [random] azért paraméter, hogy a teszt **megismételhető** legyen (és hogy a
/// hívó dönthesse el a magot). A bemenetet nem módosítja.
List<int> shuffledIndices(List<int> indices, Random random) {
  final result = List<int>.of(indices);
  for (var i = result.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final tmp = result[i];
    result[i] = result[j];
    result[j] = tmp;
  }
  return result;
}

/// A lejátszási sorrend: az eredeti sorrend, vagy a kevert sorrend.
///
/// Keverésnél a [currentIndex] (ha van és benne van) **az első helyre** kerül:
/// így a keverés bekapcsolása nem szakítja meg a most hallgatott zenét, és a
/// „következő" gomb onnantól a kevert sorrendet követi.
List<int> playOrderFor({
  required List<int> indices,
  required bool shuffle,
  Random? random,
  int? currentIndex,
}) {
  if (!shuffle) return List<int>.of(indices);
  final shuffled = shuffledIndices(indices, random ?? Random());
  if (currentIndex == null || !shuffled.contains(currentIndex)) return shuffled;
  final result = <int>[currentIndex];
  for (final index in shuffled) {
    if (index != currentIndex) result.add(index);
  }
  return result;
}

/// A **lejátszási lista** indexei a kívánt sorrendben.
///
/// A tulajdonos kérése: *„lehet szerkeszteni a playlistet?"* — ezért a lista
/// **kézzel rendezhető**. A szabály szándékosan egyszerű és kiszámítható:
///
///  1. **Alap:** a letöltött és **nem kivett** tételek a könyvtár sorrendjében.
///  2. **A kézi sorrend elöl megy:** a [customOrder]-ben szereplő tételek abban a
///     sorrendben kerülnek előre — de **csak azok**, amik tényleg a listán vannak
///     (letöltve és nincsenek kivéve). Így egy törölt/kivett tétel nem hagy
///     „lyukat", és nem is tűnik el senki más.
///  3. **Az új tételek a végére kerülnek:** amit a felhasználó még nem rendezett
///     (frissen letöltött), az a **megszokott helyén**, a lista végén jelenik meg
///     — nem kell külön „felvenni".
///  4. **A hibás/duplikált bejegyzést eldobjuk** (a kézi sorrend tárolója
///     elavulhat: elég, ha egy tételt töröltek).
List<int> orderedPlaylistIndices({
  required List<String> keys,
  required Set<String> downloaded,
  Set<String> excluded = const {},
  List<String> customOrder = const [],
}) {
  final indexByKey = <String, int>{};
  for (var index = 0; index < keys.length; index++) {
    // ⚠️ Az ELSŐ előfordulás számít: ismétlődő kulcsnál (elméletben nem fordul
    // elő, de a bemenet jöhet máshonnan) a stabil, kiszámítható választás ez.
    indexByKey.putIfAbsent(keys[index], () => index);
  }
  final playlist = <String>{};
  final libraryOrder = <String>[];
  for (final key in keys) {
    if (!downloaded.contains(key)) continue;
    if (excluded.contains(key)) continue;
    if (playlist.add(key)) libraryOrder.add(key);
  }

  final ordered = <String>[];
  final seen = <String>{};
  for (final key in customOrder) {
    if (!playlist.contains(key)) continue;
    if (!seen.add(key)) continue;
    ordered.add(key);
  }
  for (final key in libraryOrder) {
    if (seen.add(key)) ordered.add(key);
  }
  return [for (final key in ordered) indexByKey[key]!];
}

/// Egy tétel mozgatása a listában ([delta] = `-1` fel, `+1` le).
///
/// Tiszta függvény: a széleken **nem csinál semmit** (nincs körbefordulás, mert
/// az egy listánál meglepő lenne), és a bemenetet nem módosítja.
List<String> moveInOrder(List<String> order, int index, int delta) {
  final result = List<String>.of(order);
  final target = index + delta;
  if (index < 0 || index >= result.length) return result;
  if (target < 0 || target >= result.length) return result;
  final moved = result.removeAt(index);
  result.insert(target, moved);
  return result;
}

/// A **következő** lépés a lejátszási sorrendben (kurzor → kurzor).
///
/// * `cursor < 0` (még nincs kiválasztva) → `0`, ha van egyáltalán tétel;
/// * sor vége: [PlaybackRepeat.all] → `0`, [PlaybackRepeat.one] **automatikus**
///   továbblépésnél → ugyanaz a tétel (újraindul), egyébként `-1` (**megáll**);
/// * a kézi „következő" gomb [PlaybackRepeat.one] mellett is **továbblép** — így
///   nem lehet „beragadni" egy számba, ha a felhasználó tovább akar lépni.
int stepPlayback({
  required int cursor,
  required int length,
  required PlaybackRepeat repeat,
  required bool isAutoAdvance,
}) {
  if (length <= 0) return -1;
  if (cursor < 0) return 0;
  if (isAutoAdvance && repeat == PlaybackRepeat.one) return cursor;
  final next = cursor + 1;
  if (next < length) return next;
  return repeat == PlaybackRepeat.all ? 0 : -1;
}

/// Az **előző** lépés: az első tételnél `-1`, kivéve ha az egész sor ismétlődik.
int previousPlaybackStep({
  required int cursor,
  required int length,
  required PlaybackRepeat repeat,
}) {
  if (length <= 0) return -1;
  if (cursor < 0) return 0;
  final previous = cursor - 1;
  if (previous >= 0) return previous;
  return repeat == PlaybackRepeat.all ? length - 1 : -1;
}

/// Pozíció-felirat a sávra (pl. `3/17`), vagy üres, ha nincs kiválasztott tétel.
String playbackPositionLabel(int cursor, int length) {
  if (cursor < 0 || length <= 0 || cursor >= length) return '';
  return '${cursor + 1}/$length';
}

/// Időpont-felirat (`m:ss`), negatív/érvénytelen értéknél `0:00`.
String playbackClock(int milliseconds) {
  if (milliseconds <= 0) return '0:00';
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Érdemes-e folytatást felajánlani erre a pozícióra?
///
/// Nem ajánlunk: 5 másodperc előtt (gyakorlatilag az elején van), és ha a
/// hátralévő rész **10 másodperc vagy kevesebb** (mindjárt vége). Ismeretlen
/// hossznál (`durationMs <= 0`) csak az alsó határ számít.
bool worthResuming(int positionMs, int durationMs) {
  if (positionMs < 5000) return false;
  if (durationMs > 0 && positionMs >= durationMs - 10000) return false;
  return true;
}
