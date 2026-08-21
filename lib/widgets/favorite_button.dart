import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/favorites_provider.dart';

class FavoriteButton extends ConsumerWidget {
  final FavoriteKind kind;
  final int id;
  final String title;

  const FavoriteButton({
    super.key,
    required this.kind,
    required this.id,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final enabled = favorites.canUseFavorites;
    final selected = enabled && favorites.contains(kind, id);

    return IconButton(
      tooltip: selected
          ? 'Eltávolítás a kedvencekből'
          : 'Hozzáadás a kedvencekhez',
      onPressed: enabled
          ? () => ref.read(favoritesProvider).toggle(kind, id, title)
          : null,
      icon: Icon(
        selected ? Icons.favorite : Icons.favorite_border,
        color: selected ? Colors.redAccent : Colors.white54,
      ),
    );
  }
}
