import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repositories/social_repository.dart';
import '../../models/social/post.dart';
import '../../models/social/report.dart';
import '../../providers/social_providers.dart';
import '../glass_card.dart';
import 'report_dialog.dart';
import '../../utils/avatar_image.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);
const _kDanger = Color(0xFFEF4444);
const _kAvatarGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_kPurple, _kCyan],
);

class PostCard extends ConsumerWidget {
  final Post post;
  final VoidCallback? onOpenComments;
  final VoidCallback? onOpenProfile;

  const PostCard({
    super.key,
    required this.post,
    this.onOpenComments,
    this.onOpenProfile,
  });

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUsernameProvider);
    final hasLiked = ref.watch(hasLikedProvider(post.id)).maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );
    final isOwnPost = me == post.authorId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onOpenProfile,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _kAvatarGrad,
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1A1025),
                      backgroundImage: avatarImageProvider(post.authorAvatarUrl),
                      child: avatarImageProvider(post.authorAvatarUrl) == null
                          ? Text(
                              post.authorDisplayName.isNotEmpty
                                  ? post.authorDisplayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onOpenProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _timeAgo(post.createdAt),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (post.subjectTag != null && post.subjectTag!.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 110),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      post.subjectTag!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _kCyan, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: Colors.white.withValues(alpha: 0.4), size: 18),
                  color: const Color(0xFF1A1530),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await SocialRepository.deletePost(post.id);
                    } else if (value == 'report') {
                      await showReportDialog(
                        context,
                        targetType: ReportTargetType.post,
                        targetId: post.id,
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (isOwnPost)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar', style: TextStyle(color: _kDanger)),
                      ),
                    if (!isOwnPost)
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Reportar', style: TextStyle(color: Colors.white70)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _LikeButton(
                  liked: hasLiked,
                  label: '${post.likesCount}',
                  onTap: me == null
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          SocialRepository.toggleLike(post.id, me);
                        },
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  color: Colors.white.withValues(alpha: 0.6),
                  label: '${post.commentsCount}',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onOpenComments?.call();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _LikeButton extends StatefulWidget {
  final bool liked;
  final String label;
  final VoidCallback? onTap;

  const _LikeButton({required this.liked, required this.label, this.onTap});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    lowerBound: 1.0,
    upperBound: 1.35,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_LikeButton old) {
    super.didUpdateWidget(old);
    if (!old.liked && widget.liked) {
      _ctrl.forward(from: 1.0).then((_) => _ctrl.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.liked ? _kDanger : Colors.white.withValues(alpha: 0.6);
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            ScaleTransition(
              scale: _ctrl,
              child: Icon(
                widget.liked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(widget.label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
