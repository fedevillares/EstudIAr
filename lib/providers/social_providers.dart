import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/local_auth_service.dart';
import '../core/repositories/social_repository.dart';
import '../core/repositories/messaging_repository.dart';
import '../models/app_user.dart';
import '../models/social/post.dart';
import '../models/social/comment.dart';
import '../models/social/message.dart';

/// Username del usuario logueado (sync, vía Hive). Null si no hay sesión.
final currentUsernameProvider = Provider<String?>((ref) {
  return LocalAuthService.currentUsername();
});

/// Perfil completo del usuario logueado.
final currentUserProfileProvider = FutureProvider<AppUser?>((ref) async {
  return LocalAuthService.currentUser();
});

/// Estado en vivo de la cuenta logueada (false = deshabilitada o borrada
/// por un admin). MainShell escucha esto para forzar el cierre de sesión
/// sin esperar a que el usuario reabra la app o intente loguearse de nuevo.
final accountActiveProvider = StreamProvider<bool>((ref) {
  final me = ref.watch(currentUsernameProvider);
  if (me == null) return Stream.value(true);
  return LocalAuthService.watchAccountActive(me);
});

/// Feed principal de posts públicos.
final feedProvider = StreamProvider<List<Post>>((ref) {
  return SocialRepository.watchFeed();
});

/// Posts de un usuario específico (para su perfil).
final userPostsProvider =
    StreamProvider.autoDispose.family<List<Post>, String>((ref, username) {
  return SocialRepository.watchUserPosts(username);
});

/// Comentarios de un post.
final commentsProvider =
    StreamProvider.autoDispose.family<List<Comment>, String>((ref, postId) {
  return SocialRepository.watchComments(postId);
});

/// Si el usuario actual le dio like a un post.
final hasLikedProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, postId) {
  final me = ref.watch(currentUsernameProvider);
  if (me == null) return Stream.value(false);
  return SocialRepository.watchHasLiked(postId, me);
});

/// Si el usuario actual sigue a otro usuario.
final isFollowingProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, targetUsername) {
  final me = ref.watch(currentUsernameProvider);
  if (me == null) return Stream.value(false);
  return SocialRepository.watchIsFollowing(me, targetUsername);
});

final followersProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, username) {
  return SocialRepository.watchFollowers(username);
});

final followingProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, username) {
  return SocialRepository.watchFollowing(username);
});

/// Si el otro usuario me sigue a mí (necesario para calcular seguimiento
/// mutuo, ver [isMutualFollowProvider]).
final isFollowedByProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, targetUsername) {
  final me = ref.watch(currentUsernameProvider);
  if (me == null) return Stream.value(false);
  return SocialRepository.watchIsFollowing(targetUsername, me);
});

/// Seguimiento mutuo (yo lo sigo Y me sigue) entre el usuario actual y
/// [targetUsername]. Requisito para poder enviar mensajes directos: evita
/// que cualquiera le escriba a cualquiera sin conocerse, similar al
/// esquema de "solicitud de mensaje" de otras redes, simplificado acá a
/// "ambos se siguen".
final isMutualFollowProvider = Provider.autoDispose.family<bool, String>((ref, targetUsername) {
  final following = ref.watch(isFollowingProvider(targetUsername)).valueOrNull ?? false;
  final followedBy = ref.watch(isFollowedByProvider(targetUsername)).valueOrNull ?? false;
  return following && followedBy;
});

/// Si hay bloqueo (en cualquier dirección) entre el usuario actual y otro.
final isBlockedProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, targetUsername) {
  final me = ref.watch(currentUsernameProvider);
  if (me == null) return Stream.value(false);
  return SocialRepository.watchIsBlocked(me, targetUsername);
});

/// Conversaciones del usuario actual.
final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final me = ref.watch(currentUsernameProvider);
  if (me == null) return Stream.value(const []);
  return MessagingRepository.watchConversations(me);
});

/// Mensajes de una conversación puntual.
final messagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, conversationId) {
  return MessagingRepository.watchMessages(conversationId);
});

/// Total de mensajes no leídos (para badge en navegación).
final totalUnreadProvider = StreamProvider<int>((ref) {
  final me = ref.watch(currentUsernameProvider);
  if (me == null) return Stream.value(0);
  return MessagingRepository.watchTotalUnread(me);
});
