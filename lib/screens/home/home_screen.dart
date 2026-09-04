import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/social_providers.dart';
import '../../widgets/evaluation_card.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/weekly_progress_chart.dart';
import '../../widgets/offline_banner.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/streak_service.dart';
import '../../models/evaluation.dart';
import '../evaluation/add_evaluation_screen.dart';
import '../../core/auth/local_auth_service.dart';
import '../../core/security/secure_storage_service.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/admin_panel_screen.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan   = Color(0xFF06B6D4);
const _kGrad   = LinearGradient(colors: [_kPurple, _kCyan]);
const _kDanger = Color(0xFFEF4444);
const _kSuccess= Color(0xFF00B894);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _streakCtrl;
  late Animation<double> _streakScale;

  @override
  void initState() {
    super.initState();
    _streakCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _streakScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _streakCtrl, curve: Curves.easeOutBack));
    _streakCtrl.forward();
  }

  @override
  void dispose() { _streakCtrl.dispose(); super.dispose(); }

  // ── Navegación al panel de admin ──────────────────────────────
  void _goToAdminPanel() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const AdminPanelScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pending  = ref.watch(pendingEvaluationsProvider);
    final urgent   = ref.watch(urgentEvaluationsProvider);
    // select() limita el rebuild al cambio real de la lista de completadas,
    // evitando reconstruir por cambios en pendientes/urgentes que no afectan
    // esta sección (aunque Riverpod ya los batchea en el mismo frame).
    final completed = ref.watch(evaluationsProvider.select((async) =>
        async.maybeWhen(
          data: (list) => list.where((e) => e.isCompleted).toList(),
          orElse: () => <Evaluation>[],
        )));
    final streak = StreakService.streak;
    final phrase = StreakService.todayPhrase;
    final isAdmin = LocalAuthService.isCurrentUserAdmin();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [_kPurple, _kCyan]),
            boxShadow: [BoxShadow(color: _kPurple.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: FloatingActionButton.extended(
            heroTag: 'fab_home',
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AddEvaluationScreen(),
              ));
            },
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Nueva evaluación', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0D0520), Color(0xFF080D1C), Color(0xFF000000)],
              ),
            ),
          )),
          Positioned(top: -80, right: -60, child: _orb(260, _kPurple, 0.22)),
          Positioned(top: 120, left: -80,  child: _orb(220, _kCyan,   0.15)),
          Positioned(bottom: 220, right: -40, child: _orb(180, _kCyan, 0.10)),

          SafeArea(
            child: Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  child: CustomScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Fila de accesos rápidos (racha/admin/settings): chica y
                              // alineada a la derecha, separada del título para que el
                              // título quede realmente centrado en todo el ancho (antes
                              // competía por espacio con estos íconos en el mismo Row).
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (streak > 0)
                                    ScaleTransition(
                                      scale: _streakScale,
                                      child: GlassCard(
                                        opacity: 0.08,
                                        borderRadius: BorderRadius.circular(10),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Row(children: [
                                          const Text('🔥', style: TextStyle(fontSize: 13)),
                                          const SizedBox(width: 3),
                                          Text('$streak', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ]),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  // ── Ícono admin ──────────────
                                  if (isAdmin) ...[
                                    GlassCard(
                                      opacity: 0.08,
                                      borderRadius: BorderRadius.circular(10),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        iconSize: 16,
                                        icon: Icon(Icons.admin_panel_settings_outlined, color: _kCyan.withValues(alpha: 0.9)),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          _goToAdminPanel();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  // ── Ícono settings ───────────
                                  GlassCard(
                                    opacity: 0.08,
                                    borderRadius: BorderRadius.circular(10),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      iconSize: 16,
                                      icon: Icon(Icons.settings_outlined, color: Colors.white.withValues(alpha: 0.8)),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        _showSettings(context);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ShaderMask(
                                shaderCallback: (b) => _kGrad.createShader(b),
                                child: const Text('EstudIAr',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                              ),
                              Text(_greeting,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.45))),
                              const SizedBox(height: 20),
                              GlassCard(
                                opacity: 0.06,
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                  const Text('✨', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Flexible(child: Text(phrase,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6), height: 1.4, fontStyle: FontStyle.italic))),
                                ]),
                              ),
                              const SizedBox(height: 20),
                              Row(children: [
                                _StatCard(label: 'Pendientes', value: '${pending.length}',   icon: Icons.pending_actions_rounded,      color: _kPurple),
                                const SizedBox(width: 10),
                                _StatCard(label: 'Urgentes',   value: '${urgent.length}',    icon: Icons.warning_amber_rounded,        color: urgent.isEmpty ? _kSuccess : _kDanger),
                                const SizedBox(width: 10),
                                _StatCard(label: 'Listas',     value: '${completed.length}', icon: Icons.check_circle_outline_rounded, color: _kSuccess),
                              ]),
                              const SizedBox(height: 20),
                              GlassCard(
                                opacity: 0.06,
                                padding: const EdgeInsets.all(16),
                                child: const WeeklyProgressChart(),
                              ),
                              const SizedBox(height: 28),
                              if (urgent.isNotEmpty) ...[
                                GlassCard(
                                  opacity: 0.08,
                                  color: _kDanger,
                                  padding: const EdgeInsets.all(14),
                                  child: Row(children: [
                                    const Text('⚠️', style: TextStyle(fontSize: 20)),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('¡Atención!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                        Text('${urgent.first.subject} es en ${urgent.first.daysUntil == 0 ? 'hoy' : '${urgent.first.daysUntil} días'}',
                                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                                      ],
                                    )),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: _kDanger.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                                      child: Text(urgent.first.type, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ]),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                Text('Próximas evaluaciones',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
                                if (pending.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text('${pending.length} pendiente${pending.length == 1 ? '' : 's'}',
                                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.35))),
                                ],
                              ]),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),

                      if (pending.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                            child: GlassCard(
                              opacity: 0.06,
                              padding: const EdgeInsets.all(36),
                              child: Column(children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(color: _kPurple.withValues(alpha: 0.12), shape: BoxShape.circle),
                                  child: Icon(Icons.school_outlined, size: 44, color: _kPurple.withValues(alpha: 0.7)),
                                ),
                                const SizedBox(height: 16),
                                Text('No hay evaluaciones', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text('Tocá el + para agregar una', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
                              ]),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: EvaluationCard(
                                  evaluation: pending[i],
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => AddEvaluationScreen(evaluationId: pending[i].id),
                                    ));
                                  },
                                  onComplete: () {
                                    HapticFeedback.mediumImpact();
                                    ref.read(evaluationsProvider.notifier).toggleComplete(pending[i].id);
                                    StreakService.registerStudyDay();
                                  },
                                  onDelete: () {
                                    HapticFeedback.heavyImpact();
                                    ref.read(evaluationsProvider.notifier).delete(pending[i].id);
                                  },
                                ),
                              ),
                              childCount: pending.length,
                            ),
                          ),
                        ),

                      if (completed.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                            child: Center(
                              child: Text('Completadas ✓', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.4))),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: EvaluationCard(
                                  evaluation: completed[i],
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => AddEvaluationScreen(evaluationId: completed[i].id),
                                    ));
                                  },
                                  onComplete: () {
                                    HapticFeedback.mediumImpact();
                                    ref.read(evaluationsProvider.notifier).toggleComplete(completed[i].id);
                                  },
                                  onDelete: () {
                                    HapticFeedback.heavyImpact();
                                    ref.read(evaluationsProvider.notifier).delete(completed[i].id);
                                  },
                                ),
                              ),
                              childCount: completed.length,
                            ),
                          ),
                        ),
                      ] else
                        const SliverToBoxAdapter(child: SizedBox(height: 160)),
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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días 👋';
    if (h < 18) return 'Buenas tardes 👋';
    return 'Buenas noches 👋';
  }

  void _showSettings(BuildContext context) async {
    int hours = StorageService.hoursPerDay;
    bool reminders = NotificationService.remindersEnabled;
    String frequency = NotificationService.reminderFrequency;
    final apiKeyCtrl = TextEditingController(text: await SecureStorageService.getApiKey() ?? '');
    bool obscureKey = true;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: const Color(0xFF1A1025),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Text('Configuración', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sLabel('Horas de estudio por día: $hours h'),
                Slider(
                  value: hours.toDouble(), min: 1, max: 8, divisions: 7, label: '$hours h',
                  activeColor: _kPurple, inactiveColor: Colors.white.withValues(alpha: 0.15),
                  onChanged: (v) => set(() => hours = v.round()),
                ),
                _sHint('La IA usará este límite al armar tu plan'),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _sLabel('Recordatorios'),
                  Switch(value: reminders, activeThumbColor: _kPurple, onChanged: (v) => set(() => reminders = v)),
                ]),
                if (reminders) ...[
                  const SizedBox(height: 8),
                  _sLabel('Frecuencia'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    dropdownColor: const Color(0xFF1A1025),
                    style: const TextStyle(color: Colors.white),
                    decoration: _sDeco(''),
                    items: const [
                      DropdownMenuItem(value: 'hourly', child: Text('Cada hora')),
                      DropdownMenuItem(value: 'daily',  child: Text('Una vez al día')),
                      DropdownMenuItem(value: 'weekly', child: Text('Una vez a la semana')),
                    ],
                    onChanged: (v) => set(() => frequency = v ?? 'daily'),
                  ),
                ],
                const SizedBox(height: 4),
                _sHint(reminders ? 'Recordatorios activos' : 'Sin recordatorios'),
                const SizedBox(height: 20),
                _sLabel('API key de Groq (IA)'),
                const SizedBox(height: 6),
                TextField(
                  controller: apiKeyCtrl,
                  obscureText: obscureKey,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _sDeco('gsk_...').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      onPressed: () => set(() => obscureKey = !obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _sHint('Opcional: si la dejás vacía, se usa la IA compartida configurada por el administrador (con un límite diario). Cargá tu propia key acá si querés usar la tuya sin límite.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await LocalAuthService.logout();
                ref.invalidate(currentUsernameProvider);
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 400),
                      pageBuilder: (_, __, ___) => const LoginScreen(),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                    ),
                    (route) => false,
                  );
                }
              },
              child: const Text('Cerrar sesión', style: TextStyle(color: _kDanger)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [_kPurple, _kCyan]),
              ),
              child: FilledButton(
                onPressed: () async {
                  StorageService.setHoursPerDay(hours);
                  NotificationService.setRemindersEnabled(reminders);
                  NotificationService.setReminderFrequency(frequency);
                  await NotificationService.scheduleReminder();
                  await SecureStorageService.setApiKey(apiKeyCtrl.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sLabel(String t) => Text(t, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white.withValues(alpha: 0.7)));
  Widget _sHint(String t)  => Text(t, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)));
  InputDecoration _sDeco(String hint) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
    isDense: true, filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      child: GlassCard(
        opacity: 0.07,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.45)), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1),
        ]),
      ),
    ),
  );
}

Widget _orb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);