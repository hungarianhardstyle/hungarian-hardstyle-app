import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/events_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/news_provider.dart';
import '../artists/artist_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../news/news_detail_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  String _label(FavoriteKind kind) {
    switch (kind) {
      case FavoriteKind.news:
        return 'Hír';
      case FavoriteKind.event:
        return 'Esemény';
      case FavoriteKind.artist:
        return 'DJ';
    }
  }

  Future<void> _openEntry(
    BuildContext context,
    WidgetRef ref,
    FavoriteEntry entry,
  ) async {
    try {
      switch (entry.kind) {
      case FavoriteKind.artist:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(artistId: entry.id),
          ),
        );
        return;
      case FavoriteKind.event:
        final events = await ref.read(eventsProvider.future);
        final eventMatches = events
            .where((item) => item.id == entry.id)
            .toList();
        final event = eventMatches.isEmpty ? null : eventMatches.first;
        if (event != null && context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Az esemény már nem érhető el.')),
          );
        }
        return;
      case FavoriteKind.news:
        final page = await ref
            .read(wordpressServiceProvider)
            .getPosts(search: entry.title, perPage: 10);
        final postMatches = page.items
            .where((item) => item.id == entry.id)
            .toList();
        final post = postMatches.isEmpty ? null : postMatches.first;
        if (post != null && context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NewsDetailScreen(post: post)),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A hír már nem érhető el.')),
          );
        }
        return;
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A kedvenc nem tölthető be.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final entries = favorites.entries;

    return Scaffold(
      appBar: AppBar(title: const Text('Kedvencek')),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                'Még nincs mentett kedvenced.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.favorite,
                      color: Colors.redAccent,
                    ),
                    title: Text(entry.title),
                    subtitle: Text(_label(entry.kind)),
                    onTap: () => _openEntry(context, ref, entry),
                    trailing: IconButton(
                      tooltip: 'Eltávolítás',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(favoritesProvider)
                          .toggle(entry.kind, entry.id, entry.title),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
