import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class NewsReactionService {
  static const _databaseId = 'hungarian-hardstyle';

  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: _databaseId,
    );
  }

  Stream<int> watchCount(int postId) {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(0);
    return firestore
        .collection('news_reactions')
        .doc('$postId')
        .snapshots()
        .map((snapshot) => (snapshot.data()?['count'] as num?)?.toInt() ?? 0);
  }

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
      final count = (data['count'] as num?)?.toInt() ?? 0;
      if (liked) {
        likedBy.remove(user.uid);
      } else {
        likedBy[user.uid] = true;
      }
      transaction.set(
        reference,
        {
          'count': liked ? (count > 0 ? count - 1 : 0) : count + 1,
          'likedBy': likedBy,
        },
        SetOptions(merge: true),
      );
    });
  }
}
