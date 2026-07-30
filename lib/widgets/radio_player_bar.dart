import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RadioPlayerBar extends StatefulWidget {
  const RadioPlayerBar({super.key});

  @override
  State<RadioPlayerBar> createState() => _RadioPlayerBarState();
}

class _RadioPlayerBarState extends State<RadioPlayerBar> {
  static const _channel = MethodChannel('hu_hs/radio');
  static final _streamUri = Uri.parse('https://stream.realhardstyle.nl');
  String _title = 'Real Hardstyle FM';
  bool _muted = false;
  bool _playing = false;
  bool _readingMetadata = false;
  Timer? _metadataTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_syncPlaying());
  }

  Future<void> _syncPlaying() async {
    try {
      final playing = await _channel.invokeMethod<bool>('isPlaying') ?? false;
      if (!mounted) return;
      setState(() => _playing = playing);
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
    try {
      final isPlaying =
          await _channel.invokeMethod<bool>('isPlaying') ?? _playing;
      if (isPlaying) {
        await _channel.invokeMethod<void>('stop');
        _stopMetadataRefresh();
        if (mounted) {
          setState(() {
            _playing = false;
            _title = 'Real Hardstyle FM';
          });
        }
      } else {
        await _channel.invokeMethod<void>('play', _streamUri.toString());
        if (mounted) setState(() => _playing = true);
        _startMetadataRefresh();
      }
    } catch (_) {}
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackTitle = _title == 'Real Hardstyle FM' ? 'Élő adás' : _title;

    return ColoredBox(
      color: const Color(0xFF111111),
      child: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
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
                    dimension: 44,
                    child: Icon(
                      _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 30,
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
