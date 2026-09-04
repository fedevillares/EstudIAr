import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/repositories/social_repository.dart';
import '../../models/app_user.dart';
import '../../models/social/report.dart';
import '../../providers/social_providers.dart';
import '../../widgets/social/post_card.dart';
import '../../widgets/social/report_dialog.dart';
import '../../utils/avatar_image.dart';
import 'comments_screen.dart';
import 'edit_profile_screen.dart';
import 'follow_list_screen.dart';
import '../messages/chat_screen.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);
const _kDanger = Color(0xFFEF4444);

class ProfileScreen extends ConsumerStatefulWidget {
  final String username;
  const ProfileScreen({super.key, required this.username});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Future creado una sola vez en initState para que los rebuilds causados
  // por cambios en isFollowingProvider / isBlockedProvider (follow/unfollow,
  // bloqueo) no relancen la carga del perfil desde Firestore ni generen
  // el parpadeo de CircularProgressIndicator que provocaba la versión
  // ConsumerWidget (nueva instancia de Future en cada build call).
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.username)
        .get();
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
      ref.read(userPostsProvider(widget.username).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUsernameProvider);
    final isOwnProfile = me == widget.username;
    final postsAsync = ref.watch(userPostsProvider(widget.username));
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.username));
    final isBlockedAsync = ref.watch(isBlockedProvider(widget.username));
    // Alias locales para simplificar referencias al username.
    final username = widget.username;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
          Positioned(top: -60, right: -60, child: _profileOrb(220, _kPurple, 0.18)),
          Positioned(bottom: 240, left: -70, child: _profileOrb(180, _kCyan, 0.12)),
          SafeArea(
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _userFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: _kPurple));
                }
                final data = snapshot.data!.data();
                final user = data != null ? AppUser.fromMap(data) : null;
                final displayName = user?.displayName ?? username;
                final bio = user?.bio ?? '';

                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      actions: [
                        if (isOwnProfile)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                            ),
                          )
                        else
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white70),
                            color: const Color(0xFF1A1530),
                            onSelected: (value) async {
                              if (value == 'report') {
                                await showReportDialog(context,
                                    targetType: ReportTargetType.user, targetId: username);
                              } else if (value == 'block') {
                                final isBlocked = isBlockedAsync.maybeWhen(data: (v) => v, orElse: () => false);
                                if (me == null) return;
                                if (isBlocked) {
                                  await SocialRepository.unblockUser(me, username);
                                } else {
                                  await SocialRepository.blockUser(me, username);
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'report', child: Text('Reportar usuario', style: TextStyle(color: Colors.white70))),
                              PopupMenuItem(
                                value: 'block',
                                child: Text(
                                  isBlockedAsync.maybeWhen(data: (v) => v, orElse: () => false)
                                      ? 'Desbloquear'
                                      : 'Bloquear',
                                  style: const TextStyle(color: _kDanger),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_kPurple, _kCyan],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: const Color(0xFF1A1025),
                                backgroundImage: avatarImageProvider(user?.avatarUrl),
                                child: avatarImageProvider(user?.avatarUrl) == null
                                    ? Text(
                                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                            ),
                            if (bio.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                bio,
                                textAlign: TextAlign.center,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatTap(
                                  label: 'Seguidores',
                                  count: user?.followersCount ?? 0,
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => FollowListScreen(username: username, isFollowers: true))),
                                ),
                                const SizedBox(width: 28),
                                _StatTap(
                                  label: 'Siguiendo',
                                  count: user?.followingCount ?? 0,
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => FollowListScreen(username: username, isFollowers: false))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (!isOwnProfile && me != null)
                              Row(
                                children: [
                                  Expanded(
                                    child: isFollowingAsync.when(
                                      data: (isFollowing) => OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: isFollowing ? Colors.transparent : _kPurple,
                                          side: BorderSide(color: _kPurple),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () async {
                                          if (isFollowing) {
                                            await SocialRepository.unfollow(me, username);
                                          } else {
                                            await SocialRepository.follow(me, username);
                                          }
                                        },
                                        child: Text(isFollowing ? 'Siguiendo' : 'Seguir',
                                            style: TextStyle(color: isFollowing ? _kPurple : Colors.white)),
                                      ),
                                      loading: () => const SizedBox(height: 36),
                                      error: (_, __) => const SizedBox.shrink(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: _kCyan),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => ChatScreen(otherUsername: username)),
                                      ),
                                      child: const Text('Mensaje', style: TextStyle(color: _kCyan)),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white12),
                          ],
                        ),
                      ),
                    ),
                    postsAsync.when(
                      data: (posts) {
                        if (posts.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text('Sin publicaciones todavía.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                              ),
                            ),
                          );
                        }
                        final hasMore =
                            ref.watch(userPostsProvider(username).notifier).hasMore;
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
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
                                  MaterialPageRoute(builder: (_) => CommentsScreen(post: post)),
                                ),
                              );
                            },
                            childCount: posts.length + (hasMore ? 1 : 0),
                          ),
                        );
                      },
                      loading: () => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator(color: _kPurple)),
                        ),
                      ),
                      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTap extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;
  const _StatTap({required this.label, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

Widget _profileOrb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);
