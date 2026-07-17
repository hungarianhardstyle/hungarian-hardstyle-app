import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/news_provider.dart';
import '../../widgets/news_card.dart';

class TaggedNewsScreen extends ConsumerWidget {
  final String tag;
  const TaggedNewsScreen({super.key, required this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(newsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('#$tag')),
      body: news.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'A címke hírei nem tölthetők be.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
        data: (posts) {
          final matches = posts
              .where(
                (post) => post.tags.any(
                  (value) => value.toLowerCase() == tag.toLowerCase(),
                ),
              )
              .toList();
          if (matches.isEmpty) {
            return const Center(child: Text('Nincs cikk ehhez a címkéhez.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: matches.length,
            itemBuilder: (_, index) => NewsCard(post: matches[index]),
          );
        },
      ),
    );
  }
}
