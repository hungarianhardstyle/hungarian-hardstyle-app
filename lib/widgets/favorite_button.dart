import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/tr.dart';
import '../providers/favorites_provider.dart';
import 'notification_permission_prompt.dart';

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
          ? tr(context, 'Eltávolítás a kedvencekből')
          : tr(context, 'Hozzáadás a kedvencekhez'),
      onPressed: enabled
          ? () async {
              final wasFavorite = favorites.contains(kind, id);
              await ref.read(favoritesProvider).toggle(kind, id, title);
              // ⚠️ ÉRTESÍTÉSI ENGEDÉLY — az első értelmes felhasználói műveletek
              // EGYIKE (2026-09-28): **kedvenc mentése**. Csak hozzáadásnál
              // kérdezünk (a törlés nem pozitív jelzés), és csak **sikeres** mentés
              // után. A `mounted`-ellenőrzés az `await` utáni `context`-hez kell;
              // `unawaited`, hogy a felugró lap ne késleltesse a szív ikon váltását.
              if (!wasFavorite && context.mounted) {
                unawaited(
                  NotificationPermissionPrompt.requestAfterAction(context),
                );
              }
            }
          : null,
      icon: Icon(
        selected ? Icons.favorite : Icons.favorite_border,
        color: selected ? Colors.redAccent : Colors.white54,
      ),
    );
  }
}
