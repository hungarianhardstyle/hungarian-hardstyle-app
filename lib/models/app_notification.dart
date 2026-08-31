import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String targetType;
  final String targetId;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final timestamp = data['createdAt'];
    final readTimestamp = data['readAt'];
    return AppNotification(
      id: snapshot.id,
      type: data['type']?.toString() ?? 'general',
      title: data['title']?.toString().trim() ?? '',
      body: data['body']?.toString().trim() ?? '',
      targetType: data['targetType']?.toString().trim() ?? '',
      targetId: data['targetId']?.toString().trim() ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      readAt: readTimestamp is Timestamp ? readTimestamp.toDate() : null,
    );
  }
}
