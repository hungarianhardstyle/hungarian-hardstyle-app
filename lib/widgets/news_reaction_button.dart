import 'dart:async';

import 'package:flutter/material.dart';

import '../services/news_reaction_service.dart';

class NewsReactionButton extends StatefulWidget {
  final int postId;

  /// Csak a tesztelhetőségért: a widget tesztben így Firebase nélkül mérhető
  /// (a `NewsReactionService` a hálózatot és az auth-ot is használja).
  final NewsReactionService? service;

  const NewsReactionButton({super.key, required this.postId, this.service});

  @override
  State<NewsReactionButton> createState() => _NewsReactionButtonState();
}

class _NewsReactionButtonState extends State<NewsReactionButton> {
  late final NewsReactionService _service =
      widget.service ?? NewsReactionService();
  bool _busy = false;
  NewsReactionState _state = const NewsReactionState();
  NewsReactionState? _pendingState;
  Timer? _pendingStateTimer;
  StreamSubscription<NewsReactionState>? _stateSubscription;
  StreamSubscription<DailyLikePoints?>? _dailyPointsSubscription;
  DailyLikePoints? _dailyPoints;

  @override
  void initState() {
    super.initState();
    _subscribeToState();
    // A napi lájkpont-keret: ha elfogyott, a lájk NEM ad pontot — erről eddig
    // semmi nem szólt, ezért a felhasználó azt hitte, elromlott. (Tulajdonosi
    // jelzés: „lájkoltam, mégsem kaptam pontot".)
    _dailyPointsSubscription = _service.watchDailyLikePoints().listen((value) {
      if (mounted) setState(() => _dailyPoints = value);
    });
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
    // Lájk előtt: ha a napi keret már elfogyott, ezt MONDJUK MEG (különben a
    // felhasználó néma csendet lát, és azt hiszi, hibás az app).
    final wasLiked = _state.liked;
    if (!wasLiked && _dailyPoints?.exhausted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_dailyPoints!.label} Hírek kedveléséért naponta '
            '${_dailyPoints!.limit} alkalommal jár pont.',
          ),
        ),
      );
    }
    final previous = _state;
    final optimistic = NewsReactionState(
      count: (previous.count + (previous.liked ? -1 : 1))
          .clamp(0, 1 << 31)
          .toInt(),
      liked: !previous.liked,
    );
    setState(() {
      _busy = true;
      _state = optimistic;
    });
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
    } catch (_) {
      if (mounted) {
        setState(() => _state = previous);
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
    _dailyPointsSubscription?.cancel();
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
