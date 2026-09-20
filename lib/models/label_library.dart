/// A „Saját zenéim" könyvtár adatai.
///
/// A tulajdonos kérése: *„kéne egy user specifikus menüpont a megvett zenékre,
/// ahol le tudja játszani, ha vége a zenének, ugrik a következőre, le is tudja
/// tölteni újra, úgymond megmarad ott a megvásárolt zenéje"*.
///
/// A SZERVER ADJA A TÉNYT, A KLIENS A NEVET: a `getMyLabelLibrary` végpont
/// **csak** a birtokolt kiadvány-azonosítókat és változatokat adja vissza (ez a
/// biztos adat), a cím/borító/előadó a **kiadvány-katalógusból** jön, ami az
/// appban már gyorsítótárból megvan. Így egy elavult másolat nem tud
/// ellentmondani a valódi kiadványnak, és a végpont válasza kicsi marad.
library;

/// Egy kiadvány a felhasználó könyvtárában.
class LabelLibraryItem {
  const LabelLibraryItem({
    required this.releaseId,
    required this.purchased,
    required this.unlocked,
    required this.variants,
  });

  /// A WordPress-kiadvány azonosítója.
  final int releaseId;

  /// Megvásárolt változatok (Play-termékkel ellenőrizve).
  final List<String> purchased;

  /// Reklámmal feloldott változatok (nem vásárlás — a felület jelöli).
  final List<String> unlocked;

  /// A két lista együtt, a felületi sorrendben (ez a lejátszási sorrend is).
  final List<String> variants;

  bool get isPurchased => purchased.isNotEmpty;

  /// Igaz, ha MINDEN változata reklámmal nyílt meg (tehát egyért sem fizetett).
  bool get isAdOnly => purchased.isEmpty && unlocked.isNotEmpty;

  bool owns(String variant) => variants.contains(variant);

  factory LabelLibraryItem.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value
              .whereType<String>()
              .map((entry) => entry.trim())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false)
        : const [];
    final purchased = strings(json['purchased']);
    final unlocked = strings(json['unlocked']);
    final variants = strings(json['variants']);
    return LabelLibraryItem(
      releaseId: _readInt(json['releaseId']),
      purchased: purchased,
      unlocked: unlocked,
      variants: variants.isEmpty ? [...purchased, ...unlocked] : variants,
    );
  }

  Map<String, dynamic> toJson() => {
    'releaseId': releaseId,
    'purchased': purchased,
    'unlocked': unlocked,
    'variants': variants,
  };
}

/// Egy lejátszható tétel: **egy birtokolt változat egy kiadványból**.
///
/// A letöltés is ezen a szinten történik (a fájl egy változat), ezért a
/// lejátszási sor és a letöltési lista **ugyanaz** a lista.
class LabelQueueEntry {
  const LabelQueueEntry({
    required this.releaseId,
    required this.variant,
    required this.title,
    required this.artist,
    required this.coverUrl,
  });

  final int releaseId;
  final String variant;
  final String title;
  final String artist;
  final String coverUrl;

  /// A letöltött fájl neve — ebből derül ki, hogy megvan-e már.
  String get key => '$releaseId:$variant';

  String get variantLabel => labelVariantLabel(variant);

  String get fileName => labelFileName(releaseId, variant);

  /// Amit a lejátszóban kiírunk (a változat is, mert egy kiadványnak több
  /// változata is lehet a birtokában).
  String get nowPlayingLabel =>
      variantLabel.isEmpty ? title : '$title — $variantLabel';
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}'.trim()) ?? 0;
}

/// A változat emberi neve (a Play-termék utótagjából).
String labelVariantLabel(String variant) => switch (variant) {
  'radio_wav' => 'Radio (WAV)',
  'radio_mp3_320' => 'Radio (MP3 320)',
  'extended_wav' => 'Extended (WAV)',
  'extended_mp3_320' => 'Extended (MP3 320)',
  'wav' => 'WAV',
  'mp3_320' => 'MP3 320',
  'mp3_128' => 'MP3 128',
  'mp3_96' => 'MP3 96',
  'free_wav' => 'WAV (ingyenes)',
  _ => variant,
};

/// A fájl kiterjesztése a változatból. Ismeretlen változatnál `bin`, hogy a
/// lejátszó ne próbáljon tippelni a formátumra.
String labelVariantExtension(String variant) {
  if (variant.contains('wav')) return 'wav';
  if (variant.contains('mp3')) return 'mp3';
  return 'bin';
}

/// A letöltött fájl neve. A kiadvány-azonosító és a változat együtt egyedi,
/// ezért nem kell külön nyilvántartás a fájlokról.
String labelFileName(int releaseId, String variant) =>
    'huhs_${releaseId}_$variant.${labelVariantExtension(variant)}';
