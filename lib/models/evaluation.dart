import 'package:hive_flutter/hive_flutter.dart';
part 'evaluation.g.dart';

@HiveType(typeId: 0)
class Evaluation extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String subject;
  @HiveField(2)
  String type;
  @HiveField(3)
  DateTime date;
  @HiveField(4)
  int difficulty;
  @HiveField(5)
  double weight;
  @HiveField(6)
  String? notes;
  @HiveField(7)
  bool isCompleted;
  @HiveField(8)
  DateTime createdAt;

  Evaluation({
    required this.id,
    required this.subject,
    required this.type,
    required this.date,
    required this.difficulty,
    required this.weight,
    this.notes,
    this.isCompleted = false,
    required this.createdAt,
  });

  Evaluation copyWith({
    String? id,
    String? subject,
    String? type,
    DateTime? date,
    int? difficulty,
    double? weight,
    String? notes,
    bool? isCompleted,
    DateTime? createdAt,
  }) => Evaluation(
    id:          id          ?? this.id,
    subject:     subject     ?? this.subject,
    type:        type        ?? this.type,
    date:        date        ?? this.date,
    difficulty:  difficulty  ?? this.difficulty,
    weight:      weight      ?? this.weight,
    notes:       notes       ?? this.notes,
    isCompleted: isCompleted ?? this.isCompleted,
    createdAt:   createdAt   ?? this.createdAt,
  );

  int get daysUntil => date.difference(DateTime.now()).inDays;
  bool get isUrgent => daysUntil <= 3 && !isCompleted;

  String toPromptString() {
    final d = daysUntil;
    final when = d == 0 ? 'hoy' : d == 1 ? 'mañana' : 'en $d días';
    return '- $subject ($type): $when, dificultad $difficulty/5, peso ${weight.toStringAsFixed(0)}%';
  }
}