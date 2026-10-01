import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/social/post.dart';
import '../../models/social/comment.dart';
import '../../models/social/report.dart';
import '../security/content_moderation_service.dart';
import 'moderation_exceptions.dart';

export 'moderation_exceptions.dart';

class SocialRepository {
  SocialRepository._();
  static final _db = FirebaseFirestore.instance;

  static const _maxPostLength = 2000;
  static const _maxCommentLength = 1000;

  // ── Posts ───────────────────────────────────────────────────────
  static Stream<List<Post>> watchFeed({int limit = 50}) {
    return _db
        .collection('posts')
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Post.fromDoc).toList());
  }

  static Stream<List<Post>> watchUserPosts(String username, {int limit = 50}) {
    return _db
        .collection('posts')
        .where('authorId', isEqualTo: username)
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Post.fromDoc).toList());
  }

  /// Crea un post tras pasar la revisión de moderación. Lanza
  /// [ContentRejectedException] si el contenido es rechazado.
  static Future<void> createPost({
    required String authorId,
    required String authorDisplayName,
    String? authorAvatarUrl,
    required String content,
    String? subjectTag,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const ContentRejectedException('La publicación no puede estar vacía.');
    }
    if (trimmed.length > _maxPostLength) {
      throw const ContentRejectedException(
          'La publicación supera el largo máximo permitido.');
    }

    final moderation = await ContentModerationService.reviewPublicContent(trimmed);
    if (!moderation.isAllowed) {
      throw ContentRejectedException(
          moderation.reason ?? 'Contenido no permitido.');
    }

    final post = Post(
      id: '',
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      content: trimmed,
      subjectTag: subjectTag,
      createdAt: DateTime.now(),
    );
    await _db.collection('posts').add(post.toMap());
  }

  static Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }

  static Future<void> hidePost(String postId, {bool hidden = true}) async {
    await _db.collection('posts').doc(postId).update({'isHidden': hidden});
  }

  // ── Likes ───────────────────────────────────────────────────────
  static Stream<bool> watchHasLiked(String postId, String username) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(username)
        .snapshots()
        .map((doc) => doc.exists);
  }

  static Future<void> toggleLike(String postId, String username) async {
    final likeRef =
        _db.collection('posts').doc(postId).collection('likes').doc(username);
    final postRef = _db.collection('posts').doc(postId);

    await _db.runTransaction((tx) async {
      final likeDoc = await tx.get(likeRef);
      final postDoc = await tx.get(postRef);
      if (!postDoc.exists) return;

      final currentLikes = (postDoc.data()?['likesCount'] as num?)?.toInt() ?? 0;
      if (likeDoc.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likesCount': (currentLikes - 1).clamp(0, 1 << 31)});
      } else {
        tx.set(likeRef, {'createdAt': Timestamp.now()});
        tx.update(postRef, {'likesCount': currentLikes + 1});
      }
    });
  }

  // ── Comentarios ─────────────────────────────────────────────────
  static Stream<List<Comment>> watchComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Comment.fromDoc(d, postId)).toList());
  }

  static Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorDisplayName,
    String? authorAvatarUrl,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const ContentRejectedException('El comentario no puede estar vacío.');
    }
    if (trimmed.length > _maxCommentLength) {
      throw const ContentRejectedException(
          'El comentario supera el largo máximo permitido.');
    }

    final moderation = await ContentModerationService.reviewPublicContent(trimmed);
    if (!moderation.isAllowed) {
      throw ContentRejectedException(
          moderation.reason ?? 'Contenido no permitido.');
    }

    final comment = Comment(
      id: '',
      postId: postId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    final postRef = _db.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc();

    await _db.runTransaction((tx) async {
      final postDoc = await tx.get(postRef);
      if (!postDoc.exists) {
        throw const ContentRejectedException('La publicación ya no existe.');
      }
      final currentCount = (postDoc.data()?['commentsCount'] as num?)?.toInt() ?? 0;
      tx.set(commentRef, comment.toMap());
      tx.update(postRef, {'commentsCount': currentCount + 1});
    });
  }

  static Future<void> deleteComment(String postId, String commentId) async {
    final postRef = _db.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);
    await _db.runTransaction((tx) async {
      final postDoc = await tx.get(postRef);
      if (!postDoc.exists) return;
      final currentCount = (postDoc.data()?['commentsCount'] as num?)?.toInt() ?? 0;
      tx.delete(commentRef);
      tx.update(postRef, {'commentsCount': (currentCount - 1).clamp(0, 1 << 31)});
    });
  }

  // ── Follows ─────────────────────────────────────────────────────
  static String _followId(String follower, String following) =>
      '${follower}_$following';

  static Stream<bool> watchIsFollowing(String follower, String following) {
    return _db
        .collection('follows')
        .doc(_followId(follower, following))
        .snapshots()
        .map((d) => d.exists);
  }

  static Future<void> follow(String follower, String following) async {
    if (follower == following) return;
    final followRef = _db.collection('follows').doc(_followId(follower, following));
    final followerUserRef = _db.collection('users').doc(follower);
    final followingUserRef = _db.collection('users').doc(following);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(followRef);
      if (existing.exists) return;
      tx.set(followRef, {
        'followerId': follower,
        'followingId': following,
        'createdAt': Timestamp.now(),
      });
      tx.update(followerUserRef, {'followingCount': FieldValue.increment(1)});
      tx.update(followingUserRef, {'followersCount': FieldValue.increment(1)});
    });
  }

  static Future<void> unfollow(String follower, String following) async {
    final followRef = _db.collection('follows').doc(_followId(follower, following));
    final followerUserRef = _db.collection('users').doc(follower);
    final followingUserRef = _db.collection('users').doc(following);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(followRef);
      if (!existing.exists) return;
      tx.delete(followRef);
      tx.update(followerUserRef, {'followingCount': FieldValue.increment(-1)});
      tx.update(followingUserRef, {'followersCount': FieldValue.increment(-1)});
    });
  }

  static Stream<List<String>> watchFollowers(String username) {
    return _db
        .collection('follows')
        .where('followingId', isEqualTo: username)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()['followerId'] as String).toList());
  }

  static Stream<List<String>> watchFollowing(String username) {
    return _db
        .collection('follows')
        .where('followerId', isEqualTo: username)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()['followingId'] as String).toList());
  }

  // ── Bloqueos ────────────────────────────────────────────────────
  static String _blockId(String blocker, String blocked) => '${blocker}_$blocked';

  static Future<void> blockUser(String blocker, String blocked) async {
    await _db.collection('blocks').doc(_blockId(blocker, blocked)).set({
      'blockerId': blocker,
      'blockedId': blocked,
      'createdAt': Timestamp.now(),
    });
  }

  static Future<void> unblockUser(String blocker, String blocked) async {
    await _db.collection('blocks').doc(_blockId(blocker, blocked)).delete();
  }

  static Stream<bool> watchIsBlocked(String blocker, String blocked) {
    return _db
        .collection('blocks')
        .doc(_blockId(blocker, blocked))
        .snapshots()
        .map((d) => d.exists);
  }

  static Future<bool> isBlockedEitherWay(String userA, String userB) async {
    final a = await _db.collection('blocks').doc(_blockId(userA, userB)).get();
    if (a.exists) return true;
    final b = await _db.collection('blocks').doc(_blockId(userB, userA)).get();
    return b.exists;
  }

  // ── Reportes ────────────────────────────────────────────────────
  static Future<void> reportContent({
    required String reporterId,
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
  }) async {
    final report = Report(
      id: '',
      reporterId: reporterId,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      createdAt: DateTime.now(),
    );
    await _db.collection('reports').add(report.toMap());
  }
}
