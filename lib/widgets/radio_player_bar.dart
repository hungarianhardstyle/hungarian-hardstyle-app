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

  Future<void> _togglePlay() async {
    try {
      if (_playing) {
        await _channel.invokeMethod<void>('stop');
      } else {
        await _channel.invokeMethod<void>('play', _streamUri.toString());
        unawaited(_readMetadata());
      }
      if (mounted) setState(() => _playing = !_playing);
    } catch (_) {}
  }

  Future<void> _readMetadata() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(_streamUri);
      request.headers.set('Icy-MetaData', '1');
      final response = await request.close();
      final interval = int.tryParse(response.headers.value('icy-metaint') ?? '');
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
      final title = RegExp(r"StreamTitle='([^']*)'")
          .firstMatch(metadata)
          ?.group(1)
          ?.trim();
      if (mounted && title != null && title.isNotEmpty) {
        setState(() => _title = title);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF171717),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: _playing ? 'Leállítás' : 'Lejátszás',
            onPressed: _togglePlay,
            icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
            color: const Color(0xFFE53935),
          ),
          Expanded(
            child: Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: _muted ? 'Némítás feloldása' : 'Némítás',
            onPressed: () {
              setState(() => _muted = !_muted);
              _channel.invokeMethod<void>('volume', _muted ? 0.0 : 1.0);
            },
            icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
          ),
        ],
      ),
    );
  }
}
