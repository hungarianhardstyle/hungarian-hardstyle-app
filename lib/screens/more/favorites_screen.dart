import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/favorites_provider.dart';

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
