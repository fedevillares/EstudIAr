import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/social/message.dart';
import '../security/content_moderation_service.dart';
import 'social_repository.dart';

export 'moderation_exceptions.dart';

/// Repositorio de mensajería directa. Toda escritura de mensaje pasa
/// primero por [ContentModerationService] — no hay forma de enviar
/// un mensaje sin que pase por la revisión, ni desde la UI ni
/// reutilizando este repositorio desde otra pantalla.
class MessagingRepository {
  MessagingRepository._();
  static final _db = FirebaseFirestore.instance;
  static const _maxMessageLength = 4000;

  static Stream<List<Conversation>> watchConversations(String username) {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: username)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Conversation.fromDoc).toList());
  }

  static Stream<List<ChatMessage>> watchMessages(String conversationId,
      {int limit = 100}) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromDoc(d, conversationId)).toList());
  }

  static Future<Conversation> getOrCreateConversation(
      String userA, String userB) async {
    final id = Conversation.buildId(userA, userB);
    final ref = _db.collection('conversations').doc(id);
    final doc = await ref.get();
    if (doc.exists) return Conversation.fromDoc(doc);

    final now = DateTime.now();
    final conversation = Conversation(
      id: id,
      participants: [userA, userB],
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(conversation.toMap());
    return conversation;
  }

  /// Envía un mensaje tras pasar moderación y verificar que no haya
  /// bloqueo mutuo entre los participantes.
  static Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const ContentRejectedException('El mensaje no puede estar vacío.');
    }
    if (trimmed.length > _maxMessageLength) {
      throw const ContentRejectedException(
          'El mensaje supera el largo máximo permitido.');
    }

    final isBlocked =
        await SocialRepository.isBlockedEitherWay(senderId, receiverId);
    if (isBlocked) throw const BlockedUserException();

    // La UI de ChatScreen ya oculta el campo de texto si no hay seguimiento
    // mutuo, pero se revalida acá para que nadie pueda mandar mensajes no
    // solicitados reutilizando este método sin pasar por esa pantalla.
    final senderFollowsReceiver =
        await SocialRepository.watchIsFollowing(senderId, receiverId).first;
    final receiverFollowsSender =
        await SocialRepository.watchIsFollowing(receiverId, senderId).first;
    if (!senderFollowsReceiver || !receiverFollowsSender) {
      throw const ContentRejectedException(
          'Para enviar mensajes, ambos usuarios deben seguirse mutuamente.');
    }

    final moderation = await ContentModerationService.reviewDirectMessage(trimmed);
    if (!moderation.isAllowed) {
      throw ContentRejectedException(
          moderation.reason ?? 'Mensaje no permitido.');
    }

    final convRef = _db.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final message = ChatMessage(
      id: '',
      conversationId: conversationId,
      senderId: senderId,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    await _db.runTransaction((tx) async {
      final convDoc = await tx.get(convRef);
      final currentUnread = Map<String, dynamic>.from(
          convDoc.data()?['unreadCounts'] as Map<String, dynamic>? ?? {});
      final receiverUnread = (currentUnread[receiverId] as num?)?.toInt() ?? 0;
      currentUnread[receiverId] = receiverUnread + 1;

      tx.set(msgRef, message.toMap());
      tx.update(convRef, {
        'lastMessage': trimmed,
        'lastSenderId': senderId,
        'updatedAt': Timestamp.now(),
        'unreadCounts': currentUnread,
      });
    });
  }

  static Future<void> markAsRead(String conversationId, String username) async {
    final convRef = _db.collection('conversations').doc(conversationId);
    // Se usa FieldPath (no 'unreadCounts.$username' como string) porque si el
    // username tuviera un punto, Firestore interpretaría el string como una
    // ruta anidada adicional en vez de como el nombre literal del campo,
    // corrompiendo el mapa unreadCounts en lugar de resetear el contador.
    await convRef.update({
      FieldPath(['unreadCounts', username]): 0,
    });
  }

  static Future<void> deleteConversation(String conversationId) async {
    await _db.collection('conversations').doc(conversationId).delete();
  }

  /// Total de mensajes no leídos para badges de navegación.
  static Stream<int> watchTotalUnread(String username) {
    return watchConversations(username).map(
        (convs) => convs.fold<int>(0, (total, c) => total + c.unreadFor(username)));
  }
}
