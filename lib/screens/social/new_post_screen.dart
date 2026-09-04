import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/social_repository.dart';
import '../../providers/social_providers.dart';
import '../../widgets/glass_card.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);
const _kDanger = Color(0xFFEF4444);

Widget _orb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);

class NewPostScreen extends ConsumerStatefulWidget {
  const NewPostScreen({super.key});
  @override
  ConsumerState<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends ConsumerState<NewPostScreen> {
  final _contentCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  bool _sending = false;
  String? _error;

  static const _maxLength = 2000;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final me = ref.read(currentUsernameProvider);
    if (me == null) return;
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      setState(() => _error = 'Escribí algo para publicar.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final profile = await ref.read(currentUserProfileProvider.future);
      await SocialRepository.createPost(
        authorId: me,
        authorDisplayName: profile?.displayName ?? me,
        authorAvatarUrl: profile?.avatarUrl,
        content: content,
        subjectTag: _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } on ContentRejectedException catch (e) {
      if (mounted) setState(() => _error = e.reason);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo publicar. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Nueva publicación', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _sending ? null : _publish,
            child: _sending
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kPurple),
                  )
                : const Text('Publicar', style: TextStyle(color: _kPurple, fontWeight: FontWeight.bold)),
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
          Positioned(top: -60, right: -60, child: _orb(200, _kPurple, 0.18)),
          Positioned(bottom: 120, left: -60, child: _orb(160, _kCyan, 0.12)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _subjectCtrl,
                      style: const TextStyle(color: _kCyan, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Materia (opcional, ej: Matemática)',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        border: InputBorder.none,
                      ),
                      maxLength: 40,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                    const Divider(color: Colors.white12),
                    TextField(
                      controller: _contentCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLines: 10,
                      maxLength: _maxLength,
                      decoration: InputDecoration(
                        hintText: '¿Qué estás estudiando hoy?',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kDanger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: _kDanger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!, style: const TextStyle(color: _kDanger, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
