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

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.toggle(widget.postId);
    } catch (_) {
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
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _service.watchCount(widget.postId),
      initialData: 0,
      builder: (context, snapshot) => TextButton.icon(
        onPressed: _busy ? null : _toggle,
        icon: const Icon(Icons.thumb_up_alt_outlined, size: 17),
        label: Text('${snapshot.data ?? 0}'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(0, 36),
        ),
      ),
    );
  }
}
