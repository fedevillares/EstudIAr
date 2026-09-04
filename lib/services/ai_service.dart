import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../core/auth/local_auth_service.dart';
import '../core/security/prompt_sanitizer.dart';
import '../core/security/secure_storage_service.dart';
import '../core/security/shared_ai_key_service.dart';
import '../models/evaluation.dart';

/// Excepción lanzada cuando no hay API key configurada NI sesión para
/// usar el proxy compartido (caso borde: llamar a la IA sin login).
class MissingApiKeyException implements Exception {
  final String message;
  const MissingApiKeyException(
      [this.message = 'No hay API key de Groq configurada.']);
  @override
  String toString() => message;
}

/// El usuario alcanzó su límite diario de uso de IA (configurado por el
/// admin). Solo aplica cuando se usa el proxy compartido, no si el
/// usuario cargó su propia API key en Ajustes.
class UsageLimitExceededException implements Exception {
  final String message;
  const UsageLimitExceededException(
      [this.message = 'Alcanzaste el límite diario de uso de IA.']);
  @override
  String toString() => message;
}

/// La cuenta no puede usar el proxy compartido (deshabilitada o no
/// encontrada en el servidor).
class AccountIssueException implements Exception {
  final String message;
  const AccountIssueException([this.message = 'Problema con tu cuenta.']);
  @override
  String toString() => message;
}

class AIService {
  static const _modelText   = 'llama-3.3-70b-versatile';
  static const _modelVision = 'meta-llama/llama-4-scout-17b-16e-instruct';
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static final _cache   = <String, (String, DateTime)>{};
  static const _cacheTtl = Duration(hours: 12);
  static const _cacheMaxEntries = 200;

  // ── Convierte imagen a base64 ──────────────────────────────────
  static Future<String> _imageToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  static String _mimeType(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      default:     return 'image/jpeg';
    }
  }

