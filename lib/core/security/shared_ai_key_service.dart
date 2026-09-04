import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Key de Groq COMPARTIDA por todas las instalaciones de la app, guardada
/// cifrada en Firestore (`app_config/shared_ai_key`) en vez de hardcodeada
/// en el binario. La carga el admin una sola vez desde el panel (nunca se
/// pega en el chat de Claude ni se commitea a git); cada instalación la
/// descarga cifrada y la descifra en memoria justo antes de llamar a Groq,
/// sin persistirla nunca en disco.
///
/// LÍMITE REAL de este esquema — documentado a propósito, no es un bug:
/// sin backend (Cloud Functions requiere plan Blaze, que por ahora no se
/// activó), la lógica de descifrado necesariamente viaja dentro del APK.
/// Alguien dispuesto a instrumentar la app en runtime (Frida, debugger)
/// puede extraer la key igual. Lo que SÍ evita este esquema es el ataque
/// más común y de menor esfuerzo: leer la key con un `strings`/jadx
/// superficial del APK o de Firestore directo (ahí solo hay ciphertext).
/// La protección real contra un abuso grave sigue siendo poner un tope de
/// gasto/rate limit en el dashboard de Groq — avisale a Fernando.
class SharedAiKeyService {
  SharedAiKeyService._();

  static const _docPath = 'app_config/shared_ai_key';
  static String? _cachedPlainKey;

  // Pepper de descifrado partido en fragmentos: no evita que alguien lea
  // este archivo completo y lo reconstruya, pero sí que aparezca como un
  // único string "sospechoso" en un escaneo automático del APK.
  static const _f1 = 'EstudIAr';
  static const _f2 = '_shared_ai_key';
  static const _f3 = '_pepper_2026';

  static enc.Key _deriveKey() {
    final pepper = '$_f1$_f2$_f3';
    final digest = sha256.convert(utf8.encode(pepper));
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Devuelve la key compartida en texto plano (cacheada en memoria para
  /// esta sesión del proceso), o null si el admin todavía no la configuró.
  static Future<String?> getSharedKey() async {
    if (_cachedPlainKey != null && _cachedPlainKey!.isNotEmpty) {
      return _cachedPlainKey;
    }
    try {
      final snap = await FirebaseFirestore.instance.doc(_docPath).get();
      if (!snap.exists) return null;
      final data = snap.data();
      final cipherB64 = data?['ciphertext'] as String?;
      final ivB64 = data?['iv'] as String?;
      if (cipherB64 == null || ivB64 == null) return null;

      final encrypter = enc.Encrypter(enc.AES(_deriveKey(), mode: enc.AESMode.cbc));
      final plain = encrypter.decrypt64(cipherB64, iv: enc.IV.fromBase64(ivB64));
      _cachedPlainKey = plain;
      return plain;
    } catch (_) {
      return null;
    }
  }

  /// Solo la usa el panel de admin. La key en texto plano nunca se
  /// persiste ni se loguea, solo vive en memoria durante esta llamada.
  static Future<void> setSharedKey(String plainKey) async {
    final trimmed = plainKey.trim();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_deriveKey(), mode: enc.AESMode.cbc));
    final cipher = encrypter.encrypt(trimmed, iv: iv);

    await FirebaseFirestore.instance.doc(_docPath).set({
      'ciphertext': cipher.base64,
      'iv': iv.base64,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    _cachedPlainKey = trimmed;
  }

  static Future<bool> hasSharedKey() async {
    final key = await getSharedKey();
    return key != null && key.isNotEmpty;
  }

  static void clearCache() => _cachedPlainKey = null;
}
