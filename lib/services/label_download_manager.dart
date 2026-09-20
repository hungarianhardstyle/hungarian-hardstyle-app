import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/label_library.dart';

/// A letöltött fájl helye és állapota — a felület ezt rajzolja ki.
enum LabelDownloadState { missing, downloading, ready, failed }

/// A megvásárolt zene **helyi** tárolása.
///
/// A tulajdonos kérése: *„le is tudja tölteni újra, úgymond megmarad ott a
/// megvásárolt zenéje"*, *„tudjon törölni is ha akar, de a letöltési lehetősége
/// maradjon meg"*, és a legfontosabb: *„ha másik accal lép be, ne látszódjon és
/// letölteni se tudja"*.
///
/// EZÉRT A TÁROLÓ **FIÓKONKÉNT KÜLÖN MAPPA**: `label_music/<uid>/`. Enélkül a
/// készüléken maradt fájl **másik fióknak is látszana** (a fájl létezése lenne a
/// „megvan" jelzés), és le is tudná játszani — pedig nem az övé. A szerver persze
/// a letöltést is megtagadja (`label_entitlements` a hitelesített uid-del), de a
/// helyi fájlt az nem érinti: **a szétválasztás itt, a fájlrendszerben dől el**.
///
/// NÉGY SZÁNDÉKOS DÖNTÉS:
///  1. **Fiókonként külön mappa**, és a fiók nélküli (vendég) állapotban **nincs
///     letöltés** — a vásárlás bejelentkezéshez kötött.
///  2. **A link 5 percig él**, egy nagy WAV letöltése viszont tovább tarthat.
///     Ezért egy **hiba után egyszer új linkkel** próbálkozunk.
///  3. **Fájlnév = kiadvány + változat**, ezért nincs külön nyilvántartás: a
///     fájl létezése **maga** a tény.
///  4. **Letöltés közben nem írjuk felül a kész fájlt**: először egy `.part`
///     fájlba megy, és csak siker esetén nevezzük át.
class LabelDownloadManager {
  LabelDownloadManager({
    required this.uid,
    Future<Directory> Function()? directoryProvider,
    Future<void> Function(
      String url,
      String path, {
      void Function(int received, int total)? onProgress,
    })?
    downloader,
    Dio? dio,
  }) : // A privát mezőhöz nem lehet `this._x` nevű NÉVES paramétert adni (a Dart
       // nem engedi az aláhúzással kezdődő named paramétert), ezért itt
       // szándékos a kézi hozzárendelés.
       // ignore: prefer_initializing_formals
       _directoryProvider = directoryProvider,
       // ignore: prefer_initializing_formals
       _downloader = downloader,
       _dio = dio ?? Dio();

  /// A bejelentkezett felhasználó azonosítója. Üresen (vendég) nincs letöltés.
  final String uid;

  final Future<Directory> Function()? _directoryProvider;
  final Future<void> Function(
    String url,
    String path, {
    void Function(int received, int total)? onProgress,
  })?
  _downloader;
  final Dio _dio;

  final Map<String, double> _progress = {};
  final Set<String> _failed = {};
  final Map<String, Future<File>> _inFlight = {};

  /// 0.0–1.0 közötti folyamat, vagy `null`, ha épp nem töltünk le semmit.
  double? progressOf(String key) => _progress[key];

  bool hasFailed(String key) => _failed.contains(key);

  /// A fiók saját mappája. A mappanév a **fiókhoz** kötött, ezért a másik
  /// fiók listája (és a „megvan?" kérdés) **nem láthatja** ezeket a fájlokat.
  Future<Directory> _labelDirectory() async {
    if (uid.trim().isEmpty) {
      throw StateError('A zenék letöltéséhez be kell jelentkezni.');
    }
    // Firebase-uid: betű/szám. A biztonság kedvéért minden elválasztót kiszűrünk,
    // hogy egy hibás azonosító se tudjon kilépni a saját mappájából.
    final safeUid = uid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final provider = _directoryProvider;
    final base = provider != null
        ? await provider()
        : await getApplicationSupportDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}label_music'
      '${Platform.pathSeparator}$safeUid',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> fileFor(LabelQueueEntry entry) async {
    final directory = await _labelDirectory();
    return File('${directory.path}${Platform.pathSeparator}${entry.fileName}');
  }

  Future<bool> isDownloaded(LabelQueueEntry entry) async {
    final file = await fileFor(entry);
    return file.exists();
  }

  /// A meglevő tételek kulcsai — ebből tudja a sor, honnan induljon.
  Future<Set<String>> downloadedKeys(Iterable<LabelQueueEntry> entries) async {
    final present = <String>{};
    for (final entry in entries) {
      if (await isDownloaded(entry)) present.add(entry.key);
    }
    return present;
  }

  /// A helyi fájlok összmérete bájtban (a felület „ennyi helyet foglal" sora).
  Future<int> totalBytes() async {
    final directory = await _labelDirectory();
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Letölti a tételt, és visszaadja a kész fájlt.
  ///
  /// [urlFor] minden próbálkozásnál **friss** aláírt linket ad (a link 5 percig
  /// él, ezért nem szabad eltárolni).
  Future<File> download(
    LabelQueueEntry entry, {
    required Future<String> Function() urlFor,
  }) {
    final existing = _inFlight[entry.key];
    if (existing != null) return existing;
    final future = _download(entry, urlFor: urlFor).whenComplete(() {
      _inFlight.remove(entry.key);
    });
    _inFlight[entry.key] = future;
    return future;
  }

  Future<File> _download(
    LabelQueueEntry entry, {
    required Future<String> Function() urlFor,
  }) async {
    final file = await fileFor(entry);
    final part = File('${file.path}.part');
    _failed.remove(entry.key);
    _progress[entry.key] = 0;
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final url = await urlFor();
          if (url.trim().isEmpty) {
            throw StateError('Üres letöltési hivatkozás.');
          }
          await _run(url, part.path, entry.key);
          if (await file.exists()) await file.delete();
          await part.rename(file.path);
          _progress.remove(entry.key);
          return file;
        } catch (error) {
          if (await part.exists()) {
            await part.delete().catchError((_) => part);
          }
          // Az ELSŐ hiba lehet lejárt link: új linkkel még egyszer próbáljuk.
          if (attempt == 1) rethrow;
        }
      }
      throw StateError('A letöltés nem sikerült.');
    } catch (_) {
      _progress.remove(entry.key);
      _failed.add(entry.key);
      rethrow;
    }
  }

  Future<void> _run(String url, String path, String key) {
    final custom = _downloader;
    void onProgress(int received, int total) {
      if (total > 0) _progress[key] = (received / total).clamp(0, 1).toDouble();
    }

    if (custom != null) {
      return custom(url, path, onProgress: onProgress);
    }
    return _dio.download(
      url,
      path,
      onReceiveProgress: onProgress,
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// Egy tétel törlése a készülékről (a vásárlás természetesen megmarad).
  Future<void> delete(LabelQueueEntry entry) async {
    final file = await fileFor(entry);
    if (await file.exists()) await file.delete();
    final part = File('${file.path}.part');
    if (await part.exists()) await part.delete();
    _progress.remove(entry.key);
    _failed.remove(entry.key);
  }
}
