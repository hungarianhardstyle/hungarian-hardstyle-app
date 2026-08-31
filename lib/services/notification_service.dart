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
}
