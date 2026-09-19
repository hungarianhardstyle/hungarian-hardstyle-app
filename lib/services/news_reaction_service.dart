import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/firebase/firebase_callable.dart';

class NewsReactionState {
  final int count;
  final bool liked;

  const NewsReactionState({this.count = 0, this.liked = false});
}

class NewsReactionService {
  static const _databaseId = 'hungarian-hardstyle';

  static Map<String, bool> normalizeLikedBy(Object? rawLikedBy) {
    if (rawLikedBy is Map) {
      return <String, bool>{
        for (final entry in rawLikedBy.entries)
          if (entry.key is String && entry.value == true)
            entry.key as String: true,
      };
    }

    // Older documents may contain a UID list instead of the current map.
    if (rawLikedBy is List) {
      return <String, bool>{
        for (final uid in rawLikedBy.whereType<String>()) uid: true,
      };
    }

    return <String, bool>{};
  }

  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: _databaseId,
    );
  }

  Stream<NewsReactionState> watchState(int postId) {
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value(const NewsReactionState());
    }
    return Stream.multi((controller) {
      StreamSubscription<User?>? authSubscription;
      StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      documentSubscription;

      authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        documentSubscription?.cancel();
        documentSubscription = firestore
            .collection('news_reactions')
            .doc('$postId')
            .snapshots()
            .listen((snapshot) {
              final data = snapshot.data() ?? const <String, dynamic>{};
              final likedBy = normalizeLikedBy(data['likedBy']);
              controller.add(
                NewsReactionState(
                  count: likedBy.length,
                  liked: user != null && likedBy[user.uid] == true,
                ),
              );
            }, onError: controller.addError);
      }, onError: controller.addError);

      controller.onCancel = () async {
        await authSubscription?.cancel();
        await documentSubscription?.cancel();
      };
    });
  }

  Stream<int> watchCount(int postId) =>
      watchState(postId).map((state) => state.count);

  Future<NewsReactionState> toggle(int postId) async {
    if (postId <= 0) {
      throw ArgumentError.value(
        postId,
        'postId',
        'Érvényes hír-azonosító kell.',
      );
    }
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) {
      throw StateError('A reakcióhoz nem sikerült felhasználót azonosítani.');
    }
    final response = await callFirebaseCallable<Map<String, dynamic>>(
      'toggleNewsReaction',
      parameters: <String, dynamic>{'postId': postId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return NewsReactionState(
      count: (data['count'] as num?)?.toInt() ?? 0,
      liked: data['liked'] == true,
    );
  }

  /// A napi lájkpont-keret állapota a **saját** profilból, vagy `null`.
  ///
  /// MIÉRT: a tulajdonos jelzése szerint a felhasználó lájkolt, és nem történt
  /// semmi — mert a napi 3 pontos keret már elfogyott, erről viszont az app nem
  /// szólt. A szerver a napi számlálót a profilba is beírja
  /// (`achievementDailyLimit`), ezért innen ki tudjuk írni: „Ma 2/3 lájkpont" /
  /// „A mai lájkpontod elfogyott".
  Stream<DailyLikePoints?> watchDailyLikePoints() {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(null);
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null || user.isAnonymous) return Stream.value(null);
      return firestore
          .collection('community_profiles')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) => dailyLikePointsOf(snapshot.data()));
    });
  }
}

/// A napi lájkpont-keret a profil mezőjéből (tiszta logika → tesztelhető).
class DailyLikePoints {
  const DailyLikePoints({
    required this.count,
    required this.limit,
    required this.date,
  });

  final int count;
  final int limit;
  final String date;

  bool get exhausted => count >= limit;

  String get label => exhausted
      ? 'A mai lájkpontod elfogyott.'
      : 'Ma $count/$limit lájkpont jár.';
}

/// `achievementDailyLimit` mezőből, ha az a mai napra és a hír-lájkra vonatkozik.
DailyLikePoints? dailyLikePointsOf(Object? profileData, {DateTime? now}) {
  if (profileData is! Map) return null;
  final raw = profileData['achievementDailyLimit'];
  if (raw is! Map) return null;
  if ('${raw['kind'] ?? ''}' != 'newsLike') return null;
  final nowDate = now ?? DateTime.now();
  final today =
      '${nowDate.year.toString().padLeft(4, '0')}-'
      '${nowDate.month.toString().padLeft(2, '0')}-'
      '${nowDate.day.toString().padLeft(2, '0')}';
  if ('${raw['date'] ?? ''}' != today) return null;
  final limit = (raw['limit'] as num?)?.toInt() ?? 0;
  final count = (raw['count'] as num?)?.toInt() ?? 0;
  if (limit <= 0) return null;
  return DailyLikePoints(count: count, limit: limit, date: today);
}
