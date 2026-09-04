import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repositories/messaging_repository.dart';
import '../../core/repositories/social_repository.dart';
import '../../models/social/message.dart';
import '../../models/social/report.dart';
import '../../providers/social_providers.dart';
import '../../widgets/social/report_dialog.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);
const _kDanger = Color(0xFFEF4444);

Widget _chatOrb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUsername;
  const ChatScreen({super.key, required this.otherUsername});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _conversationId;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final me = ref.read(currentUsernameProvider);
    if (me == null) return;
    final conv = await MessagingRepository.getOrCreateConversation(me, widget.otherUsername);
    await MessagingRepository.markAsRead(conv.id, me);
    if (mounted) setState(() => _conversationId = conv.id);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = ref.read(currentUsernameProvider);
    if (me == null || _conversationId == null) return;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await MessagingRepository.sendMessage(
        conversationId: _conversationId!,
        senderId: me,
        receiverId: widget.otherUsername,
        content: text,
      );
      _msgCtrl.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } on BlockedUserException catch (e) {
      setState(() => _error = e.toString());
    } on ContentRejectedException catch (e) {
      setState(() => _error = e.reason);
    } catch (_) {
      setState(() => _error = 'No se pudo enviar el mensaje. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUsernameProvider);
    final isBlockedAsync = ref.watch(isBlockedProvider(widget.otherUsername));
    final isBlocked = isBlockedAsync.maybeWhen(data: (v) => v, orElse: () => false);
    // Solo se puede escribir si ambos se siguen mutuamente — evita mensajes
    // no solicitados de desconocidos (ver [isMutualFollowProvider]).
    final isMutual = ref.watch(isMutualFollowProvider(widget.otherUsername));
    final isFollowing =
        ref.watch(isFollowingProvider(widget.otherUsername)).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.otherUsername,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1A1530),
            onSelected: (value) async {
              if (me == null) return;
              if (value == 'block') {
                if (isBlocked) {
                  await SocialRepository.unblockUser(me, widget.otherUsername);
                } else {
                  await SocialRepository.blockUser(me, widget.otherUsername);
                }
              } else if (value == 'report') {
                await showReportDialog(context,
                    targetType: ReportTargetType.user, targetId: widget.otherUsername);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'block',
                child: Text(isBlocked ? 'Desbloquear' : 'Bloquear',
                    style: const TextStyle(color: _kDanger)),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Text('Reportar', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ],
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
          Positioned(top: -60, right: -60, child: _chatOrb(200, _kPurple, 0.18)),
          Positioned(bottom: 160, left: -60, child: _chatOrb(160, _kCyan, 0.12)),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _conversationId == null
                      ? const Center(child: CircularProgressIndicator(color: _kPurple))
                      : Consumer(
                          builder: (context, ref, _) {
                            final messagesAsync = ref.watch(messagesProvider(_conversationId!));
                            return messagesAsync.when(
                              data: (messages) {
                                if (messages.isEmpty) {
                                  return Center(
                                    child: Text('Iniciá la conversación.',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                                  );
                                }
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (_scrollCtrl.hasClients) {
                                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                                  }
                                });
                                return ListView.builder(
                                  controller: _scrollCtrl,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = messages[index];
                                    final isMe = msg.senderId == me;
                                    return _MessageBubble(message: msg, isMe: isMe);
                                  },
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator(color: _kPurple)),
                              error: (_, __) => Center(
                                child: Text('Error al cargar mensajes.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                              ),
                            );
                          },
                        ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: _kDanger, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: _kDanger, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                if (isBlocked)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Hay un bloqueo activo entre vos y este usuario. No se pueden enviar mensajes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                    ),
                  )
                else if (!isMutual)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          isFollowing
                              ? 'Esperando a que ${widget.otherUsername} te siga de vuelta para poder chatear.'
                              : 'Para enviar mensajes, ambos deben seguirse. Seguí a ${widget.otherUsername} primero.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                        ),
                        if (!isFollowing) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: me == null
                                ? null
                                : () => SocialRepository.follow(me, widget.otherUsername),
                            child: const Text('Seguir', style: TextStyle(color: _kPurple)),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgCtrl,
                              style: const TextStyle(color: Colors.white),
                              maxLength: 4000,
                              minLines: 1,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: 'Escribí un mensaje...',
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
                            onPressed: _sending ? null : _send,
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? _kPurple.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
