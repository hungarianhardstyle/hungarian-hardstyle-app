import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/errors/user_facing_error.dart';
import '../../models/label_library.dart';
import '../../models/release.dart';
import '../../providers/community_provider.dart';
import '../../providers/label_library_provider.dart';
import '../../providers/releases_provider.dart';
import '../../services/label_download_manager.dart';
import '../../services/label_library_plan.dart';
import '../../widgets/radio_player_bar.dart';
import '../../widgets/resized_network_image.dart';
import '../releases/releases_screen.dart';

/// „Saját zenéim" — a **megvásárolt** (és reklámmal feloldott) zenék.
///
/// A tulajdonos kérése: *„kéne egy user specifikus menüpont a megvett zenékre,
/// ahol le tudja játszani, ha vége a zenének, ugrik a következőre, le is tudja
/// tölteni újra, úgymond megmarad ott a megvásárolt zenéje"* — kiegészítve:
/// *„tudjon törölni is ha akar, de a letöltési lehetősége maradjon meg"*, és
/// *„ha másik accal lép be, ne látszódjon és letölteni se tudja"*.
///
/// AMI EBBŐL A KÉPERNYŐN KÖVETKEZIK:
///  1. **A lista a szerverről jön** (a hitelesített UID-del szűrve), a letöltött
///     fájlok pedig **fiókonként külön mappában** vannak — ezért más fiók sem
///     listát, sem lejátszható fájlt nem lát.
///  2. **A törlés csak a készülékről töröl**: a vásárlás a szerveren marad,
///     ezért a „Letöltés" gomb **azonnal visszakerül** a törölt tételhez.
///  3. **A szám végén magától a következőre lép**, és ha az még nincs meg,
///     előbb letölti — a sor nem akad meg.
class MyMusicScreen extends ConsumerStatefulWidget {
  const MyMusicScreen({super.key});

  @override
  ConsumerState<MyMusicScreen> createState() => _MyMusicScreenState();
}

