import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isModerated; // true si fue bloqueado por moderación (no debería persistirse, pero por si acaso)

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.readAt,
    this.isModerated = false,
  });

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'content': content,
        'createdAt': Timestamp.fromDate(createdAt),
        'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
        'isModerated': isModerated,
      };

  factory ChatMessage.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, String conversationId) {
    final data = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      conversationId: conversationId,
      senderId: data['senderId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      isModerated: data['isModerated'] as bool? ?? false,
    );
  }
}

class Conversation {
  final String id; // formato: "usuarioA_usuarioB" (orden alfabético)
  final List<String> participants;
  final String? lastMessage;
  final String? lastSenderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int> unreadCounts; // username -> cantidad no leídos

  const Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastSenderId,
    required this.createdAt,
    required this.updatedAt,
    this.unreadCounts = const {},
  });

  static String buildId(String userA, String userB) {
    final sorted = [userA, userB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  String otherParticipant(String me) =>
      participants.firstWhere((p) => p != me, orElse: () => me);

  int unreadFor(String username) => unreadCounts[username] ?? 0;

  // 'createdAt' es requerido acá porque firestore.rules exige ese campo
  // en la creación del documento de conversación
  // (`allow create: if ... .hasAll(['participants', 'createdAt'])`);
  // si se omite, Firestore rechaza la creación con permission-denied y
  // el usuario no puede iniciar conversaciones nuevas.
  Map<String, dynamic> toMap() => {
        'participants': participants,
        'lastMessage': lastMessage,
        'lastSenderId': lastSenderId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'unreadCounts': unreadCounts,
      };

  factory Conversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawUnread = data['unreadCounts'] as Map<String, dynamic>? ?? {};
    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] as List? ?? []),
      lastMessage: data['lastMessage'] as String?,
      lastSenderId: data['lastSenderId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCounts: rawUnread.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}
