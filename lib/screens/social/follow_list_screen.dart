import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/social_providers.dart';
import 'profile_screen.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);

Widget _orb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);

class FollowListScreen extends ConsumerWidget {
  final String username;
  final bool isFollowers;
  const FollowListScreen({super.key, required this.username, required this.isFollowers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = isFollowers
        ? ref.watch(followersProvider(username))
        : ref.watch(followingProvider(username));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(isFollowers ? 'Seguidores' : 'Siguiendo', style: const TextStyle(color: Colors.white)),
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
          Positioned(bottom: 120, left: -60, child: _orb(160, _kCyan, 0.12)),
          SafeArea(
            child: listAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      isFollowers ? 'Sin seguidores todavía.' : 'No sigue a nadie todavía.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final u = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _kPurple.withValues(alpha: 0.25),
                        child: Text(u.isNotEmpty ? u[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(u,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ProfileScreen(username: u)),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: _kPurple)),
              error: (_, __) => Center(
                child: Text('Error al cargar.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
