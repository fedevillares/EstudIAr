import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String content;
  final String? subjectTag; // materia relacionada, opcional
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final bool isHidden; // ocultado por moderación/admin

  const Post({
    required this.id,
    required this.authorId,
    required this.authorDisplayName,
    this.authorAvatarUrl,
    required this.content,
    this.subjectTag,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isHidden = false,
  });

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorDisplayName': authorDisplayName,
        'authorAvatarUrl': authorAvatarUrl,
        'content': content,
        'subjectTag': subjectTag,
        'createdAt': Timestamp.fromDate(createdAt),
        'likesCount': likesCount,
        'commentsCount': commentsCount,
        'isHidden': isHidden,
      };

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Post(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorDisplayName: data['authorDisplayName'] as String? ?? 'Usuario',
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      content: data['content'] as String? ?? '',
      subjectTag: data['subjectTag'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      isHidden: data['isHidden'] as bool? ?? false,
    );
  }

  Post copyWith({int? likesCount, int? commentsCount, bool? isHidden}) => Post(
        id: id,
        authorId: authorId,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        content: content,
        subjectTag: subjectTag,
        createdAt: createdAt,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        isHidden: isHidden ?? this.isHidden,
      );
}
