import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../providers/events_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/news_provider.dart';
import '../../widgets/app_text.dart';
import '../artists/artist_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../news/news_detail_screen.dart';
import '../organizers/organizer_detail_screen.dart';

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
      case FavoriteKind.organizer:
        return 'Szervező';
    }
  }

  static Future<void> openEntry(
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
              MaterialPageRoute(
                builder: (_) => EventDetailScreen(event: event),
              ),
            );
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: AppText('Az esemény már nem érhető el.')),
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
              const SnackBar(content: AppText('A hír már nem érhető el.')),
            );
          }
          return;
        case FavoriteKind.organizer:
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrganizerDetailScreen(
                organizerId: entry.id,
                fallbackName: entry.title,
              ),
            ),
          );
          return;
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('A kedvenc nem tölthető be.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final entries = favorites.entries;

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Kedvencek'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: tr(context, 'Összes törlése'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const AppText('Kedvencek törlése'),
                    content: const AppText('Törlöd az összes mentett kedvencet?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const AppText('Mégse'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const AppText('Törlés'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref.read(favoritesProvider).clearAll();
                }
              },
            ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(
              child: AppText(
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
                    onTap: () => openEntry(context, ref, entry),
                    trailing: IconButton(
                      tooltip: tr(context, 'Eltávolítás'),
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
