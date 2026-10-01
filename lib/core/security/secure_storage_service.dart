import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro respaldado por Keystore (Android) / Keychain (iOS).
/// No agregamos cifrado AES casero: la clave estaría hardcodeada en el binario
/// y sería trivial de extraer, lo cual da una falsa sensación de seguridad.
class SecureStorageService {
  SecureStorageService._();

  static const _kApiKey = 'groq_api_key';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// API key por defecto a inyectar en build (NO se commitea).
  /// Uso: `flutter run --dart-define=<tu-key-de-groq>
  static const _defaultApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  // ── API Key ────────────────────────────────────────────────────────────────

  /// Si no hay API key guardada y se compiló con --dart-define=GROQ_API_KEY=...,
  /// la persiste en el storage seguro. Llamar una vez al arrancar la app.
  static Future<void> initDefaultApiKey() async {
    final existing = await _storage.read(key: _kApiKey);
    if ((existing == null || existing.isEmpty) && _defaultApiKey.isNotEmpty) {
      await _storage.write(key: _kApiKey, value: _defaultApiKey);
    }
  }

  static Future<void> setApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _kApiKey);
      return;
    }
    await _storage.write(key: _kApiKey, value: trimmed);
  }

  static Future<String?> getApiKey() async {
    final v = await _storage.read(key: _kApiKey);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<bool> hasApiKey() async {
    final v = await getApiKey();
    return v != null && v.isNotEmpty;
  }

  // ── Utilidad ───────────────────────────────────────────────────────────────

  static Future<void> clear() => _storage.deleteAll();
}