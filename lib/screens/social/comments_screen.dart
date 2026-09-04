import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/social_repository.dart';
import '../../models/social/post.dart';
import '../../providers/social_providers.dart';
import '../../widgets/social/post_card.dart';
import '../../utils/avatar_image.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);
const _kDanger = Color(0xFFEF4444);

Widget _orb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);

class CommentsScreen extends ConsumerStatefulWidget {
  final Post post;
  const CommentsScreen({super.key, required this.post});

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _commentCtrl = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final me = ref.read(currentUsernameProvider);
    if (me == null) return;
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final profile = await ref.read(currentUserProfileProvider.future);
      await SocialRepository.addComment(
        postId: widget.post.id,
        authorId: me,
        authorDisplayName: profile?.displayName ?? me,
        authorAvatarUrl: profile?.avatarUrl,
        content: text,
      );
      _commentCtrl.clear();
    } on ContentRejectedException catch (e) {
      if (mounted) setState(() => _error = e.reason);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo comentar. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.post.id));
    final me = ref.watch(currentUsernameProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Comentarios', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D0520), Color(0xFF080D1C), Colors.black],
                ),
              ),
            ),
          ),
          Positioned(top: -60, right: -60, child: _orb(200, _kPurple, 0.18)),
          Positioned(bottom: 160, left: -60, child: _orb(160, _kCyan, 0.12)),
          SafeArea(
            child: Column(
              children: [
                PostCard(post: widget.post),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: commentsAsync.when(
                    data: (comments) {
                      if (comments.isEmpty) {
                        return Center(
                          child: Text('Sé el primero en comentar.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final c = comments[index];
                          final isOwn = c.authorId == me;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _kPurple.withValues(alpha: 0.25),
                                  backgroundImage: avatarImageProvider(c.authorAvatarUrl),
                                  child: avatarImageProvider(c.authorAvatarUrl) == null
                                      ? Text(
                                          c.authorDisplayName.isNotEmpty
                                              ? c.authorDisplayName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.authorDisplayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(c.content,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isOwn)
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        size: 16, color: Colors.white.withValues(alpha: 0.3)),
                                    onPressed: () => SocialRepository.deleteComment(widget.post.id, c.id),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: _kPurple)),
                    error: (_, __) => Center(
                      child: Text('Error al cargar comentarios.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_error!, style: const TextStyle(color: _kDanger, fontSize: 12)),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            style: const TextStyle(color: Colors.white),
                            maxLength: 1000,
                            decoration: InputDecoration(
                              hintText: 'Escribí un comentario...',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: _sending
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPurple),
                                )
                              : const Icon(Icons.send, color: _kPurple),
                          onPressed: _sending ? null : _sendComment,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
