import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';

/// Resultado de una revisión de moderación.
class ModerationResult {
  final bool isAllowed;
  final String? reason;
  final ModerationSeverity severity;

  const ModerationResult({
    required this.isAllowed,
    this.reason,
    this.severity = ModerationSeverity.none,
  });

  const ModerationResult.allowed()
      : isAllowed = true,
        reason = null,
        severity = ModerationSeverity.none;

  factory ModerationResult.blocked(String reason,
          {ModerationSeverity severity = ModerationSeverity.medium}) =>
      ModerationResult(isAllowed: false, reason: reason, severity: severity);
}

enum ModerationSeverity { none, low, medium, high }

/// Capa de moderación de contenido para posts, comentarios y mensajes
/// directos de la red social.
///
/// Estrategia en dos pasos, pensada para ser rápida y no depender
/// 100% de un servicio externo:
///   1. Filtro local instantáneo (sin red): listas de términos
///      prohibidos, detección de spam/flood, y detección de datos
///      personales sensibles (teléfonos, emails, links) que no
///      deberían compartirse en mensajes públicos del feed.
///   2. Si el filtro local no encuentra nada, y hay una API key de IA
///      configurada, se hace una segunda pasada con un modelo de
///      lenguaje para detectar acoso, contenido de odio, grooming,
///      amenazas o contenido sexual que el filtro de palabras no
///      pueda capturar por contexto.
///
/// El filtro local es la línea de defensa principal (no se puede
/// evadir aunque la IA falle o no esté disponible); la IA es una
/// capa adicional, no la única.
class ContentModerationService {
  ContentModerationService._();

  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';

  // Lista de términos bloqueados. No exhaustiva (la moderación de
  // lenguaje natural completa requiere la capa de IA), pero cubre
  // insultos graves, discurso de odio explícito y términos asociados
  // a grooming/abuso, que deben bloquearse siempre y sin excepción,
  // incluso sin conexión a internet.
  static final List<RegExp> _blockedPatterns = [
    // Insultos y violencia explícita (ejemplos representativos en español rioplatense)
    RegExp(r'\b(put[ao]s?|forro|conch[ae]\s*tu|hijo\s*de\s*put)\b', caseSensitive: false),
    RegExp(r'\b(matate|te\s*voy\s*a\s*matar|te\s*mato)\b', caseSensitive: false),
    // Discurso de odio (grupos protegidos) — patrones genéricos de detección
    RegExp(r'\b(negro\s*de\s*mierda|sucio\s*jud[ií]o|maric[oó]n\s*de\s*mierda)\b', caseSensitive: false),
  ];

  // Patrones de datos personales sensibles que no deberían circular
  // en el feed público (sí pueden circular en DM, donde solo se filtran
  // por contenido abusivo, no por compartir contacto).
  static final RegExp _phonePattern =
      RegExp(r'(\+?\d{1,3}[\s.-]?)?\(?\d{2,4}\)?[\s.-]?\d{3,4}[\s.-]?\d{3,4}');
  static final RegExp _emailPattern =
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
  static final RegExp _urlPattern =
      RegExp(r'(https?:\/\/|www\.)\S+', caseSensitive: false);

  /// Revisa contenido destinado al feed público (posts/comentarios).
  /// Es más estricto: bloquea también datos de contacto, porque
  /// expone a estudiantes (potencialmente menores) a contacto directo
  /// no solicitado desde un espacio público.
  static Future<ModerationResult> reviewPublicContent(String text) async {
    final localResult = _runLocalFilters(text, blockContactInfo: true);
    if (!localResult.isAllowed) return localResult;
    return _runAiReview(text, context: 'post público del feed de una red social educativa');
  }

  /// Revisa contenido de un mensaje directo (DM). Permite compartir
  /// datos de contacto (es razonable entre dos personas que ya se
  /// están mensajeando), pero sigue bloqueando acoso, odio y amenazas.
  static Future<ModerationResult> reviewDirectMessage(String text) async {
    final localResult = _runLocalFilters(text, blockContactInfo: false);
    if (!localResult.isAllowed) return localResult;
    return _runAiReview(text, context: 'mensaje directo privado entre dos estudiantes');
  }

