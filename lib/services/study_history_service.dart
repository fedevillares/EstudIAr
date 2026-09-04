import 'package:hive/hive.dart';

/// Histórico diario de minutos estudiados.
/// Guarda en una box Hive propia ('study_history'), una entrada por día:
///   clave = 'YYYY-MM-DD'  →  valor = minutos acumulados ese día.
class StudyHistoryService {
  StudyHistoryService._();

  static const _boxName = 'study_history';
  static Box? _box;

  /// Llamar una vez en main.dart, después de Hive.initFlutter().
  static Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
    }
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Suma minutos al día indicado (default: hoy).
  static Future<void> addMinutes(int minutes, {DateTime? day}) async {
    if (_box == null || minutes <= 0) return;
    final d = day ?? DateTime.now();
    final k = _key(d);
    final current = (_box!.get(k, defaultValue: 0) as int);
    await _box!.put(k, current + minutes);
  }

  static int minutesOn(DateTime day) {
    if (_box == null) return 0;
    return _box!.get(_key(day), defaultValue: 0) as int;
  }

  /// Últimos 7 días terminando HOY (índice 0 = hace 6 días, índice 6 = hoy).
  static List<DayProgress> lastWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return DayProgress(
        date: day,
        minutes: minutesOn(day),
        isToday: i == 6,
      );
    });
  }

  static int get weekTotalMinutes =>
      lastWeek().fold<int>(0, (acc, d) => acc + d.minutes);
}

/// Dato de un día para el gráfico.
class DayProgress {
  final DateTime date;
  final int minutes;
  final bool isToday;

  const DayProgress({
    required this.date,
    required this.minutes,
    required this.isToday,
  });

  /// Inicial del día en español: L M M J V S D
  String get weekdayInitial {
    const initials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return initials[date.weekday - 1];
  }
}