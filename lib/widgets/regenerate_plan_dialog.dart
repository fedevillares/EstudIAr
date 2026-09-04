import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/evaluation.dart';
import '../providers/study_plan_provider.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);

/// Ofrece regenerar el plan cuando cambia el cronograma de evaluaciones.
/// Llamar después de editar/guardar una evaluación cuya FECHA cambió.
///
/// Uso:
///   await RegeneratePlanPrompt.maybeOffer(
///     context, ref,
///     evaluations: todasLasEvaluaciones,
///     dateChanged: true,
///   );
class RegeneratePlanPrompt {
  static Future<void> maybeOffer(
    BuildContext context,
    WidgetRef ref, {
    required List<Evaluation> evaluations,
    required bool dateChanged,
  }) async {
    if (!dateChanged || !context.mounted) return;

    final planState = ref.read(studyPlanProvider);
    // Solo ofrecemos si ya existe un plan generado.
    if (planState.plan == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF120A24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _kPurple.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kPurple, _kCyan]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.autorenew_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Cambió el cronograma',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Modificaste la fecha de una evaluación. '
                'Tu plan de estudio actual quedó desactualizado. '
                '¿Querés que lo regenere considerando el nuevo cronograma?',
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Ahora no',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Regenerar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && context.mounted) {
      await ref.read(studyPlanProvider.notifier).generate(evaluations);
    }
  }
}