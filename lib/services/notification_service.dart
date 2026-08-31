import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_notification.dart';

class NotificationService {
  NotificationService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : auth = auth ?? FirebaseAuth.instance,
      firestore =
          firestore ??
          FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: 'hungarian-hardstyle',
          );

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  Stream<List<AppNotification>> watchNotifications({int limit = 50}) {
    final uid = auth.currentUser?.uid;
    if (uid == null || auth.currentUser?.isAnonymous == true) {
      return Stream<List<AppNotification>>.value(const []);
    }
    // Sort locally so this read does not require a new composite Firestore index.
    return firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(AppNotification.fromSnapshot)
              .where((item) => !item.isArchived)
              .toList();
          items.sort(
            (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          );
          return items;
        });
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead || auth.currentUser?.uid == null) return;
    await firestore.collection('notifications').doc(notification.id).update({
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllRead() async {
    final uid = auth.currentUser?.uid;
    if (uid == null || auth.currentUser?.isAnonymous == true) return;
    final snapshot = await firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .get();
    final unread = snapshot.docs.where((doc) {
      final data = doc.data();
      return data['readAt'] == null && data['archivedAt'] == null;
    });
    await _commitInChunks(unread, (batch, doc) {
      batch.update(doc.reference, {'readAt': FieldValue.serverTimestamp()});
    });
  }

  Future<void> archive(AppNotification notification) async {
    if (auth.currentUser?.uid == null) return;
    await firestore.collection('notifications').doc(notification.id).update({
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(AppNotification notification) async {
    if (auth.currentUser?.uid == null) return;
    await firestore.collection('notifications').doc(notification.id).delete();
  }

  Future<void> deleteAll() async {
    final uid = auth.currentUser?.uid;
    if (uid == null || auth.currentUser?.isAnonymous == true) return;
    final snapshot = await firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .get();
    await _commitInChunks(snapshot.docs, (batch, doc) {
      batch.delete(doc.reference);
    });
  }

  Future<void> archiveReadOlderThan(Duration age) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || auth.currentUser?.isAnonymous == true) return;
    final cutoff = DateTime.now().subtract(age);
    final snapshot = await firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .get();
    final oldRead = snapshot.docs.where((doc) {
      final data = doc.data();
      final readAt = data['readAt'];
      return data['archivedAt'] == null &&
          readAt is Timestamp &&
          readAt.toDate().isBefore(cutoff);
    });
    await _commitInChunks(oldRead, (batch, doc) {
      batch.update(doc.reference, {'archivedAt': FieldValue.serverTimestamp()});
    });
  }

  Future<void> _commitInChunks(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    void Function(
      WriteBatch batch,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    )
    operation,
  ) async {
    final docs = documents.toList();
    for (var offset = 0; offset < docs.length; offset += 450) {
      final batch = firestore.batch();
      final end = (offset + 450).clamp(0, docs.length);
      for (final doc in docs.sublist(offset, end)) {
        operation(batch, doc);
      }
      await batch.commit();
    }
  }
}
