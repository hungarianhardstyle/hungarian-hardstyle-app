import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  final String id;
  final String authorName;
  final String authorId;
  final String text;
  final String imageUrl;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorId,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
  });

  factory CommunityPost.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final timestamp = data['createdAt'];
    return CommunityPost(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Unknown User',
      text: data['text'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }
}
