import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
    final callable = FirebaseFunctions.instance.httpsCallable(
      'toggleNewsReaction',
    );
    final response = await callable.call(<String, dynamic>{'postId': postId});
    final data = Map<String, dynamic>.from(response.data as Map);
    return NewsReactionState(
      count: (data['count'] as num?)?.toInt() ?? 0,
      liked: data['liked'] == true,
    );
  }
}
