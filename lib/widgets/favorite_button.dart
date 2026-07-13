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
    final selected = ref.watch(favoritesProvider).contains(kind, id);

    return IconButton(
      tooltip: selected
          ? 'Eltávolítás a kedvencekből'
          : 'Hozzáadás a kedvencekhez',
      onPressed: () => ref.read(favoritesProvider).toggle(kind, id, title),
      icon: Icon(
        selected ? Icons.favorite : Icons.favorite_border,
        color: selected ? Colors.redAccent : Colors.white54,
      ),
    );
  }
}
