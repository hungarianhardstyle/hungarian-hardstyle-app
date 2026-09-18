import 'dart:async';

import 'package:flutter/material.dart';

/// Starts loading the detail data of a list item once its card has been on
/// screen long enough to look intentional.
///
/// Cards are built when they scroll into view, so the short [delay] means a fast
/// flick starts no requests (the card is disposed before the timer fires), while
/// a card the user stops on is already loaded by the time they tap it: the
/// detail screen opens with content instead of a loader.
///
/// The request is the same one the detail screen makes and the service caches
/// and de-duplicates by id, so a repeated prefetch costs no extra request and
/// never downloads anything twice.
class DetailPrefetch extends StatefulWidget {
  const DetailPrefetch({
    super.key,
    required this.onPrefetch,
    required this.child,
    this.delay = const Duration(milliseconds: 700),
  });

  final Future<void> Function() onPrefetch;
  final Widget child;
  final Duration delay;

  @override
  State<DetailPrefetch> createState() => _DetailPrefetchState();
}

class _DetailPrefetchState extends State<DetailPrefetch> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, _run);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    _timer = null;
    try {
      await widget.onPrefetch();
    } catch (_) {
      // Prefetching is opportunistic: the detail screen loads the same data and
      // shows its own error state, so a failed warm-up must stay invisible.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
