class StudySession {
  final String subject;
  final String task;
  final int durationMinutes;

  const StudySession({
    required this.subject,
    required this.task,
    required this.durationMinutes,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      subject: _readString(json['subject'], fallback: 'Materia'),
      task: _readString(json['task'], fallback: 'Estudiar'),
      durationMinutes: _readInt(
        json['duration_minutes'] ?? json['durationMinutes'],
        fallback: 30,
        min: 5,
        max: 240,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'task': task,
        'duration_minutes': durationMinutes,
      };

  static String _readString(dynamic v, {required String fallback}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static int _readInt(
    dynamic v, {
    required int fallback,
    int? min,
    int? max,
  }) {
    int result;
    if (v == null) {
      result = fallback;
    } else if (v is int) {
      result = v;
    } else if (v is double) {
      result = v.round();
    } else if (v is num) {
      result = v.round();
    } else {
      final parsed = int.tryParse(v.toString().trim()) ??
          double.tryParse(v.toString().trim())?.round();
      result = parsed ?? fallback;
    }
    if (min != null && result < min) result = min;
    if (max != null && result > max) result = max;
    return result;
  }
}

class StudyDay {
  final String date;
  final List<StudySession> sessions;

  const StudyDay({required this.date, required this.sessions});

  int get totalMinutes =>
      sessions.fold<int>(0, (acc, s) => acc + s.durationMinutes);

  DateTime? get dateTime {
    try {
      return DateTime.parse(date);
    } catch (_) {
      return null;
    }
  }

  factory StudyDay.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['sessions'];
    final List<StudySession> parsed;
    if (rawSessions is List) {
      parsed = rawSessions
          .whereType<Map>()
          .map((s) => StudySession.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    } else {
      parsed = const [];
    }
    return StudyDay(
      date: (json['date'] as String?)?.trim() ?? '',
      sessions: parsed,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };
}

class StudyPlan {
  final List<StudyDay> days;
  final String advice;
  final DateTime generatedAt;

  const StudyPlan({
    required this.days,
    required this.advice,
    required this.generatedAt,
  });

  int get totalMinutes =>
      days.fold<int>(0, (acc, d) => acc + d.totalMinutes);

  int get averageMinutesPerDay {
    if (days.isEmpty) return 0;
    final activeDays = days.where((d) => d.sessions.isNotEmpty).length;
    if (activeDays == 0) return 0;
    return (totalMinutes / activeDays).round();
  }

  bool respectsLimit(int hoursPerDay) {
    final max = hoursPerDay * 60;
    return days.every((d) => d.totalMinutes <= max);
  }

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final List<StudyDay> parsed;
    if (rawDays is List) {
      parsed = rawDays
          .whereType<Map>()
          .map((d) => StudyDay.fromJson(Map<String, dynamic>.from(d)))
          .toList();
    } else {
      parsed = const [];
    }
    return StudyPlan(
      days: parsed,
      advice: (json['advice'] as String?)?.trim() ?? '',
      generatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'days': days.map((d) => d.toJson()).toList(),
        'advice': advice,
        'generatedAt': generatedAt.toIso8601String(),
      };
}