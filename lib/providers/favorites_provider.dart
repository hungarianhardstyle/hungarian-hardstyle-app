import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FavoriteKind { news, event, artist }

class FavoriteEntry {
  final FavoriteKind kind;
  final int id;
  final String title;

  const FavoriteEntry({
    required this.kind,
    required this.id,
    required this.title,
  });
}

class FavoritesNotifier extends ChangeNotifier {
  static const _storageKey = 'favorite_items';

  final Map<String, FavoriteEntry> _items = {};
  late final Future<void> _ready;

  FavoritesNotifier() {
    _ready = _load();
  }

  bool contains(FavoriteKind kind, int id) =>
      _items.containsKey(_key(kind, id));

  List<FavoriteEntry> get entries => _items.values.toList(growable: false);

  Future<void> toggle(FavoriteKind kind, int id, String title) async {
    await _ready;
    final key = _key(kind, id);
    if (_items.containsKey(key)) {
      _items.remove(key);
    } else {
      _items[key] = FavoriteEntry(kind: kind, id: id, title: title);
    }
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      _items.values
          .map(
            (entry) => jsonEncode({
              'kind': entry.kind.name,
              'id': entry.id,
              'title': entry.title,
            }),
          )
          .toList(),
    );
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    _items.clear();
    for (final value in preferences.getStringList(_storageKey) ?? const []) {
      try {
        final json = jsonDecode(value) as Map<String, dynamic>;
        final kind = FavoriteKind.values.byName(json['kind'] as String);
        final entry = FavoriteEntry(
          kind: kind,
          id: (json['id'] as num).toInt(),
          title: json['title'] as String,
        );
        _items[_key(entry.kind, entry.id)] = entry;
      } catch (_) {
        // Ignore malformed local entries.
      }
    }
    notifyListeners();
  }

  String _key(FavoriteKind kind, int id) => '${kind.name}:$id';
}

final favoritesProvider = ChangeNotifierProvider<FavoritesNotifier>((ref) {
  return FavoritesNotifier();
});
