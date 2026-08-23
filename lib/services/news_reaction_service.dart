import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class NewsReactionState {
  final int count;
  final bool liked;

  const NewsReactionState({this.count = 0, this.liked = false});
}

class NewsReactionService {
  static const _databaseId = 'hungarian-hardstyle';

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
    return firestore
        .collection('news_reactions')
        .doc('$postId')
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data() ?? const <String, dynamic>{};
          final rawLikedBy = data['likedBy'];
          final likedBy = rawLikedBy is Map
              ? Map<String, dynamic>.from(rawLikedBy)
              : <String, dynamic>{};
          final userId = FirebaseAuth.instance.currentUser?.uid;
          final storedCount = (data['count'] as num?)?.toInt() ?? 0;
          final count = likedBy.isEmpty
              ? storedCount
              : likedBy.values.where((value) => value == true).length;
          return NewsReactionState(
            count: count,
            liked: userId != null && likedBy[userId] == true,
          );
        });
  }

  Stream<int> watchCount(int postId) =>
      watchState(postId).map((state) => state.count);

  Future<void> toggle(int postId) async {
    final firestore = _firestore;
    if (firestore == null) return;
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) return;
    final reference = firestore.collection('news_reactions').doc('$postId');
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final likedBy = Map<String, dynamic>.from(
        data['likedBy'] as Map? ?? const <String, dynamic>{},
      );
      final liked = likedBy[user.uid] == true;
      if (liked) {
        likedBy.remove(user.uid);
      } else {
        likedBy[user.uid] = true;
      }
      final count = likedBy.values.where((value) => value == true).length;
      transaction.set(reference, {
        'count': liked ? (count > 0 ? count - 1 : 0) : count + 1,
        'likedBy': likedBy,
      }, SetOptions(merge: true));
    });
  }
}
