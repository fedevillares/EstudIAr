import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/social_providers.dart';
import 'chat_screen.dart';
import 'new_conversation_screen.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat('dd/MM').format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUsernameProvider);
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          const LinearGradient(colors: [_kPurple, _kCyan]).createShader(bounds),
                      child: const Text(
                        'Mensajes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: _kPurple),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NewConversationScreen()),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: conversationsAsync.when(
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return Center(
                      child: Text(
                        'No tenés conversaciones todavía.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      final other = me != null ? conv.otherParticipant(me) : '?';
                      final unread = me != null ? conv.unreadFor(me) : 0;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _kPurple.withValues(alpha: 0.25),
                          child: Text(other.isNotEmpty ? other[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(other,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(
                          conv.lastMessage ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread > 0 ? Colors.white70 : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_formatTime(conv.updatedAt),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                            if (unread > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _kPurple,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('$unread',
                                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChatScreen(otherUsername: other)),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: _kPurple)),
                error: (err, _) {
                  debugPrint('[mensajes] error cargando conversaciones: $err');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        kDebugMode
                            ? 'No se pudieron cargar tus mensajes.\n$err'
                            : 'No se pudieron cargar tus mensajes.',
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
    );
  }
}
