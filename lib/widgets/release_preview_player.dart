import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/release.dart';

class ReleasePreviewPlayer extends StatefulWidget {
  final ReleaseTrack track;
  final int index;

  const ReleasePreviewPlayer({
    super.key,
    required this.track,
    required this.index,
  });

  @override
  State<ReleasePreviewPlayer> createState() => _ReleasePreviewPlayerState();
}

class _ReleasePreviewPlayerState extends State<ReleasePreviewPlayer> {
  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    if (widget.track.previewUrl.isNotEmpty) {
      _player.setUrl(widget.track.previewUrl);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.track.previewUrl.isEmpty) {
      return ListTile(
        title: Text('${widget.index + 1}. ${widget.track.title}'),
        subtitle: const Text('Preview még nem érhető el.'),
      );
    }
    return Card(
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final playing = snapshot.data?.playing == true;
          return ListTile(
            leading: IconButton(
              tooltip: playing ? 'Szünet' : 'Preview lejátszása',
              icon: Icon(
                playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: Colors.redAccent,
                size: 34,
              ),
              onPressed: () => playing ? _player.pause() : _player.play(),
            ),
            title: Text('${widget.index + 1}. ${widget.track.title}'),
            subtitle: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, position) => LinearProgressIndicator(
                value: (position.data?.inMilliseconds ?? 0) / 60000,
                minHeight: 4,
              ),
            ),
          );
        },
      ),
    );
  }
}
