import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/evaluation.dart';
import '../core/repositories/evaluation_repository.dart';

class EvaluationsNotifier extends AsyncNotifier<List<Evaluation>> {
  @override
  Future<List<Evaluation>> build() async {
    final repo = ref.watch(evaluationRepoProvider);
    return await repo.getEvaluations();
  }

  Future<void> add(Evaluation e) async {
    final repo = ref.read(evaluationRepoProvider);
    await repo.addEvaluation(e);
    ref.invalidateSelf();
  }

  Future<void> updateEval(Evaluation e) async {
    final repo = ref.read(evaluationRepoProvider);
    await repo.updateEvaluation(e);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final repo = ref.read(evaluationRepoProvider);
    await repo.deleteEvaluation(id);
    ref.invalidateSelf();
  }

  Future<void> toggleComplete(String id) async {
    final repo = ref.read(evaluationRepoProvider);
    await repo.toggleComplete(id);
    ref.invalidateSelf();
  }

  Evaluation createNew({
    required String subject,
    required String type,
    required DateTime date,
    required int difficulty,
    required double weight,
    String? notes,
  }) =>
      Evaluation(
        id: const Uuid().v4(),
        subject: subject,
        type: type,
        date: date,
        difficulty: difficulty,
        weight: weight,
        notes: notes,
        createdAt: DateTime.now(),
      );
}

final evaluationsProvider =
    AsyncNotifierProvider<EvaluationsNotifier, List<Evaluation>>(
  EvaluationsNotifier.new,
);

final pendingEvaluationsProvider = Provider<List<Evaluation>>(
  (ref) {
    final asyncValue = ref.watch(evaluationsProvider);
    return asyncValue.maybeWhen(
      data: (list) => list.where((e) => !e.isCompleted).toList()
        ..sort((a, b) => a.date.compareTo(b.date)),
      orElse: () => [],
    );
  },
);

final urgentEvaluationsProvider = Provider<List<Evaluation>>(
  (ref) =>
      ref.watch(pendingEvaluationsProvider).where((e) => e.isUrgent).toList(),
);