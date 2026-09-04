import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/local_auth_service.dart';
import '../core/repositories/social_repository.dart';
import '../core/repositories/messaging_repository.dart';
import '../models/app_user.dart';
import '../models/social/post.dart';
import '../models/social/comment.dart';
import '../models/social/message.dart';

const _kPageSize = 20;

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

/// Feed principal de posts públicos, con paginación ("cargar más").
///
/// Combina la "cabeza" en vivo (stream con límite fijo, sigue reaccionando
/// a posts nuevos en tiempo real) con páginas más viejas cargadas una sola
/// vez vía [SocialRepository.fetchOlderPosts] cuando se llama a
/// [FeedNotifier.loadMore], deduplicadas por id de doc.
class FeedNotifier extends AsyncNotifier<List<Post>> {
  StreamSubscription<List<Post>>? _sub;
  List<Post> _head = const [];
  List<Post> _older = const [];
  bool _hasMore = true;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _loadingMore;

  @override
  Future<List<Post>> build() async {
    ref.onDispose(() => _sub?.cancel());
    final completer = Completer<List<Post>>();
    _sub = SocialRepository.watchFeed().listen((posts) {
      _head = posts;
      final merged = _merge();
      if (!completer.isCompleted) {
        completer.complete(merged);
      } else {
        state = AsyncData(merged);
      }
    }, onError: (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    });
    return completer.future;
  }

  List<Post> _merge() {
    final seen = <String>{};
    final merged = <Post>[];
    for (final p in _head) {
      if (seen.add(p.id)) merged.add(p);
    }
    for (final p in _older) {
      if (seen.add(p.id)) merged.add(p);
    }
    return merged;
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final current = state.valueOrNull ?? const [];
    if (current.isEmpty) return;
    _loadingMore = true;
    try {
      final fetched = await SocialRepository.fetchOlderPosts(
          before: current.last.createdAt, limit: _kPageSize);
      if (fetched.length < _kPageSize) _hasMore = false;
      _older = [..._older, ...fetched];
      state = AsyncData(_merge());
    } finally {
      _loadingMore = false;
    }
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, List<Post>>(FeedNotifier.new);

/// Posts de un usuario específico (para su perfil), con la misma paginación
/// que [feedProvider].
class UserPostsNotifier extends AutoDisposeFamilyAsyncNotifier<List<Post>, String> {
  StreamSubscription<List<Post>>? _sub;
  List<Post> _head = const [];
  List<Post> _older = const [];
  bool _hasMore = true;
  bool _loadingMore = false;
  late String _username;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _loadingMore;

  @override
  Future<List<Post>> build(String username) async {
    _username = username;
    ref.onDispose(() => _sub?.cancel());
    final completer = Completer<List<Post>>();
    _sub = SocialRepository.watchUserPosts(username).listen((posts) {
      _head = posts;
      final merged = _merge();
      if (!completer.isCompleted) {
        completer.complete(merged);
      } else {
        state = AsyncData(merged);
      }
    }, onError: (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    });
    return completer.future;
  }

  List<Post> _merge() {
    final seen = <String>{};
    final merged = <Post>[];
    for (final p in _head) {
      if (seen.add(p.id)) merged.add(p);
    }
    for (final p in _older) {
      if (seen.add(p.id)) merged.add(p);
    }
    return merged;
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final current = state.valueOrNull ?? const [];
    if (current.isEmpty) return;
    _loadingMore = true;
    try {
      final fetched = await SocialRepository.fetchOlderUserPosts(_username,
          before: current.last.createdAt, limit: _kPageSize);
      if (fetched.length < _kPageSize) _hasMore = false;
      _older = [..._older, ...fetched];
      state = AsyncData(_merge());
    } finally {
      _loadingMore = false;
    }
  }
}

final userPostsProvider =
    AsyncNotifierProvider.autoDispose.family<UserPostsNotifier, List<Post>, String>(
        UserPostsNotifier.new);

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

/// Conversaciones del usuario actual, con paginación ("cargar más") igual
/// que [feedProvider].
class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  StreamSubscription<List<Conversation>>? _sub;
  List<Conversation> _head = const [];
  List<Conversation> _older = const [];
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _me;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _loadingMore;

  @override
  Future<List<Conversation>> build() async {
    ref.onDispose(() => _sub?.cancel());
    _me = ref.watch(currentUsernameProvider);
    final me = _me;
    if (me == null) return const [];

    final completer = Completer<List<Conversation>>();
    _sub = MessagingRepository.watchConversations(me).listen((convs) {
      _head = convs;
      final merged = _merge();
      if (!completer.isCompleted) {
        completer.complete(merged);
      } else {
        state = AsyncData(merged);
      }
    }, onError: (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    });
    return completer.future;
  }

  List<Conversation> _merge() {
    final seen = <String>{};
    final merged = <Conversation>[];
    for (final c in _head) {
      if (seen.add(c.id)) merged.add(c);
    }
    for (final c in _older) {
      if (seen.add(c.id)) merged.add(c);
    }
    return merged;
  }

  Future<void> loadMore() async {
    final me = _me;
    if (_loadingMore || !_hasMore || me == null) return;
    final current = state.valueOrNull ?? const [];
    if (current.isEmpty) return;
    _loadingMore = true;
    try {
      final fetched = await MessagingRepository.fetchOlderConversations(me,
          before: current.last.updatedAt, limit: _kPageSize);
      if (fetched.length < _kPageSize) _hasMore = false;
      _older = [..._older, ...fetched];
      state = AsyncData(_merge());
    } finally {
      _loadingMore = false;
    }
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
        ConversationsNotifier.new);

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
