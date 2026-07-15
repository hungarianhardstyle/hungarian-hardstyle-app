import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/post.dart';
import '../../providers/artists_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/news_provider.dart';
import '../../widgets/event_card.dart';
import '../artists/artist_detail_screen.dart';
import '../news/news_detail_screen.dart';

class GenreDiscoveryScreen extends ConsumerWidget {
  final String genre;

  const GenreDiscoveryScreen({super.key, required this.genre});

  bool _matchesPost(Post post) => [
        post.title,
        post.excerpt,
        post.content,
        ...post.categories,
      ].join(' ').toLowerCase().contains(genre.toLowerCase());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final artists = ref.watch(artistsProvider((category: '', search: '')));
    final posts = ref.watch(newsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(genre)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              '$genre – kapcsolódó tartalmak',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _Section(
              title: 'Események',
              child: events.when(
                loading: () => const _Loading(),
                error: (error, stack) => const _Empty(),
                data: (items) {
                  final matches = items
                      .where((event) => event.genres.any(
                            (item) => item.toLowerCase() == genre.toLowerCase(),
                          ))
                      .toList();
                  return matches.isEmpty
                      ? const _Empty()
                      : Column(
                          children: matches
                              .map((event) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: EventCard(event: event),
                                  ))
                              .toList(),
                        );
                },
              ),
            ),
            _Section(
              title: 'DJ-k',
              child: artists.when(
                loading: () => const _Loading(),
                error: (error, stack) => const _Empty(),
                data: (page) {
                  final matches = page.items
                      .where((artist) => artist.genres.any(
                            (item) => item.toLowerCase() == genre.toLowerCase(),
                          ))
                      .toList();
                  return matches.isEmpty
                      ? const _Empty()
                      : Column(
                          children: matches
                              .map((artist) => Card(
                                    child: ListTile(
                                      title: Text(artist.title),
                                      subtitle: Text(artist.genres.join(' · ')),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => ArtistDetailScreen(
                                            artistId: artist.id,
                                            fallbackName: artist.title,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        );
                },
              ),
            ),
            _Section(
              title: 'Hírek',
              child: posts.when(
                loading: () => const _Loading(),
                error: (error, stack) => const _Empty(),
                data: (items) {
                  final matches = items.where(_matchesPost).toList();
                  return matches.isEmpty
                      ? const _Empty()
                      : Column(
                          children: matches
                              .map((post) => Card(
                                    child: ListTile(
                                      title: Text(post.title),
                                      subtitle: Text(post.excerpt),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => NewsDetailScreen(post: post),
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Text(
        'Nincs találat.',
        style: TextStyle(color: Colors.white70),
      );
}
