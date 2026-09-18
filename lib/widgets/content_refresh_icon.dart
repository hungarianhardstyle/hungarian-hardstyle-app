import 'package:flutter/material.dart';

/// Small refresh affordance for WordPress-backed content surfaces.
///
/// It runs exactly the same forced refresh as pull-to-refresh, but it is
/// visible without a gesture: tapping it re-reads the section from WordPress
/// while a spinner shows that the request is still running. The button is
/// disabled during the request so a second tap cannot start a parallel load.
class ContentRefreshIcon extends StatefulWidget {
  const ContentRefreshIcon({
    super.key,
    required this.onRefresh,
    this.tooltip = 'Frissítés',
    this.color,
  });

  final Future<void> Function() onRefresh;
  final String tooltip;
  final Color? color;

  @override
  State<ContentRefreshIcon> createState() => _ContentRefreshIconState();
}

class _ContentRefreshIconState extends State<ContentRefreshIcon> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
    } catch (_) {
      // The refreshed provider already renders its own error state; the icon
      // must never surface a second, duplicate message.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _busy ? null : _run,
      color: widget.color,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
    );
  }
}
