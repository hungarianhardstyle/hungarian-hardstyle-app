import 'dart:async';

import 'package:flutter/material.dart';

import '../services/news_reaction_service.dart';

class NewsReactionButton extends StatefulWidget {
  final int postId;

  const NewsReactionButton({super.key, required this.postId});

  @override
  State<NewsReactionButton> createState() => _NewsReactionButtonState();
}

class _NewsReactionButtonState extends State<NewsReactionButton> {
  final _service = NewsReactionService();
  bool _busy = false;
  NewsReactionState _state = const NewsReactionState();
  NewsReactionState? _pendingState;
  Timer? _pendingStateTimer;
  StreamSubscription<NewsReactionState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToState();
  }

  @override
  void didUpdateWidget(covariant NewsReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      _state = const NewsReactionState();
      _subscribeToState();
    }
  }

  void _subscribeToState() {
    _stateSubscription?.cancel();
    _stateSubscription = _service.watchState(widget.postId).listen((state) {
      final pendingState = _pendingState;
      if (pendingState != null) {
        if (state.count != pendingState.count ||
            state.liked != pendingState.liked) {
          // A listener can deliver the pre-transaction snapshot after the
          // transaction has already completed. Do not resurrect that state.
          return;
        }
        _pendingState = null;
        _pendingStateTimer?.cancel();
      }
      if (mounted) setState(() => _state = state);
    });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = await _service.toggle(widget.postId);
      if (mounted) {
        _pendingState = state;
        _pendingStateTimer?.cancel();
        _pendingStateTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) return;
          _pendingState = null;
          setState(() {});
        });
        setState(() => _state = state);
      }
    } catch (error, stackTrace) {
      debugPrint('Hír-like mentési hiba: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A reakció mentése nem sikerült.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _pendingStateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _busy ? null : _toggle,
      icon: Icon(
        _state.liked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
        size: 17,
      ),
      label: Text('${_state.count}'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.redAccent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 36),
      ),
    );
  }
}
