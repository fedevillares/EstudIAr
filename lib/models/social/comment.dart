import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String authorId;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorDisplayName,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'postId': postId,
        'authorId': authorId,
        'authorDisplayName': authorDisplayName,
        'authorAvatarUrl': authorAvatarUrl,
        'content': content,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Comment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc, String postId) {
    final data = doc.data() ?? {};
    return Comment(
      id: doc.id,
      postId: postId,
      authorId: data['authorId'] as String? ?? '',
      authorDisplayName: data['authorDisplayName'] as String? ?? 'Usuario',
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      content: data['content'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
