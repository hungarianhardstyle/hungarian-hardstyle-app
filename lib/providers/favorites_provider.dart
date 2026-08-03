import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FavoriteKind { news, event, artist, organizer }

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
  static const _databaseId = 'hungarian-hardstyle';

  final Map<String, FavoriteEntry> _items = {};
  late final Future<void> _ready;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  StreamSubscription<User?>? _authSubscription;
  String? _userId;
  bool _hadAuthenticatedUser = false;

  FavoritesNotifier() {
    // Widget tests and offline startup can render favorites before Firebase is
    // configured. Local favorites remain available until a Firebase app exists.
    if (Firebase.apps.isNotEmpty) {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: _databaseId,
      );
    }
    _ready = _initialize();
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
    await _saveCloud();
  }

  Future<void> clearAll() async {
    await _ready;
    _items.clear();
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    await _clearCloud();
  }

  Future<void> _initialize() async {
    await _loadLocal();
    final auth = _auth;
    if (auth == null) return;
    _authSubscription = auth.authStateChanges().listen(_handleAuthChange);
    await _handleAuthChange(auth.currentUser);
  }

  Future<void> _handleAuthChange(User? user) async {
    final nextUserId = user == null || user.isAnonymous ? null : user.uid;
    if (_userId == nextUserId) return;
    if (nextUserId != null && _hadAuthenticatedUser && _userId != nextUserId) {
      _items.clear();
    }
    _userId = nextUserId;
    if (nextUserId == null) return;
    _hadAuthenticatedUser = true;

    final collection = _favoritesCollection(nextUserId);
    if (collection == null) return;
    final snapshot = await collection.get();
    for (final document in snapshot.docs) {
      try {
        final data = document.data();
        final entry = FavoriteEntry(
          kind: FavoriteKind.values.byName(data['kind'] as String),
          id: (data['id'] as num).toInt(),
          title: data['title'] as String,
        );
        _items[_key(entry.kind, entry.id)] = entry;
      } catch (_) {
        // Ignore malformed cloud entries.
      }
    }
    await _saveLocal();
    await _saveCloud();
    notifyListeners();
  }

  Future<void> _loadLocal() async {
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

  CollectionReference<Map<String, dynamic>>? _favoritesCollection(String uid) {
    final firestore = _firestore;
    if (firestore == null) return null;
    return firestore
        .collection('community_profiles')
        .doc(uid)
        .collection('favorites');
  }

  Future<void> _saveLocal() async {
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

  Future<void> _saveCloud() async {
    final uid = _userId;
    final firestore = _firestore;
    final collection = uid == null ? null : _favoritesCollection(uid);
    if (collection == null || firestore == null) return;
    final existing = await collection.get();
    final batch = firestore.batch();
    final keys = _items.keys.toSet();
    for (final document in existing.docs) {
      if (!keys.contains(document.id)) batch.delete(document.reference);
    }
    for (final entry in _items.values) {
      batch.set(collection.doc(_key(entry.kind, entry.id)), {
        'kind': entry.kind.name,
        'id': entry.id,
        'title': entry.title,
      });
    }
    await batch.commit();
  }

  Future<void> _clearCloud() async {
    final uid = _userId;
    final firestore = _firestore;
    final collection = uid == null ? null : _favoritesCollection(uid);
    if (collection == null || firestore == null) return;
    final snapshot = await collection.get();
    final batch = firestore.batch();
    for (final document in snapshot.docs) {
      batch.delete(document.reference);
    }
    await batch.commit();
  }

  String _key(FavoriteKind kind, int id) => '${kind.name}:$id';

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final favoritesProvider = ChangeNotifierProvider<FavoritesNotifier>((ref) {
  return FavoritesNotifier();
});
