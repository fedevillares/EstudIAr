class FlashcardEngine {
  double _easiness = 2.5;
  int _repetitions = 0;
  int _interval = 1;
  DateTime? _nextReview;

  double get easiness => _easiness;
  int get repetitions => _repetitions;
  DateTime? get nextReview => _nextReview;

  FlashcardEngine({double? initialEasiness}) {
    if (initialEasiness != null && initialEasiness > 0) _easiness = initialEasiness;
  }

  void rate(int quality) {
    // quality: 0 (olvido) a 5 (dominio)
    if (quality < 0 || quality > 5) throw ArgumentError('Calificación inválida');
    
    if (quality < 3) {
      _repetitions = 0;
      _interval = 1;
    } else {
      _repetitions++;
      if (_repetitions == 1) { _interval = 1; }
      else if (_repetitions == 2) { _interval = 6; }
      else { _interval = (_interval * _easiness).round(); }
      _easiness = _easiness + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      if (_easiness < 1.3) _easiness = 1.3;
    }
    _nextReview = DateTime.now().add(Duration(days: _interval));
  }

  Map<String, dynamic> toData() => {
    'easiness': _easiness,
    'repetitions': _repetitions,
    'interval': _interval,
    'nextReview': _nextReview?.toIso8601String(),
  };

  static FlashcardEngine fromData(Map<String, dynamic> data) {
    final engine = FlashcardEngine(initialEasiness: data['easiness'] as double? ?? 2.5);
    engine._repetitions = (data['repetitions'] as num?)?.toInt() ?? 0;
    engine._interval = (data['interval'] as num?)?.toInt() ?? 1;
    engine._nextReview = DateTime.tryParse(data['nextReview'] as String? ?? '');
    return engine;
  }
}