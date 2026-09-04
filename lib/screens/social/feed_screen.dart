import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/social_providers.dart';
import '../../widgets/social/post_card.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/skeleton_loader.dart';
import 'comments_screen.dart';
import 'profile_screen.dart';
import 'new_post_screen.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);
const _kGrad = LinearGradient(colors: [_kPurple, _kCyan]);

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0D0520), Color(0xFF080D1C), Color(0xFF000000)],
              ),
            ),
          )),
          Positioned(top: -70, right: -50, child: _orb(220, _kPurple, 0.18)),
          Positioned(bottom: 160, left: -70, child: _orb(180, _kCyan, 0.12)),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ShaderMask(
                          shaderCallback: (bounds) => _kGrad.createShader(bounds),
                          child: const Text(
                            'Comunidad',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      GlassCard(
                        opacity: 0.08,
                        borderRadius: BorderRadius.circular(14),
                        child: IconButton(
                          icon: const Icon(Icons.add_rounded, color: _kCyan, size: 24),
                          tooltip: 'Nueva publicación',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const NewPostScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: feedAsync.when(
                    data: (posts) {
                      if (posts.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: GlassCard(
                              opacity: 0.06,
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: _kPurple.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.groups_outlined,
                                        size: 36, color: _kPurple.withValues(alpha: 0.7)),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Todavía no hay publicaciones',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '¡Sé el primero en compartir algo!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return RefreshIndicator(
                        color: _kPurple,
                        backgroundColor: const Color(0xFF1A1025),
                        onRefresh: () async {
                          ref.invalidate(feedProvider);
                          await Future.delayed(const Duration(milliseconds: 400));
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 4, bottom: 140),
                          physics: const BouncingScrollPhysics(),
                          itemCount: posts.length +
                              (ref.watch(feedProvider.notifier).hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= posts.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: _kPurple),
                                  ),
                                ),
                              );
                            }
                            final post = posts[index];
                            return PostCard(
                              post: post,
                              onOpenComments: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CommentsScreen(post: post),
                                ),
                              ),
                              onOpenProfile: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(username: post.authorId),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const PostCardSkeletonList(),
                    error: (err, _) {
                      debugPrint('[feed] error cargando feed: $err');
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            kDebugMode
                                ? 'No se pudo cargar el feed.\n$err'
                                : 'No se pudo cargar el feed. Revisá tu conexión.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                        ),
                      );
                    },
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

Widget _orb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);