class _MyMusicScreenState extends ConsumerState<MyMusicScreen> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;

  final Set<String> _downloaded = <String>{};
  int _currentIndex = -1;
  bool _busy = false;
  bool _resumeRadioAfterStop = false;
  String? _message;
  int _storageBytes = 0;

  /// A legutóbb kiszámolt sor — a `build`-ben **tisztán** áll elő, ezért nem
  /// kell `setState` a számításhoz (az csak a fájlok pásztázásához kell).
  List<LabelQueueEntry> _queue = const [];
  String _queueSignature = '';

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_advance());
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    unawaited(_releaseAudio());
    _player.dispose();
    super.dispose();
  }

  LabelDownloadManager get _downloads => ref.read(labelDownloadManagerProvider);

  Future<String> _urlFor(LabelQueueEntry entry) => ref
      .read(labelLibraryServiceProvider)
      .downloadUrl(releaseId: entry.releaseId, variant: entry.variant);

  /// A meglévő fájlok és a helyfoglalás frissítése (a sor előállítása után).
  Future<void> _scanDownloads() async {
    final queue = _queue;
    Set<String> downloaded;
    var storage = 0;
    try {
      downloaded = await _downloads.downloadedKeys(queue);
      storage = await _downloads.totalBytes();
    } catch (_) {
      // Vendég fióknál (nincs mappa) nincs mit pásztázni — nem hiba.
      downloaded = <String>{};
      storage = 0;
    }
    if (!mounted) return;
    setState(() {
      _downloaded
        ..clear()
        ..addAll(downloaded);
      _storageBytes = storage;
      if (_currentIndex >= queue.length) _currentIndex = -1;
    });
  }

  Future<bool> _ensureDownloaded(LabelQueueEntry entry) async {
    try {
      if (await _downloads.isDownloaded(entry)) {
        if (mounted) setState(() => _downloaded.add(entry.key));
        return true;
      }
      await _downloads.download(entry, urlFor: () => _urlFor(entry));
      if (mounted) {
        setState(() {
          _downloaded.add(entry.key);
          _message = null;
        });
      }
      unawaited(_scanDownloads());
      return true;
    } catch (error) {
      if (mounted) setState(() => _message = userFacingError(error));
      return false;
    }
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final entry = _queue[index];
    setState(() => _currentIndex = index);
    if (!await _ensureDownloaded(entry)) return;
    try {
      // A rádió és a lejátszó ne szóljon egyszerre — ugyanaz a minta, mint a
      // kiadvány-előhallgatónál.
      if (!releasePreviewPlayingState.value) {
        _resumeRadioAfterStop = await isRadioPlaybackActive();
        if (_resumeRadioAfterStop) await stopRadioPlayback();
        if (mounted) releasePreviewPlayingState.value = true;
      }
      final file = await _downloads.fileFor(entry);
      await _player.setFilePath(file.path);
      unawaited(_player.play());
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _message = userFacingError(error));
    }
  }

  /// A szám végén a következőre lép (a sor végén megáll, és visszaadja a rádiót).
  Future<void> _advance() async {
    final next = nextLabelQueueIndex(_currentIndex, _queue.length);
    if (next < 0) {
      await _releaseAudio();
      if (mounted) setState(() => _currentIndex = -1);
      return;
    }
    await _playIndex(next);
  }

  /// Leállás: a rádió visszakapja a hangot, ha előtte az szólt.
  Future<void> _releaseAudio() async {
    await _player.stop();
    releasePreviewPlayingState.value = false;
    if (_resumeRadioAfterStop) {
      _resumeRadioAfterStop = false;
      await resumeRadioPlayback();
    }
  }

  Future<void> _togglePlay() async {
    if (_currentIndex >= 0 && _player.playing) {
      await _player.pause();
    } else if (_currentIndex >= 0 && _player.audioSource != null) {
      unawaited(_player.play());
    } else {
      final start = firstUndownloadedIndex(_queue, _downloaded);
      await _playIndex(start < 0 ? 0 : start);
    }
    if (mounted) setState(() {});
  }

  Future<void> _downloadOnly(LabelQueueEntry entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _ensureDownloaded(entry);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Mégsem'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmDelete(LabelQueueEntry entry) async {
    final ok = await _confirm(
      'Törlés a készülékről',
      'A(z) „${entry.nowPlayingLabel}" letöltött fájlja törlődik. '
          'A vásárlás megmarad, ezért bármikor újra letöltheted.',
      'Törlés',
    );
    if (!ok) return;
    await _downloads.delete(entry);
    if (!mounted) return;
    setState(() {
      _downloaded.remove(entry.key);
      _message = 'Törölve a készülékről — a vásárlás megmaradt.';
      if (_currentIndex >= 0 &&
          _currentIndex < _queue.length &&
          _queue[_currentIndex].key == entry.key) {
        _currentIndex = -1;
      }
    });
    await _scanDownloads();
  }

  Future<void> _deleteAll() async {
    final ok = await _confirm(
      'Letöltött zenék törlése',
      'Minden letöltött fájl törlődik a készülékről. A vásárlásaid '
          'megmaradnak, bármikor újra letölthetők.',
      'Törlés',
    );
    if (!ok) return;
    await _releaseAudio();
    for (final entry in List<LabelQueueEntry>.from(_queue)) {
      await _downloads.delete(entry);
    }
    if (!mounted) return;
    setState(() {
      _downloaded.clear();
      _currentIndex = -1;
      _message = 'A letöltött zenék törölve — a vásárlásaid megmaradtak.';
    });
    await _scanDownloads();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 0.1) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) {
      return const _Scaffold(
        child: _Notice(
          icon: Icons.lock_outline,
          title: 'A zenéidhez jelentkezz be',
          body:
              'A megvásárolt zenék a fiókodhoz tartoznak, ezért csak '
              'bejelentkezve láthatók és tölthetők le.',
        ),
      );
    }

    final library = ref.watch(labelLibraryProvider);
    final releases = ref.watch(releasesProvider((search: '', artistId: 0)));

    return _Scaffold(
      child: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Notice(
          icon: Icons.cloud_off,
          title: 'A zenéid most nem érhetők el',
          body: userFacingError(error),
        ),
        data: (items) => releases.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Notice(
            icon: Icons.cloud_off,
            title: 'A kiadványok most nem érhetők el',
            body: userFacingError(error),
          ),
          data: (catalog) {
            final catalogById = <int, HuhsRelease>{
              for (final release in catalog) release.id: release,
            };
            final queue = buildLabelQueue(items: items, catalog: catalogById);
            final signature = queue.map((entry) => entry.key).join(',');
            if (signature != _queueSignature) {
              _queueSignature = signature;
              _queue = queue;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(_scanDownloads());
              });
            }
            return _buildContent(items);
          },
        ),
      ),
    );
  }

  Widget _buildContent(List<LabelLibraryItem> items) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 40),
          const _Notice(
            icon: Icons.library_music_outlined,
            title: 'Még nincs megvásárolt zenéd',
            body:
                'A Kiadványok fülön megvásárolt (vagy reklámmal feloldott) '
                'zenék itt jelennek meg, és innen játszhatók le.',
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReleasesScreen()),
              ),
              icon: const Icon(Icons.album_outlined),
              label: const Text('Kiadványok böngészése'),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (_message != null) _MessageBanner(message: _message!),
        Row(
          children: [
            Expanded(
              child: Text(
                _storageBytes > 0
                    ? '${items.length} kiadvány · ${_queue.length} tétel · '
                          '${_formatBytes(_storageBytes)} a készüléken'
                    : '${items.length} kiadvány · ${_queue.length} tétel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_storageBytes > 0)
              TextButton.icon(
                onPressed: _deleteAll,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Tárhely ürítése'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_queue.isNotEmpty) _buildPlayerBar(),
        for (final item in items) _buildReleaseCard(item),
      ],
    );
  }

  Widget _buildPlayerBar() {
    final hasCurrent = _currentIndex >= 0 && _currentIndex < _queue.length;
    final entry = hasCurrent ? _queue[_currentIndex] : null;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Előző',
              onPressed: previousLabelQueueIndex(_currentIndex, _queue.length) < 0
                  ? null
                  : () => _playIndex(
                      previousLabelQueueIndex(_currentIndex, _queue.length),
                    ),
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              tooltip: _player.playing ? 'Szünet' : 'Lejátszás',
              onPressed: _togglePlay,
              icon: Icon(
                _player.playing ? Icons.pause_circle : Icons.play_circle,
                size: 34,
              ),
            ),
            IconButton(
              tooltip: 'Következő',
              onPressed: nextLabelQueueIndex(_currentIndex, _queue.length) < 0
                  ? null
                  : () => _playIndex(
                      nextLabelQueueIndex(_currentIndex, _queue.length),
                    ),
              icon: const Icon(Icons.skip_next),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry?.nowPlayingLabel ?? 'Válassz egy zenét',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    hasCurrent
                        ? '${_currentIndex + 1}/${_queue.length}'
                        : 'A megvásárolt zenéid sorban',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseCard(LabelLibraryItem item) {
    final entries = _queue
        .where((entry) => entry.releaseId == item.releaseId)
        .toList(growable: false);
    final first = entries.isEmpty ? null : entries.first;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: first != null && first.coverUrl.isNotEmpty
                        ? ResizedNetworkImage(
                            url: first.coverUrl,
                            physicalWidth: 160,
                          )
                        : const Icon(Icons.album, size: 32),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first?.title ?? 'Kiadvány #${item.releaseId}',
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (first != null && first.artist.isNotEmpty)
                        Text(
                          first.artist,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        item.isAdOnly ? 'Reklámmal feloldva' : 'Megvásárolva',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: item.isAdOnly
                              ? theme.colorScheme.tertiary
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final entry in entries) _buildEntryRow(item, entry),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryRow(LabelLibraryItem item, LabelQueueEntry entry) {
    final downloaded = _downloaded.contains(entry.key);
    final progress = _downloads.progressOf(entry.key);
    final failed = _downloads.hasFailed(entry.key);
    final isCurrent =
        _currentIndex >= 0 &&
        _currentIndex < _queue.length &&
        _queue[_currentIndex].key == entry.key;
    final playing = isCurrent && _player.playing;
    final unlockedOnly = item.unlocked.contains(entry.variant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          IconButton(
            tooltip: playing ? 'Szünet' : 'Lejátszás',
            onPressed: progress != null
                ? null
                : () => isCurrent
                      ? _togglePlay()
                      : _playIndex(_queue.indexOf(entry)),
            icon: Icon(
              progress != null
                  ? Icons.downloading
                  : playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: isCurrent ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.variantLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unlockedOnly) ...[
                      const SizedBox(width: 6),
                      Chip(
                        label: const Text('reklám'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelStyle: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
                Text(
                  progress != null
                      ? 'Letöltés… ${(progress * 100).round()}%'
                      : failed
                      ? 'A letöltés nem sikerült — próbáld újra'
                      : downloaded
                      ? 'Letöltve a készüléken'
                      : 'Nincs letöltve',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: LinearProgressIndicator(value: progress),
                  ),
              ],
            ),
          ),
          if (downloaded && progress == null)
            IconButton(
              tooltip: 'Törlés a készülékről (a vásárlás megmarad)',
              onPressed: () => _confirmDelete(entry),
              icon: const Icon(Icons.delete_outline),
            )
          else if (progress == null)
            IconButton(
              tooltip: 'Letöltés',
              onPressed: () => _downloadOnly(entry),
              icon: const Icon(Icons.download_outlined),
            ),
        ],
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saját zenéim')),
    body: SafeArea(child: child),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 44),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
