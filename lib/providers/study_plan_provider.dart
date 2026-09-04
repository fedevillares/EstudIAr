import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/evaluation.dart';
import '../models/study_plan.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/connectivity_service.dart';

enum PlanStatus { idle, loading, error, success }

class PlanState {
  final PlanStatus status;
  final StudyPlan? plan;
  final String? error;
  final int hoursPerDay;
  final bool exceedsLimit; // true si el plan generado supera el límite diario

  const PlanState({
    this.status = PlanStatus.idle,
    this.plan,
    this.error,
    this.hoursPerDay = 0,
    this.exceedsLimit = false,
  });

  PlanState copyWith({
    PlanStatus? status,
    StudyPlan? plan,
    String? error,
    int? hoursPerDay,
    bool? exceedsLimit,
  }) =>
      PlanState(
        status: status ?? this.status,
        plan: plan ?? this.plan,
        error: error ?? this.error,
        hoursPerDay: hoursPerDay ?? this.hoursPerDay,
        exceedsLimit: exceedsLimit ?? this.exceedsLimit,
      );
}

class StudyPlanNotifier extends Notifier<PlanState> {
  static const int _maxRetries = 2;

  @override
  PlanState build() => const PlanState();

  Future<void> generate(List<Evaluation> evaluations) async {
    final hours = StorageService.hoursPerDay;
    state = PlanState(status: PlanStatus.loading, hoursPerDay: hours);

    // Chequeo offline antes de gastar la llamada a la IA.
    final online = await ConnectivityService.isOnline();
    if (!online) {
      state = PlanState(
        status: PlanStatus.error,
        error: 'Necesitás conexión a internet para generar el plan.',
        hoursPerDay: hours,
      );
      return;
    }

    Object? lastError;

    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final raw = await AIService.generateStudyPlan(
          pending: evaluations,
          hoursPerDay: hours,
        );

        final jsonStr = _extractJson(raw);
        if (jsonStr == null) {
          throw const FormatException(
              'La respuesta de la IA no contiene un JSON válido.');
        }

        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('JSON raíz inesperado (no es objeto).');
        }

        final plan = StudyPlan.fromJson(decoded);
        final exceeds = !plan.respectsLimit(hours);

        state = PlanState(
          status: PlanStatus.success,
          plan: plan,
          hoursPerDay: hours,
          exceedsLimit: exceeds,
        );
        return;
      } catch (e) {
        lastError = e;
        // Reintento solo si quedan intentos. Backoff suave.
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
        }
      }
    }

    state = PlanState(
      status: PlanStatus.error,
      error: _humanizeError(lastError),
      hoursPerDay: hours,
    );
  }

  /// Limpia markdown / texto extra y devuelve el bloque JSON balanceado.
  /// Si no encuentra un JSON razonable, retorna null.
  String? _extractJson(String raw) {
    var s = raw.trim();

    // Eliminar fences de markdown (```json ... ``` o ``` ... ```)
    s = s.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('```', '').trim();

    // Encontrar primer '{' y emparejar llaves para obtener objeto balanceado.
    final start = s.indexOf('{');
    if (start == -1) return null;

    var depth = 0;
    var inString = false;
    var escape = false;
    int? end;

    for (var i = start; i < s.length; i++) {
      final ch = s[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (ch == r'\') {
        escape = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }

    if (end == null) return null;
    return s.substring(start, end + 1);
  }

  String _humanizeError(Object? e) {
    if (e == null) return 'Ocurrió un error desconocido al generar el plan.';
    if (e is MissingApiKeyException) return e.message;
    if (e is UsageLimitExceededException) return e.message;
    if (e is AccountIssueException) return e.message;
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
      return 'Sin conexión a internet. Revisá tu red e intentá de nuevo.';
    }
    if (msg.contains('401') || msg.contains('403')) {
      return 'API key inválida o sin permisos. Verificá la configuración.';
    }
    if (msg.contains('429')) {
      return 'La IA recibió demasiadas solicitudes. Esperá unos segundos y probá de nuevo.';
    }
    if (msg.contains('FormatException') || msg.contains('JSON')) {
      return 'La IA devolvió una respuesta con formato inválido. Intentá nuevamente.';
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return 'El servicio de IA está temporalmente caído. Probá en un rato.';
    }
    // No exponer el mensaje crudo (puede incluir stack traces o paths).
    return 'No se pudo generar el plan. Intentá de nuevo en unos segundos.';
  }

  void clear() => state = const PlanState();
}

final studyPlanProvider =
    NotifierProvider<StudyPlanNotifier, PlanState>(StudyPlanNotifier.new);