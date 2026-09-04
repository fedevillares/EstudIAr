import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/study_plan_provider.dart';
import '../../providers/evaluations_provider.dart';
import '../../models/study_plan.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pomodoro_widget.dart';
import '../../models/evaluation.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan   = Color(0xFF06B6D4);
const _kGrad   = LinearGradient(colors: [_kPurple, _kCyan]);
const _kDanger = Color(0xFFEF4444);

class StudyPlanScreen extends ConsumerWidget {
  const StudyPlanScreen({super.key});

  // Lee la lista de evaluaciones en el momento del tap, evitando un
  // ref.watch amplio que reconstruiría esta pantalla en cada cambio de
  // evaluaciones (que aquí solo importan al presionar "Generar").
  List<Evaluation> _readEvaluations(WidgetRef ref) =>
      ref.read(evaluationsProvider).maybeWhen(
        data: (list) => list,
        orElse: () => <Evaluation>[],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(studyPlanProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fondo oscuro
          Positioned.fill(child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0D0520), Color(0xFF080D1C), Color(0xFF000000)],
              ),
            ),
          )),
          // Orbes
          Positioned(top: -60, right: -50, child: _orb(200, _kPurple, 0.20)),
          Positioned(bottom: 200, left: -60, child: _orb(180, _kCyan, 0.12)),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ShaderMask(
                          shaderCallback: (b) => _kGrad.createShader(b),
                          child: const Text('Plan de estudio',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      // Pomodoro
                      GlassCard(
                        opacity: 0.08,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          icon: const Text('🍅', style: TextStyle(fontSize: 20)),
                          tooltip: 'Pomodoro',
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A1025),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                              ),
                              child: const PomodoroWidget(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (planState.status == PlanStatus.success)
                        GlassCard(
                          opacity: 0.08,
                          borderRadius: BorderRadius.circular(12),
                          child: IconButton(
                            icon: Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.8)),
                            tooltip: 'Regenerar',
                            onPressed: () => ref
                                .read(studyPlanProvider.notifier)
                                .generate(_readEvaluations(ref)),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (planState.status) {
                    PlanStatus.idle    => _IdleView(onGenerate: () => ref.read(studyPlanProvider.notifier).generate(_readEvaluations(ref))),
                    PlanStatus.loading => const _LoadingView(),
                    PlanStatus.error   => _ErrorView(message: planState.error ?? 'Error desconocido', onRetry: () => ref.read(studyPlanProvider.notifier).generate(_readEvaluations(ref))),
                    PlanStatus.success => _PlanView(plan: planState.plan!),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _orb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);

// ── Idle ──────────────────────────────────────────────────────────
class _IdleView extends StatelessWidget {
  final VoidCallback onGenerate;
  const _IdleView({required this.onGenerate});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassCard(
            opacity: 0.08,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0x33A855F7), Color(0x2206B6D4)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('✨', style: TextStyle(fontSize: 46)),
                ),
                const SizedBox(height: 20),
                const Text('Plan personalizado con IA',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text('La IA analiza tus evaluaciones y crea un cronograma día por día adaptado a vos.',
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.45), height: 1.5),
                  textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(colors: [_kPurple, _kCyan]),
                      boxShadow: [BoxShadow(color: _kPurple.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: FilledButton.icon(
                      onPressed: onGenerate,
                      icon: const Icon(Icons.auto_awesome, color: Colors.white),
                      label: const Text('Generar plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            opacity: 0.06,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('🍅', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pomodoro integrado', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                    Text('Tocá el 🍅 arriba para el temporizador', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Loading ───────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => Center(
    child: GlassCard(
      opacity: 0.08,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _kPurple),
          const SizedBox(height: 24),
          const Text('Generando tu plan...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Esto puede tardar unos segundos', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4))),
        ],
      ),
    ),
  );
}

// ── Error ─────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        opacity: 0.08,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52, color: _kDanger),
            const SizedBox(height: 16),
            const Text('Algo salió mal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text(message, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Intentar de nuevo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPurple,
                side: BorderSide(color: _kPurple.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Plan View ─────────────────────────────────────────────────────
class _PlanView extends StatelessWidget {
  final StudyPlan plan;
  const _PlanView({required this.plan});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
    physics: const BouncingScrollPhysics(),
    children: [
      if (plan.advice.isNotEmpty) ...[
        GlassCard(
          opacity: 0.08,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(plan.advice, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7), height: 1.5))),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      ...plan.days.map((day) => _DayCard(day: day)),
    ],
  );
}

// ── Day Card ──────────────────────────────────────────────────────
class _DayCard extends StatelessWidget {
  final StudyDay day;
  const _DayCard({required this.day});
  @override
  Widget build(BuildContext context) {
    final totalH = day.totalMinutes / 60;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        opacity: 0.07,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del día
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x22A855F7), Color(0x1506B6D4)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      day.date,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${totalH.toStringAsFixed(1)} hs',
                      style: const TextStyle(fontSize: 13, color: _kPurple, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            // Sesiones
            ...day.sessions.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _kCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text('${s.durationMinutes}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kCyan)),
                              const Text('min', style: TextStyle(fontSize: 9, color: _kCyan)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(s.task, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45), height: 1.4)),
                          ],
                        )),
                      ],
                    ),
                  ),
                  if (i < day.sessions.length - 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                    ),
                ],
              );
            }),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}