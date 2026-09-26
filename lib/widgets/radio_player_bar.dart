import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/i18n/tr.dart';
import '../services/radio_playback.dart';
import 'app_text.dart';

class RadioPlayerBar extends StatefulWidget {
  const RadioPlayerBar({super.key});

  @override
  State<RadioPlayerBar> createState() => _RadioPlayerBarState();
}

final radioPlayingState = ValueNotifier<bool>(false);
final releasePreviewPlayingState = ValueNotifier<bool>(false);
const _radioStreamUrl = 'https://stream.realhardstyle.nl';

Future<void> stopRadioPlayback() async {
  try {
    await radioPlayback.stop();
  } catch (_) {}
  radioPlayingState.value = false;
}

Future<void> resumeRadioPlayback() async {
  try {
    await radioPlayback.play(_radioStreamUrl);
    radioPlayingState.value = true;
  } catch (_) {}
}

Future<bool> isRadioPlaybackActive() async {
  try {
    return await radioPlayback.isPlaying() ?? radioPlayingState.value;
  } catch (_) {
    return radioPlayingState.value;
  }
}

class _RadioPlayerBarState extends State<RadioPlayerBar> {
  static final _streamUri = Uri.parse('https://stream.realhardstyle.nl');
  String _title = 'Real Hardstyle FM';
  bool _muted = false;
  bool _playing = false;
  bool _toggleBusy = false;
  bool _readingMetadata = false;
  Timer? _metadataTimer;
  VoidCallback? _previewListener;

  @override
  void initState() {
    super.initState();
    _previewListener = () {
      if (releasePreviewPlayingState.value) {
        // Reset the visual state immediately as well as stopping the native
        // player. This prevents a rapid tap from leaving the bar on Stop
        // while a release preview is playing.
        if (mounted && _playing) {
          setState(() {
            _playing = false;
            _title = 'Real Hardstyle FM';
          });
          _stopMetadataRefresh();
        }
        // ReleasePreviewPlayer stops the native radio before it starts the
        // preview. This listener only keeps the visible radio state in sync.
      }
    };
    releasePreviewPlayingState.addListener(_previewListener!);
    radioPlayingState.addListener(_syncExternalRadioState);
    unawaited(_syncPlaying());
  }

  void _syncExternalRadioState() {
    if (!mounted || radioPlayingState.value == _playing) return;
    setState(() {
      _playing = radioPlayingState.value;
      if (!_playing) _title = 'Real Hardstyle FM';
    });
    if (_playing) {
      _startMetadataRefresh();
    } else {
      _stopMetadataRefresh();
    }
  }

  Future<void> _syncPlaying() async {
    try {
      final playing = await radioPlayback.isPlaying() ?? false;
      if (!mounted) return;
      setState(() => _playing = playing);
      radioPlayingState.value = playing;
      if (playing) _startMetadataRefresh();
    } catch (_) {}
  }

  void _startMetadataRefresh() {
    _metadataTimer?.cancel();
    unawaited(_readMetadata());
    _metadataTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_readMetadata()),
    );
  }

  void _stopMetadataRefresh() {
    _metadataTimer?.cancel();
    _metadataTimer = null;
  }

  Future<void> _togglePlay() async {
    if (_toggleBusy || releasePreviewPlayingState.value) return;
    _toggleBusy = true;
    try {
      final isPlaying =
          await radioPlayback.isPlaying() ?? _playing;
      if (isPlaying) {
        // A preview can stop the native player while this widget still has a
        // stale snapshot. If the UI says stopped, clear that stale native
        // state before handling the user's new Play tap.
        if (!_playing) {
          await radioPlayback.stop();
          radioPlayingState.value = false;
        }
        if (!_playing) {
          await radioPlayback.play(_streamUri.toString());
          if (mounted) setState(() => _playing = true);
          radioPlayingState.value = true;
          _startMetadataRefresh();
          return;
        }
        await radioPlayback.stop();
        _stopMetadataRefresh();
        if (mounted) {
          setState(() {
            _playing = false;
            _title = 'Real Hardstyle FM';
          });
        }
        radioPlayingState.value = false;
      } else {
        // The preview may have started while the native radio call was
        // awaiting. Never allow the radio to win that race.
        if (releasePreviewPlayingState.value) return;
        await radioPlayback.play(_streamUri.toString());
        if (releasePreviewPlayingState.value) {
          await stopRadioPlayback();
          return;
        }
        if (mounted) setState(() => _playing = true);
        radioPlayingState.value = true;
        _startMetadataRefresh();
      }
    } catch (_) {
    } finally {
      _toggleBusy = false;
    }
  }

  Future<void> _readMetadata() async {
    if (_readingMetadata || !_playing) return;
    _readingMetadata = true;
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(_streamUri);
      request.headers.set('Icy-MetaData', '1');
      final response = await request.close();
      final interval = int.tryParse(
        response.headers.value('icy-metaint') ?? '',
      );
      if (interval == null) return;
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length >= interval + 1) break;
      }
      if (bytes.length <= interval) return;
      final length = bytes[interval] * 16;
      final metadata = String.fromCharCodes(
        bytes.skip(interval + 1).take(length),
      ).replaceAll('\u0000', '');
      final title = RegExp(r"StreamTitle='([^']*)'")
          .firstMatch(metadata)
          ?.group(1)
          ?.trim();
      if (mounted && title != null && title.isNotEmpty) {
        setState(() => _title = title);
      }
    } catch (_) {
    } finally {
      client?.close(force: true);
      _readingMetadata = false;
    }
  }

  @override
  void dispose() {
    _stopMetadataRefresh();
    if (_previewListener != null) {
      releasePreviewPlayingState.removeListener(_previewListener!);
    }
    radioPlayingState.removeListener(_syncExternalRadioState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ A tulajdonos képernyőképe (2026-09-26): angol módban a rádiósávban
    // „Élő adás" jelent meg. Ez a **ternary-ág** osztály: a felirat nyersen állt,
    // a szótárban sem volt — ezért a megjelenítés helyén fordítjuk, és a
    // fordítás is bekerült.
    final trackTitle = _title == 'Real Hardstyle FM' ? tr(context, 'Élő adás') : _title;
    final compact = MediaQuery.orientationOf(context) == Orientation.landscape;

    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Colors.transparent,
      child: Container(
        height: compact ? 46 : 52,
        margin: EdgeInsets.fromLTRB(compact ? 6 : 10, 3, compact ? 6 : 10, 3),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Tooltip(
              message: _playing ? 'Leállítás' : tr(context, 'Lejátszás'),
              child: Material(
                color: scheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _togglePlay,
                  child: SizedBox.square(
                    dimension: compact ? 34 : 38,
                    child: Icon(
                      _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: compact ? 21 : 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _playing
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: AppText(
                          'REAL HARDSTYLE FM',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trackTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: _muted ? 'Némítás feloldása' : tr(context, 'Némítás'),
              onPressed: () {
                setState(() => _muted = !_muted);
                radioPlayback.setVolume(_muted ? 0.0 : 1.0);
              },
              style: IconButton.styleFrom(
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                shape: const CircleBorder(),
              ),
              icon: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
