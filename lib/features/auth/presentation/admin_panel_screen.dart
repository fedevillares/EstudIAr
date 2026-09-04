import 'package:flutter/material.dart';
import '../../../core/auth/local_auth_service.dart';
import '../../../core/security/shared_ai_key_service.dart';
import '../../../models/app_user.dart';
import '../../../widgets/glass_card.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan   = Color(0xFF06B6D4);
const _kSuccess = Color(0xFF00B894);
const _kDanger  = Color(0xFFE17055);

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late Future<List<AppUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    _usersFuture = LocalAuthService.getAllUsers();
  }

  void _refresh() {
    setState(() {
      _loadUsers();
    });
  }

  // Antes las acciones fallaban en silencio (Firestore permission-denied,
  // p.ej. por reglas no desplegadas) y el panel refrescaba igual, dando la
  // falsa impresión de que la acción funcionó. Ahora se avisa explícitamente.
  void _showActionError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _kDanger,
      ),
    );
  }

  Future<void> _showSharedAiKeyDialog() async {
    final ctrl = TextEditingController();
    bool obscure = true;
    bool saving = false;
    String? error;
    final hasKey = await SharedAiKeyService.hasSharedKey();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: const Color(0xFF1A1530),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('IA compartida (Groq)',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasKey
                    ? 'Ya hay una key compartida configurada. Pegá una nueva acá para reemplazarla.'
                    : 'Todavía no configuraste la key compartida. Los usuarios sin API key propia en Ajustes no van a poder usar la IA hasta que la cargues.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'API key de Groq (gsk_...)',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    onPressed: () => set(() => obscure = !obscure),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Se guarda cifrada en Firestore, nunca en texto plano. '
                'Solo se descifra en memoria al momento de llamar a la IA.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: _kDanger)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kPurple),
              onPressed: saving
                  ? null
                  : () async {
                      final value = ctrl.text.trim();
                      if (value.isEmpty) {
                        set(() => error = 'Pegá la API key antes de guardar.');
                        return;
                      }
                      set(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await SharedAiKeyService.setSharedKey(value);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                        set(() {
                          saving = false;
                          error = 'No se pudo guardar la key. Probá de nuevo.';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAiLimitDialog(AppUser user) async {
    final ctrl = TextEditingController(
        text: user.aiUsageLimit > 0 ? user.aiUsageLimit.toString() : '');
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: const Color(0xFF1A1530),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Límite de IA — ${user.username}',
              style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Llamadas a la IA por día',
                  hintText: '0 = sin límite',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Se cuenta cada vez que el usuario le pide algo a la IA '
                '(plan de estudio, resumen, flashcards, chat, examen). '
                'El contador se reinicia cada 24 horas.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: _kDanger)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kPurple),
              onPressed: () async {
                final raw = ctrl.text.trim();
                final limit = raw.isEmpty ? 0 : int.tryParse(raw);
                if (limit == null || limit < 0) {
                  set(() => error = 'Ingresá un número válido (0 o mayor).');
                  return;
                }
                final ok =
                    await LocalAuthService.setAiUsageLimit(user.username, limit);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!mounted) return;
                if (!ok) {
                  _showActionError('No se pudo guardar el límite de IA.');
                }
                _refresh();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateUserDialog() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isAdmin = false;
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: const Color(0xFF1A1530),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Nuevo usuario',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: isAdmin,
                    activeColor: _kPurple,
                    onChanged: (v) =>
                        set(() => isAdmin = v ?? false),
                  ),
                  const Text('Es administrador',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: _kDanger)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kPurple),
              onPressed: () async {
                final username = userCtrl.text.trim();
                final password = passCtrl.text;
                if (username.isEmpty || password.length < 6) {
                  set(() => error =
                      'Usuario requerido y contraseña de al menos 6 caracteres.');
                  return;
                }
                final ok = await LocalAuthService.createUser(
                  username: username,
                  password: password,
                  isAdmin: isAdmin,
                );
                if (!ok) {
                  set(() => error = 'Ese usuario ya existe.');
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) _refresh();
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) =>
              const LinearGradient(colors: [_kPurple, _kCyan])
                  .createShader(bounds),
          child: const Text(
            'Panel de administración',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined, color: _kPurple),
            onPressed: _showSharedAiKeyDialog,
            tooltip: 'Configurar IA compartida',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _kCyan),
            onPressed: _refresh,
            tooltip: 'Recargar usuarios',
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
                  colors: [
                    Color(0xFF0D0520),
                    Color(0xFF080D1C),
                    Color(0xFF000000),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<List<AppUser>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _kPurple),
                  );
                }

                final users = snapshot.data ?? [];

                if (users.isEmpty) {
                  return const Center(
                    child: Text('No hay usuarios.',
                        style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        user.username,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (user.isAdmin) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _kCyan.withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'ADMIN',
                                            style: TextStyle(
                                              color: _kCyan,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: user.isActive,
                                  activeThumbColor: _kSuccess,
                                  onChanged: user.isAdmin
                                      ? null
                                      : (_) async {
                                          final ok = await LocalAuthService
                                              .toggleActive(user.username);
                                          if (!mounted) return;
                                          if (!ok) {
                                            _showActionError(
                                                'No se pudo cambiar el estado del usuario.');
                                          }
                                          _refresh();
                                        },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.isActive ? 'Activo' : 'Deshabilitado',
                              style: TextStyle(
                                color:
                                    user.isActive ? _kSuccess : _kDanger,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.deviceId == null || user.deviceId!.isEmpty
                                  ? 'Sin dispositivo vinculado'
                                  : 'Dispositivo vinculado',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.aiUsageLimit > 0
                                  ? 'Límite IA: ${user.aiUsageCount}/${user.aiUsageLimit} hoy'
                                  : 'Límite IA: sin límite',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (user.deviceId != null &&
                                    user.deviceId!.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () async {
                                      final ok = await LocalAuthService
                                          .resetDevice(user.username);
                                      if (!mounted) return;
                                      if (!ok) {
                                        _showActionError(
                                            'No se pudo resetear el dispositivo.');
                                      }
                                      _refresh();
                                    },
                                    icon: const Icon(Icons.phonelink_erase,
                                        size: 18, color: _kCyan),
                                    label: const Text(
                                      'Resetear dispositivo',
                                      style: TextStyle(color: _kCyan),
                                    ),
                                  ),
                                TextButton.icon(
                                  onPressed: () => _showAiLimitDialog(user),
                                  icon: const Icon(Icons.smart_toy_outlined,
                                      size: 18, color: _kPurple),
                                  label: const Text(
                                    'Límite IA',
                                    style: TextStyle(color: _kPurple),
                                  ),
                                ),
                                const Spacer(),
                                if (!user.isAdmin)
                                  TextButton.icon(
                                    onPressed: () async {
                                      final ok = await LocalAuthService
                                          .deleteUser(user.username);
                                      if (!mounted) return;
                                      if (!ok) {
                                        _showActionError(
                                            'No se pudo eliminar el usuario (revisá las reglas de Firestore).');
                                      }
                                      _refresh();
                                    },
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: _kDanger),
                                    label: const Text(
                                      'Eliminar',
                                      style: TextStyle(color: _kDanger),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kPurple,
        onPressed: _showCreateUserDialog,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}