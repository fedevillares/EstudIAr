import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/repositories/social_repository.dart';
import '../../providers/social_providers.dart';
import 'chat_screen.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);

// Carácter Unicode más alto del rango BMP (punto de código 0xF8FF), usado
// como tope superior en búsquedas de prefijo con Firestore: cualquier
// string que empiece con "trimmed" es lexicográficamente menor a
// "trimmed" + este carácter, así que cierra el rango sin excluir
// coincidencias. Sin esto, endAt([trimmed]) solo matchea el username
// EXACTO y la búsqueda por prefijo nunca encuentra resultados parciales.
final String _kPrefixUpperBound = String.fromCharCode(0xF8FF);

Widget _newConvOrb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);

class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({super.key});
  @override
  ConsumerState<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  final _searchCtrl = TextEditingController();
  List<String> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  Future<void> _search(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final me = ref.read(currentUsernameProvider);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('username')
          .startAt([trimmed])
          .endAt(['$trimmed$_kPrefixUpperBound'])
          .limit(20)
          .get();
      if (!mounted) return;
      setState(() {
        _results = snapshot.docs.map((d) => d.id).where((u) => u != me).toList();
        _loading = false;
        _searched = true;
      });
    } catch (e) {
      // Antes esto tragaba el error real (p.ej. permission-denied por
      // firestore.rules, o failed-precondition por falta de índice) y solo
      // mostraba un mensaje genérico — sin poder diagnosticar por qué
      // fallaba la búsqueda. Mostrar el error real permite ver la causa
      // exacta la próxima vez que se reproduzca.
      debugPrint('[chat] Error buscando usuarios ("$trimmed"): $e');
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
        _searched = true;
        _error = 'No se pudo buscar: $e';
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Nueva conversación', style: TextStyle(color: Colors.white)),
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
          Positioned(top: -60, right: -60, child: _newConvOrb(200, _kPurple, 0.18)),
          Positioned(bottom: 120, left: -60, child: _newConvOrb(160, _kCyan, 0.12)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: 'Buscar usuario...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: CircularProgressIndicator(color: _kPurple),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                  ),
                if (!_loading && _searched && _results.isEmpty && _error == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Text(
                      'No se encontraron usuarios con ese nombre.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final u = _results[index];
                      // Cada fila necesita reaccionar a SU propio estado de
                      // seguimiento (independiente del resto de la lista),
                      // por eso va en un Consumer propio en vez de watchear
                      // en el build de toda la pantalla.
                      return Consumer(
                        builder: (context, ref, _) {
                          final me = ref.watch(currentUsernameProvider);
                          final isFollowing =
                              ref.watch(isFollowingProvider(u)).valueOrNull ?? false;
                          final isMutual = ref.watch(isMutualFollowProvider(u));

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _kPurple.withValues(alpha: 0.25),
                              child: Text(
                                u.isNotEmpty ? u[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(u,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              isMutual
                                  ? 'Se siguen mutuamente'
                                  : isFollowing
                                      ? 'Esperando a que te siga de vuelta'
                                      : 'Seguilo para poder enviarle mensajes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isMutual
                                    ? const Color(0xFF00B894)
                                    : Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                            trailing: me == null
                                ? null
                                : TextButton(
                                    onPressed: () async {
                                      if (isFollowing) {
                                        await SocialRepository.unfollow(me, u);
                                      } else {
                                        await SocialRepository.follow(me, u);
                                      }
                                    },
                                    child: Text(
                                      isFollowing ? 'Siguiendo' : 'Seguir',
                                      style: TextStyle(
                                        color: isFollowing ? Colors.white54 : _kPurple,
                                      ),
                                    ),
                                  ),
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => ChatScreen(otherUsername: u)),
                              );
                            },
                          );
                        },
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
