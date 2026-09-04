import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/evaluation.dart';

abstract class IEvaluationRepository {
  Future<List<Evaluation>> getEvaluations();
  Future<void> addEvaluation(Evaluation evaluation);
  Future<void> updateEvaluation(Evaluation evaluation);
  Future<void> deleteEvaluation(String id);
  Future<void> toggleComplete(String id);
}

class HiveEvaluationRepository implements IEvaluationRepository {
  Box<Evaluation> get _box => Hive.box<Evaluation>('evaluations');

  @override
  Future<List<Evaluation>> getEvaluations() async {
    return _box.values.toList();
  }

  @override
  Future<void> addEvaluation(Evaluation evaluation) async {
    await _box.put(evaluation.id, evaluation);
  }

  @override
  Future<void> updateEvaluation(Evaluation evaluation) async {
    await _box.put(evaluation.id, evaluation);
  }

  @override
  Future<void> deleteEvaluation(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> toggleComplete(String id) async {
    final eval = _box.get(id);
    if (eval != null) {
      await _box.put(id, eval.copyWith(isCompleted: !eval.isCompleted));
    }
  }
}

final evaluationRepoProvider = Provider<IEvaluationRepository>((ref) {
  return HiveEvaluationRepository();
});