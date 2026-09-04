import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/social_providers.dart';
import '../../widgets/glass_card.dart';
import '../../utils/avatar_image.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);
const _kDanger = Color(0xFFEF4444);
const _maxBioLength = 200;
const _maxNameLength = 40;

Widget _editOrb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _pickingImage = false;
  String? _error;

  // Avatar: null = no se tocó (se conserva el actual al guardar).
  // '' = el usuario lo quitó explícitamente.
  // 'data:image/...;base64,...' = foto nueva elegida.
  String? _pendingAvatarUrl;
  String? _existingAvatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(currentUserProfileProvider.future);
    if (profile != null) {
      _nameCtrl.text = profile.displayName;
      _bioCtrl.text = profile.bio;
      _existingAvatarUrl = profile.avatarUrl;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  String? get _displayedAvatar =>
      _pendingAvatarUrl ?? _existingAvatarUrl;

  Future<void> _pickAvatar() async {
    setState(() => _pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Recorte aproximado: foto de perfil chica para que el Base64
        // resultante sea liviano (se guarda directo en Firestore, no hay
        // Storage configurado en este proyecto).
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 900 * 1024) {
        if (mounted) {
          setState(() => _error = 'La imagen es muy pesada. Probá con otra.');
        }
        return;
      }
      final b64 = base64Encode(bytes);
      final mime = _guessMime(picked.name, bytes);
      if (mounted) {
        setState(() {
          _pendingAvatarUrl = 'data:$mime;base64,$b64';
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la imagen.');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  String _guessMime(String filename, Uint8List bytes) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _removeAvatar() {
    setState(() {
      _pendingAvatarUrl = '';
      _existingAvatarUrl = null;
    });
  }

  Future<void> _save() async {
    final me = ref.read(currentUsernameProvider);
    if (me == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre no puede estar vacío.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final update = <String, dynamic>{
        'displayName': name,
        'bio': _bioCtrl.text.trim(),
      };
      // Solo tocamos avatarUrl si el usuario eligió/quitó una foto en esta
      // sesión de edición; si no, dejamos el valor existente intacto.
      if (_pendingAvatarUrl != null) {
        update['avatarUrl'] =
            _pendingAvatarUrl!.isEmpty ? null : _pendingAvatarUrl;
      }
      await FirebaseFirestore.instance.collection('users').doc(me).update(update);
      ref.invalidate(currentUserProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Editar perfil', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _kPurple))
                : const Text('Guardar', style: TextStyle(color: _kPurple, fontWeight: FontWeight.bold)),
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
          Positioned(top: -60, right: -60, child: _editOrb(200, _kPurple, 0.18)),
          Positioned(bottom: 120, left: -60, child: _editOrb(160, _kCyan, 0.12)),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: _kPurple))
          else
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(child: _AvatarPicker(
                    avatarUrl: _displayedAvatar,
                    displayName: _nameCtrl.text,
                    loading: _pickingImage,
                    onTap: _pickAvatar,
                    onRemove: (_displayedAvatar?.isNotEmpty ?? false) ? _removeAvatar : null,
                  )),
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nombre visible', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        TextField(
                          controller: _nameCtrl,
                          maxLength: _maxNameLength,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                          onChanged: (_) => setState(() {}),
                        ),
                        const Divider(color: Colors.white12),
                        const Text('Bio', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        TextField(
                          controller: _bioCtrl,
                          maxLength: _maxBioLength,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Contá algo sobre vos...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: const TextStyle(color: _kDanger, fontSize: 13)),
                        ],
                      ],
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

class _AvatarPicker extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final bool loading;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _AvatarPicker({
    required this.avatarUrl,
    required this.displayName,
    required this.loading,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final provider = avatarImageProvider(avatarUrl);
    return Column(
      children: [
        GestureDetector(
          onTap: loading ? null : onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
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
                  radius: 45,
                  backgroundColor: const Color(0xFF1A1025),
                  backgroundImage: provider,
                  child: provider == null
                      ? Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              if (loading)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _kPurple,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0D0520), width: 2.5),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: loading ? null : onTap,
          child: const Text('Cambiar foto', style: TextStyle(color: _kCyan, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        if (onRemove != null)
          TextButton(
            onPressed: loading ? null : onRemove,
            child: const Text('Quitar foto', style: TextStyle(color: _kDanger, fontSize: 12)),
          ),
      ],
    );
  }
}
