import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'ai_service.dart';

class StreakService {
  static Box get _box => Hive.box('settings');

  // ── Streak ────────────────────────────────────────────────────────

  static int get streak => _box.get('streak', defaultValue: 0) as int;

  static DateTime? get lastStudyDate {
    final s = _box.get('lastStudyDate') as String?;
    return s != null ? DateTime.parse(s) : null;
  }

  static void registerStudyDay() {
    final now = DateTime.now();
    final last = lastStudyDate;
    if (last == null) {
      _box.put('streak', 1);
    } else {
      final diff = now.difference(last).inDays;
      if (diff == 0) return;
      _box.put('streak', diff == 1 ? streak + 1 : 1);
    }
    _box.put('lastStudyDate', now.toIso8601String());
  }

  static bool get studiedToday {
    final last = lastStudyDate;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  // ── Frases ────────────────────────────────────────────────────────

  // Pool de 25 frases — se usa cuando no hay frase de IA disponible
  static const List<String> _fallback = [
    'El éxito es la suma de pequeños esfuerzos diarios 💪',
    'No estudies para el examen, estudiá para tu futuro 🚀',
    'Cada hora de estudio es una inversión en vos mismo ✨',
    'La disciplina es el puente entre tus metas y tus logros 🌟',
    'Hoy es un buen día para aprender algo nuevo 📚',
    'El conocimiento es el único tesoro que nadie te puede quitar 🏆',
    'Pequeños pasos todos los días llevan a grandes resultados 🔥',
    'Tu esfuerzo de hoy es tu orgullo de mañana 💡',
    'No importa lo lento que vayas, siempre que no te detengas 🐢',
    'La constancia vence al talento cuando el talento no es constante 🎯',
    'Cada vez que estudiás, le ganás al que no lo hizo 😤',
    'Un día a la vez, una página a la vez 📖',
    'El cerebro que estudia hoy descansa tranquilo mañana 🧠',
    'Convertí el esfuerzo de hoy en el éxito de mañana ⭐',
    'No es talento, es disciplina 🔑',
    'Arrancar es la mitad del trabajo 🏁',
    'Cada página que leés te acerca a donde querés llegar 📝',
    'La mente que estudia hoy duerme tranquila esta noche 😴',
    'No esperes el momento perfecto, crealo vos 🎯',
    'El que estudia hoy, celebra mañana 🎉',
    'Dale, que podés. Ya arrancaste lo más difícil 💫',
    'Cada esfuerzo suma, aunque no lo notes todavía 🌱',
    'Hoy estudiás, mañana brillás 🌟',
    'Un ratito más y después descansás. Vamos 💥',
    'La diferencia entre ordinario y extraordinario es ese esfuerzo extra 🦁',
  ];

  // Frase en memoria — se elige una vez por apertura de app
  static String _currentPhrase = '';
  static bool _isRefreshing = false;

  /// Llamar en SplashScreen. Elige frase nueva cada apertura:
  /// - Si hay una frase de IA guardada del arranque anterior → la usa
  /// - Si no → rota el fallback evitando repetir la última
  /// - En ambos casos, pide una nueva a la IA en background para la próxima vez
  static Future<void> initPhraseWithAi() async {
    final aiPhrase = _box.get('prefetchedAiPhrase') as String?;

    if (aiPhrase != null && aiPhrase.isNotEmpty) {
      _currentPhrase = aiPhrase;
      _box.delete('prefetchedAiPhrase'); // consumir, no reusar
      _box.put('lastPhrase', _currentPhrase);
    } else {
      _pickFallback();
    }

    // Pedir frase a la IA en background para la próxima apertura
    _prefetchAiPhrase();
  }

  static void _pickFallback() {
    final lastPhrase = _box.get('lastPhrase') as String? ?? '';
    // Índice basado en segundos actuales para variar entre aperturas
    final base = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % _fallback.length;
    int idx = base;
    // Evitar repetir la misma frase que la última vez
    if (_fallback[idx] == lastPhrase) {
      idx = (idx + 1) % _fallback.length;
    }
    _currentPhrase = _fallback[idx];
    _box.put('lastPhrase', _currentPhrase);
  }

  /// Devuelve la frase elegida al iniciar la app.
  static String get todayPhrase {
    if (_currentPhrase.isNotEmpty) return _currentPhrase;
    // Fallback de emergencia si initPhraseWithAi no fue llamado
    _pickFallback();
    return _currentPhrase;
  }

  /// Guarda una frase de IA en Hive para usarla en la PRÓXIMA apertura.
  static Future<void> _prefetchAiPhrase() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final phrase = await AIService.generateMotivationalPhrase();
      final trimmed = phrase.trim();
      if (trimmed.isNotEmpty && trimmed.length > 5 && trimmed.length < 150) {
        _box.put('prefetchedAiPhrase', trimmed);
      }
    } catch (e) {
      // No es crítico (hay fallback de frases locales), pero se loguea
      // el tipo de error para poder diagnosticar fallas recurrentes.
      debugPrint('[streak] prefetch AI phrase failed: ${e.runtimeType}');
    } finally {
      _isRefreshing = false;
    }
  }

  static Future<void> forceRefreshPhrase() async {
    _box.delete('prefetchedAiPhrase');
    _box.delete('lastPhrase');
    _currentPhrase = '';
    _isRefreshing = false;
    await initPhraseWithAi();
  }
}