  // ── Filtro local ────────────────────────────────────────────────
  static ModerationResult _runLocalFilters(String text,
      {required bool blockContactInfo}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return ModerationResult.blocked('El mensaje está vacío.');
    }
    if (trimmed.length > 4000) {
      return ModerationResult.blocked('El mensaje es demasiado largo.');
    }

    for (final pattern in _blockedPatterns) {
      if (pattern.hasMatch(trimmed)) {
        return ModerationResult.blocked(
          'Tu mensaje contiene lenguaje que viola las normas de la comunidad.',
          severity: ModerationSeverity.high,
        );
      }
    }

    // Detección simple de flood/spam: mismo carácter repetido en exceso
    // o el mensaje compuesto casi enteramente por mayúsculas (grito).
    if (RegExp(r'(.)\1{9,}').hasMatch(trimmed)) {
      return ModerationResult.blocked(
        'Evitá repetir caracteres de forma excesiva (spam).',
        severity: ModerationSeverity.low,
      );
    }

    if (blockContactInfo) {
      if (_phonePattern.hasMatch(trimmed) && trimmed.replaceAll(RegExp(r'\D'), '').length >= 7) {
        return ModerationResult.blocked(
          'Por tu seguridad, no se permite compartir números de teléfono en publicaciones públicas. Podés usar los mensajes directos.',
          severity: ModerationSeverity.medium,
        );
      }
      if (_emailPattern.hasMatch(trimmed)) {
        return ModerationResult.blocked(
          'Por tu seguridad, no se permite compartir emails en publicaciones públicas.',
          severity: ModerationSeverity.medium,
        );
      }
      if (_urlPattern.hasMatch(trimmed)) {
        return ModerationResult.blocked(
          'No se permiten links externos en publicaciones públicas para evitar spam y phishing.',
          severity: ModerationSeverity.medium,
        );
      }
    }

    return const ModerationResult.allowed();
  }

  // ── Segunda capa: revisión por IA ──────────────────────────────
  static Future<ModerationResult> _runAiReview(String text,
      {required String context}) async {
    try {
      final apiKey = await SecureStorageService.getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        // Sin IA disponible: el filtro local ya corrió, se permite.
        // (degradación segura: no bloquea contenido legítimo por falta
        // de conectividad, pero el filtro local sigue protegiendo).
        return const ModerationResult.allowed();
      }

      final prompt = '''
Analizá el siguiente texto, que es un $context en una app educativa usada por estudiantes (pueden ser menores de edad).

Texto a analizar:
"""
$text
"""

Determiná si el texto contiene alguno de estos problemas:
- Acoso, bullying o humillación hacia otra persona
- Discurso de odio (racismo, homofobia, xenofobia, etc.)
- Amenazas de violencia o autolesión
- Contenido sexual explícito o grooming hacia menores
- Spam, estafas o phishing
- Venta de exámenes/trabajos o promoción de deshonestidad académica grave

Respondé ÚNICAMENTE con este JSON, sin texto adicional:
{"bloquear": true o false, "motivo": "razón breve en español si se bloquea, o null"}
''';

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Sos un moderador de contenido estricto pero justo para una app educativa de estudiantes. Respondés solo JSON válido.'
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.0,
              'max_tokens': 200,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        // Si la IA falla, no bloqueamos contenido legítimo: el filtro
        // local ya es la barrera dura contra lo más grave.
        return const ModerationResult.allowed();
      }

      final data = jsonDecode(response.body);
      final content =
          data['choices']?[0]?['message']?['content'] as String? ?? '{}';
      final cleaned = content
          .replaceAll(RegExp(r'```json'), '')
          .replaceAll(RegExp(r'```'), '')
          .trim();
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;

      final shouldBlock = parsed['bloquear'] == true;
      if (shouldBlock) {
        return ModerationResult.blocked(
          (parsed['motivo'] as String?) ??
              'El contenido fue marcado por el sistema de moderación.',
          severity: ModerationSeverity.high,
        );
      }
      return const ModerationResult.allowed();
    } catch (_) {
      // Fail-open ante errores de red/parseo: el filtro local ya corrió.
      return const ModerationResult.allowed();
    }
  }
}
