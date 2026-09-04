import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/study_history_service.dart';

/// Notifier reactivo del histórico semanal.
/// Llamá a `recordMinutes` al completar una sesión para refrescar el gráfico.
class StudyHistoryNotifier extends Notifier<List<DayProgress>> {
  @override
  List<DayProgress> build() => StudyHistoryService.lastWeek();

  Future<void> recordMinutes(int minutes) async {
    await StudyHistoryService.addMinutes(minutes);
    state = StudyHistoryService.lastWeek();
  }

  void refresh() => state = StudyHistoryService.lastWeek();
}

final studyHistoryProvider =
    NotifierProvider<StudyHistoryNotifier, List<DayProgress>>(
  StudyHistoryNotifier.new,
);

/// Total de minutos de la semana (derivado).
final weekTotalMinutesProvider = Provider<int>((ref) {
  final days = ref.watch(studyHistoryProvider);
  return days.fold<int>(0, (acc, d) => acc + d.minutes);
});