import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/release.dart';
import 'radio_player_bar.dart';

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

class _ReleasePreviewPlayerState extends State<ReleasePreviewPlayer>
    with AutomaticKeepAliveClientMixin<ReleasePreviewPlayer> {
  static _ReleasePreviewPlayerState? _activePlayer;

  // The preview must keep its AudioPlayer alive while the release detail list
  // scrolls. Without keep-alive, Flutter can dispose off-screen track rows and
  // stop playback even though the user stayed on the same release.
  @override
  bool get wantKeepAlive => true;

  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _toggleBusy = false;
  bool _completionResetBusy = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    if (widget.track.previewUrl.isNotEmpty) {
      _player.setUrl(widget.track.previewUrl);
    }
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_resetAfterCompletion());
      }
    });
  }

  Future<void> _resetAfterCompletion() async {
    if (_completionResetBusy) return;
    _completionResetBusy = true;
    try {
      // Release the shared lock before awaiting the audio engine. just_audio
      // can emit its final state asynchronously; keeping this true leaves
      // both the preview controls and the radio button disabled after 60 s.
      if (identical(_activePlayer, this)) {
        _activePlayer = null;
        releasePreviewPlayingState.value = false;
      }
      await _player.stop();
      if (mounted) setState(() {});
    } finally {
      _completionResetBusy = false;
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    if (identical(_activePlayer, this)) {
      _activePlayer = null;
      releasePreviewPlayingState.value = false;
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_toggleBusy) return;
    _toggleBusy = true;
    try {
      if (_player.position >=
          (_player.duration ?? const Duration(minutes: 1)) -
              const Duration(milliseconds: 300)) {
        await _player.seek(Duration.zero);
      }
      if (_player.playing) {
        await _player.pause();
      } else {
        final previous = _activePlayer;
        if (previous != null && !identical(previous, this)) {
          await previous._player.pause();
        }
        _activePlayer = this;
        await stopRadioPlayback();
        releasePreviewPlayingState.value = true;
        // `play()` completes when playback ends. Do not keep the toggle lock
        // for the whole 60-second preview; otherwise pause and stop taps are
        // ignored until the preview finishes.
        unawaited(_playSafely());
      }
    } finally {
      _toggleBusy = false;
    }
  }

  Future<void> _playSafely() async {
    try {
      await _player.play();
    } catch (_) {
      if (identical(_activePlayer, this)) {
        _activePlayer = null;
        releasePreviewPlayingState.value = false;
      }
    }
  }

  Future<void> _stop() async {
    if (_toggleBusy) return;
    _toggleBusy = true;
    try {
      if (identical(_activePlayer, this)) {
        _activePlayer = null;
        releasePreviewPlayingState.value = false;
      }
      await _player.stop();
    } finally {
      _toggleBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: playing ? 'Szünet' : 'Preview lejátszása',
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.redAccent,
                    size: 34,
                  ),
                  onPressed: _toggle,
                ),
                IconButton(
                  tooltip: 'Preview leállítása',
                  icon: Icon(Icons.stop_circle_outlined, color: Colors.white),
                  onPressed: _stop,
                ),
              ],
            ),
            title: Text('${widget.index + 1}. ${widget.track.title}'),
            subtitle: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, position) {
                final duration = _player.duration ?? const Duration(minutes: 1);
                final max = duration.inMilliseconds.clamp(1, 60000).toDouble();
                final value = (position.data ?? Duration.zero).inMilliseconds
                    .clamp(0, max)
                    .toDouble();
                return Slider(
                  min: 0,
                  max: max,
                  value: value,
                  onChanged: (next) =>
                      _player.seek(Duration(milliseconds: next.round())),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