// ── Plan de estudio ────────────────────────────────────────────
  static Future<String> generateStudyPlan({
    required List<Evaluation> pending,
    int hoursPerDay = 2,
  }) async {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final maxMinutesPerDay = hoursPerDay * 60;
    // Objetivo: usar entre el 85% y el 100% del tiempo configurado.
    final minMinutesPerDay = (maxMinutesPerDay * 0.85).round();

    final context = pending
        .where((e) => !e.isCompleted && e.date.isAfter(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (context.isEmpty) {
      return '{"days": [], "advice": "No hay evaluaciones pendientes para planificar."}';
    }

    final evalList = context
        .map((e) =>
            '• ${e.subject} | Tipo: ${e.type} | Fecha: ${e.date.toIso8601String().split("T")[0]} | Dificultad: ${e.difficulty}/5')
        .join('\n');

    // Sugerencia de cantidad de sesiones por día según horas configuradas.
    // Esto le da al modelo una guía concreta de cuántas sesiones armar.
    final int suggestedSessions;
    if (hoursPerDay <= 1) {
      suggestedSessions = 2;
    } else if (hoursPerDay <= 2) {
      suggestedSessions = 3;
    } else if (hoursPerDay <= 4) {
      suggestedSessions = 4;
    } else if (hoursPerDay <= 6) {
      suggestedSessions = 5;
    } else {
      suggestedSessions = 6;
    }

    final seed = DateTime.now().millisecondsSinceEpoch % 9999;

    final prompt = '''
Sos un tutor académico experto. Creá un plan de estudio VARIADO y DIFERENTE (seed: $seed).

Evaluaciones pendientes:
$evalList

Fecha actual: ${today.toIso8601String().split("T")[0]}

⚠️ REGLA CRÍTICA DE TIEMPO DIARIO ⚠️
El estudiante DEDICA $hoursPerDay HORAS por día ($maxMinutesPerDay minutos).
Tenés que PROGRAMAR entre $minMinutesPerDay y $maxMinutesPerDay minutos POR DÍA.
NO menos de $minMinutesPerDay minutos. NO más de $maxMinutesPerDay minutos.

Para lograr eso:
- Programá APROXIMADAMENTE $suggestedSessions sesiones por día.
- Cada sesión dura entre 25 y 50 minutos.
- La SUMA de duration_minutes de las sesiones de cada día tiene que estar entre $minMinutesPerDay y $maxMinutesPerDay.
- Si te faltan minutos para llegar al mínimo, AGREGÁ otra sesión (ej: repaso general, ejercicios extra, mapa conceptual).
- VERIFICÁ MENTALMENTE la suma de cada día antes de responder.

Reglas adicionales:
- Distribuí el estudio desde hoy hasta 1 día antes de cada evaluación.
- Priorizá materias más urgentes y con mayor dificultad.
- Variá las actividades: "Leer apuntes del tema X", "Resolver ejercicios de práctica", "Hacer mapa conceptual", "Repasar fórmulas", "Resumir capítulo Y", "Practicar con preguntas tipo examen", "Autoevaluación con preguntas", "Releer y subrayar conceptos clave", etc.
- Sé creativo y específico en cada actividad.
- El "advice" debe ser un consejo concreto y útil de 1-2 oraciones.

EJEMPLO de día válido con límite de $maxMinutesPerDay min:
${_buildExampleDay(maxMinutesPerDay, suggestedSessions)}

Respondé ÚNICAMENTE con este JSON válido, sin texto antes ni después:
{
  "days": [
    {
      "date": "YYYY-MM-DD",
      "sessions": [
        {
          "subject": "nombre de la materia",
          "task": "actividad concreta y específica",
          "duration_minutes": 30
        }
      ]
    }
  ],
  "advice": "consejo motivador y concreto"
}
''';

    return _callGroq([
      {
        'role': 'system',
        'content':
            'Sos un asistente educativo riguroso con la gestión del tiempo. Respondés SOLO con JSON válido, sin markdown, sin texto adicional. La suma de duration_minutes de cada día DEBE respetar el rango indicado por el usuario.'
      },
      {'role': 'user', 'content': prompt}
    ], maxTokens: 4096, skipCache: true, temperature: 0.8);
  }

  /// Construye un ejemplo dinámico de un día con sesiones que suman
  /// aproximadamente el tiempo configurado, para anclar al modelo.
  static String _buildExampleDay(int targetMinutes, int sessions) {
    // Reparto del tiempo en N sesiones de entre 25 y 50 min.
    final perSession = (targetMinutes / sessions).round().clamp(25, 50);
    final actualTotal = perSession * sessions;
    final exampleSessions = List.generate(sessions, (i) {
      final tareas = [
        'Leer apuntes del tema 1',
        'Resolver ejercicios prácticos',
        'Hacer mapa conceptual',
        'Repasar fórmulas clave',
        'Autoevaluación con preguntas',
        'Resumen del capítulo',
      ];
      return '  {"subject":"Materia X","task":"${tareas[i % tareas.length]}","duration_minutes":$perSession}';
    }).join(',\n');
    return '''[
$exampleSessions
]  // Total: $actualTotal min (objetivo: $targetMinutes min)''';
  }

  // ── Flashcards ─────────────────────────────────────────────────
  static Future<String> generateFlashcards({
    required String subject,
    required String material,
  }) async {
    final prompt = PromptSanitizer.sanitize('''
Extraé exactamente 5 flashcards del siguiente material de $subject.
Respondé SOLO con JSON válido, sin texto adicional, sin markdown:
[
  {"id": 1, "pregunta": "...", "respuesta": "..."},
  {"id": 2, "pregunta": "...", "respuesta": "..."},
  {"id": 3, "pregunta": "...", "respuesta": "..."},
  {"id": 4, "pregunta": "...", "respuesta": "..."},
  {"id": 5, "pregunta": "...", "respuesta": "..."}
]

Material:
$material
''');
    return _callGroq([
      {'role': 'system', 'content': 'Respondés SOLO con un array JSON válido. Sin markdown, sin texto antes ni después.'},
      {'role': 'user',   'content': prompt}
    ]);
  }

  // ── Chat con material ──────────────────────────────────────────
  static Future<String> chatWithMaterial({
    required String material,
    required String question,
  }) async {
    final prompt = PromptSanitizer.sanitize('''
Material de referencia:
$material

Pregunta del estudiante: $question

Respondé de forma clara, concisa y pedagógica. Si la respuesta no está en el material, indicalo.
''');
    return _callGroq([
      {'role': 'system', 'content': 'Sos un tutor académico. Respondés en español, de forma clara y útil para estudiantes.'},
      {'role': 'user',   'content': prompt}
    ]);
  }

  // ── Resumen de material (texto + imágenes opcionales) ──────────
  static Future<String> summarizeMaterial({
    required String subject,
    required String material,
    List<File>? images,
  }) async {
    final hasImages = images != null && images.isNotEmpty;

    final textPrompt = '''
Sos un tutor académico experto. Analizá el siguiente material de "$subject" y creá un resumen completo y estructurado.
${hasImages ? 'Se adjuntan ${images.length} imagen(es) de apuntes para analizar junto con el texto.' : ''}

MATERIAL:
${material.isEmpty ? '(sin texto, analizá solo las imágenes)' : material}

El resumen debe incluir:
1. **Idea principal**: Una oración que capture el tema central.
2. **Conceptos clave**: Lista los 4-6 conceptos más importantes con una explicación breve de cada uno.
3. **Desarrollo**: Explicá los puntos principales en 2-3 párrafos claros, usando lenguaje accesible para un estudiante.
4. **Conclusión**: Un párrafo corto que conecte las ideas y destaque qué es lo más importante recordar.
5. **Para el examen**: 2-3 puntos concretos que el estudiante debería estudiar bien.

Usá un tono académico pero accesible. Respondé en español.
''';

    if (hasImages) {
      // Construir mensaje con múltiples imágenes en base64
      final contentParts = <Map<String, dynamic>>[];

      // Primero el texto
      contentParts.add({
        'type': 'text',
        'text': PromptSanitizer.sanitize(textPrompt),
      });

      // Luego cada imagen
      for (final img in images) {
        final b64  = await _imageToBase64(img);
        final mime = _mimeType(img);
        contentParts.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:$mime;base64,$b64',
          },
        });
      }

      return _callGroqVision(
        systemPrompt: 'Sos un tutor académico experto. Analizás texto e imágenes de apuntes y creás resúmenes claros y útiles para estudiantes. Respondés siempre en español.',
        contentParts: contentParts,
        maxTokens: 2048,
      );
    } else {
      // Solo texto
      return _callGroq([
        {'role': 'system', 'content': 'Sos un tutor académico experto. Creás resúmenes claros, estructurados y útiles para estudiantes. Respondés siempre en español.'},
        {'role': 'user',   'content': PromptSanitizer.sanitize(textPrompt)}
      ], maxTokens: 2048);
    }
  }

  // ── Pregunta de examen ─────────────────────────────────────────
  static Future<String> generateExamQuestion({
    required String subject,
    required String material,
    required List<String> previousQuestions,
  }) async {
    final historyText = previousQuestions.isNotEmpty
        ? 'Preguntas ya hechas (no repetir):\n${previousQuestions.map((q) => '- $q').join('\n')}'
        : '';

    final prompt = PromptSanitizer.sanitize('''
Generá UNA pregunta de examen para la materia "$subject" basada en este material:

$material

$historyText

La pregunta debe:
- Ser clara y sin ambigüedades
- Requerir comprensión, no solo memorización
- Tener dificultad media-alta
- Poder responderse en 3-5 oraciones

Respondé SOLO con la pregunta, sin numeración ni explicaciones.
''');
    return _callGroq([
      {'role': 'system', 'content': 'Sos un profesor universitario que crea preguntas de examen desafiantes y claras.'},
      {'role': 'user',   'content': prompt}
    ]);
  }

  // ── Evaluar respuesta de examen ────────────────────────────────
  static Future<String> evaluateExamAnswer({
    required String subject,
    required String material,
    required String question,
    required String answer,
  }) async {
    final prompt = PromptSanitizer.sanitize('''
Evaluá la siguiente respuesta de un estudiante. Respondé SOLO con JSON válido, sin texto adicional:

{
  "puntaje": <número entre 0 y 10>,
  "feedback": "<explicación constructiva de 2-3 oraciones>",
  "respuesta_correcta": "<respuesta ideal basada en el material>"
}

Materia: $subject
Material: $material
Pregunta: $question
Respuesta del estudiante: $answer
''');
    return _callGroq([
      {'role': 'system', 'content': 'Sos un evaluador académico justo y constructivo. Respondés SOLO con JSON válido.'},
      {'role': 'user',   'content': prompt}
    ]);
  }

  // ── Frase motivacional ─────────────────────────────────────────
  static Future<String> generateMotivationalPhrase() async {
    const prompt =
        'Generá UNA frase motivacional corta (máximo 12 palabras) para un estudiante argentino. '
        'Usá español rioplatense, terminá con un emoji relevante. '
        'Respondé ÚNICAMENTE con la frase, sin comillas ni explicaciones.';
    return _callGroq([
      {'role': 'system', 'content': 'Sos un coach motivacional para estudiantes argentinos. Respondés solo con la frase, nada más.'},
      {'role': 'user',   'content': prompt},
    ], maxTokens: 100);
  }

  // ── Call Groq texto ────────────────────────────────────────────
  static Future<String> _callGroq(
    List<Map<String, String>> messages, {
    int maxTokens   = 1024,
    bool skipCache  = false,
    double temperature = 0.3,
  }) async {
    final cacheKey = jsonEncode(messages.last['content']);
    final now      = DateTime.now();

    if (!skipCache && _cache.containsKey(cacheKey)) {
      final (val, ts) = _cache[cacheKey]!;
      if (now.difference(ts).inMinutes < _cacheTtl.inMinutes) return val;
      _cache.remove(cacheKey);
    }

    final ownKey = await SecureStorageService.getApiKey();
    final content = (ownKey != null && ownKey.isNotEmpty)
        ? await _callGroqDirect(
            apiKey: ownKey,
            model: _modelText,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
          )
        : await _callSharedKeyGroq(
            model: _modelText,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
          );

    if (!skipCache) {
      // Map preserva orden de inserción: si nos pasamos del tope, tiramos
      // la entrada más vieja antes de agregar la nueva (evita que el
      // cache en memoria crezca sin límite durante una sesión larga).
      if (_cache.length >= _cacheMaxEntries) {
        _cache.remove(_cache.keys.first);
      }
      _cache[cacheKey] = (content, now);
    }
    return content;
  }

  // ── Call Groq visión (imágenes) ────────────────────────────────
  static Future<String> _callGroqVision({
    required String systemPrompt,
    required List<Map<String, dynamic>> contentParts,
    int maxTokens = 2048,
  }) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user',   'content': contentParts},
    ];

    final ownKey = await SecureStorageService.getApiKey();
    if (ownKey != null && ownKey.isNotEmpty) {
      return _callGroqDirect(
        apiKey: ownKey,
        model: _modelVision,
        messages: messages,
        temperature: 0.3,
        maxTokens: maxTokens,
        timeout: const Duration(seconds: 45),
      );
    }
    return _callSharedKeyGroq(
      model: _modelVision,
      messages: messages,
      temperature: 0.3,
      maxTokens: maxTokens,
      timeout: const Duration(seconds: 45),
    );
  }

  // ── Llamada directa a Groq con la API key propia del usuario ───
  static Future<String> _callGroqDirect({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
    required double temperature,
    required int maxTokens,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model':       model,
        'messages':    messages,
        'temperature': temperature,
        'max_tokens':  maxTokens,
      }),
    ).timeout(timeout);

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const MissingApiKeyException(
          'La API key de Groq es inválida o fue rechazada.');
    }
    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices']?[0]?['message']?['content'] as String? ?? '';
  }

  // ── Key compartida (sin backend): límite de uso por usuario chequeado
  // y consumido en una transacción de Firestore ANTES de descifrar/usar
  // la key compartida, después se llama a Groq directo con esa key.
  // Ver SharedAiKeyService para el detalle y las limitaciones de este
  // esquema (documentadas ahí, no repetir la discusión acá).
  static Future<String> _callSharedKeyGroq({
    required String model,
    required List<Map<String, dynamic>> messages,
    required double temperature,
    required int maxTokens,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final username = LocalAuthService.currentUsername();
    if (username == null || username.isEmpty) {
      throw const MissingApiKeyException(
          'Iniciá sesión para poder usar la IA.');
    }

    await _checkAndConsumeUsage(username);

    final sharedKey = await SharedAiKeyService.getSharedKey();
    if (sharedKey == null || sharedKey.isEmpty) {
      throw const MissingApiKeyException(
          'El administrador todavía no configuró la IA compartida. '
          'Podés cargar tu propia API key en Ajustes mientras tanto.');
    }

    try {
      return await _callGroqDirect(
        apiKey: sharedKey,
        model: model,
        messages: messages,
        temperature: temperature,
        maxTokens: maxTokens,
        timeout: timeout,
      );
    } catch (_) {
      // Si Groq falló, devolvemos el crédito consumido (best-effort).
      await _refundUsage(username);
      rethrow;
    }
  }

  static const _dayMs = 24 * 60 * 60 * 1000;

  /// Chequea el límite diario configurado por el admin y lo consume en
  /// una transacción. Se resetea solo cada 24hs desde el primer uso del
  /// período. limit == 0 significa sin límite.
  static Future<void> _checkAndConsumeUsage(String username) async {
    final normalized = username.trim().toLowerCase();
    final ref = FirebaseFirestore.instance.collection('users').doc(normalized);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const AccountIssueException('Usuario no encontrado.');
      }
      final data = snap.data()!;
      if (data['isActive'] == false) {
        throw const AccountIssueException('Tu cuenta está deshabilitada.');
      }

      final limit = (data['aiUsageLimit'] as num?)?.toInt() ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final resetAtStr = data['aiUsageResetAt'] as String?;
      final resetAtMs = resetAtStr != null
          ? DateTime.tryParse(resetAtStr)?.millisecondsSinceEpoch ?? 0
          : 0;

      var count = (data['aiUsageCount'] as num?)?.toInt() ?? 0;
      var newResetAtMs = resetAtMs;

      if (resetAtMs == 0 || now >= resetAtMs) {
        count = 0;
        newResetAtMs = now + _dayMs;
      }

      if (limit > 0 && count >= limit) {
        throw const UsageLimitExceededException();
      }

      tx.update(ref, {
        'aiUsageCount': count + 1,
        'aiUsageResetAt':
            DateTime.fromMillisecondsSinceEpoch(newResetAtMs).toIso8601String(),
      });
    });
  }

  static Future<void> _refundUsage(String username) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(username.trim().toLowerCase());
      await ref.update({'aiUsageCount': FieldValue.increment(-1)});
    } catch (_) {
      // Best-effort: si falla, el usuario pierde 1 crédito de más. No
      // rompemos el flujo principal por esto.
    }
  }
}