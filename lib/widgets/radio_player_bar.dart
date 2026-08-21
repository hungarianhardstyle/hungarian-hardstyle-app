import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RadioPlayerBar extends StatefulWidget {
  const RadioPlayerBar({super.key});

  @override
  State<RadioPlayerBar> createState() => _RadioPlayerBarState();
}

final radioPlayingState = ValueNotifier<bool>(false);
final releasePreviewPlayingState = ValueNotifier<bool>(false);

Future<void> stopRadioPlayback() async {
  try {
    await const MethodChannel('hu_hs/radio').invokeMethod<void>('stop');
  } catch (_) {}
  radioPlayingState.value = false;
}

class _RadioPlayerBarState extends State<RadioPlayerBar> {
  static const _channel = MethodChannel('hu_hs/radio');
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
        unawaited(stopRadioPlayback());
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
      final playing = await _channel.invokeMethod<bool>('isPlaying') ?? false;
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
          await _channel.invokeMethod<bool>('isPlaying') ?? _playing;
      if (isPlaying) {
        // A preview can stop the native player while this widget still has a
        // stale snapshot. If the UI says stopped, clear that stale native
        // state before handling the user's new Play tap.
        if (!_playing) {
          await _channel.invokeMethod<void>('stop');
          radioPlayingState.value = false;
        }
        if (!_playing) {
          await _channel.invokeMethod<void>('play', _streamUri.toString());
          if (mounted) setState(() => _playing = true);
          radioPlayingState.value = true;
          _startMetadataRefresh();
          return;
        }
        await _channel.invokeMethod<void>('stop');
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
        await _channel.invokeMethod<void>('play', _streamUri.toString());
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
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(_streamUri);
      request.headers.set('Icy-MetaData', '1');
      final response = await request.close();
      final interval = int.tryParse(
        response.headers.value('icy-metaint') ?? '',
      );
      if (interval == null) {
        client.close(force: true);
        return;
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length >= interval + 1) break;
      }
      client.close(force: true);
      if (bytes.length <= interval) return;
      final length = bytes[interval] * 16;
      final metadata = String.fromCharCodes(
        bytes.skip(interval + 1).take(length),
      ).replaceAll('\u0000', '');
      final title = RegExp(
        r"StreamTitle='([^']*)'",
      ).firstMatch(metadata)?.group(1)?.trim();
      if (mounted && title != null && title.isNotEmpty) {
        setState(() => _title = title);
      }
    } catch (_) {
    } finally {
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
    final trackTitle = _title == 'Real Hardstyle FM' ? 'Élő adás' : _title;
    final compact = MediaQuery.orientationOf(context) == Orientation.landscape;

    return ColoredBox(
      color: const Color(0xFF111111),
      child: Container(
        height: compact ? 56 : 70,
        margin: EdgeInsets.fromLTRB(compact ? 8 : 12, 4, compact ? 8 : 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7A2929)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Tooltip(
              message: _playing ? 'Leállítás' : 'Lejátszás',
              child: Material(
                color: const Color(0xFFF03A37),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _togglePlay,
                  child: SizedBox.square(
                    dimension: compact ? 36 : 44,
                    child: Icon(
                      _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: compact ? 24 : 30,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                              ? const Color(0xFFF03A37)
                              : Colors.white38,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          'REAL HARDSTYLE FM',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
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
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: _muted ? 'Némítás feloldása' : 'Némítás',
              onPressed: () {
                setState(() => _muted = !_muted);
                _channel.invokeMethod<void>('volume', _muted ? 0.0 : 1.0);
              },
              style: IconButton.styleFrom(
                side: const BorderSide(color: Color(0xFF5A5A5A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
