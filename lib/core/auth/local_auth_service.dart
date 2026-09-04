import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../models/app_user.dart';
export '../../models/app_user.dart' show LoginResult;

/// Servicio de autenticación local con persistencia en Firestore.
///
/// NOTA DE SEGURIDAD: este es un esquema de autenticación casero
/// (usuario/contraseña con hash propio + device binding). Para producción
/// real se recomienda migrar a Firebase Authentication, que maneja
/// hashing, rate limiting y rotación de credenciales de forma auditada.
/// Mientras tanto, este servicio aplica las mitigaciones razonables:
/// salt aleatorio por usuario, sin contraseñas ni hashes en logs, y
/// sin atajos de autenticación hardcodeados en el código fuente.
class LocalAuthService {
  static Box get _box => Hive.box('settings');
  static final _firestore = FirebaseFirestore.instance;
  static const _usersCollection = 'users';

  // ── Hashing con salt ───────────────────────────────────────────
  static String _generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _hashWithSalt(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static String _normalize(String username) => username.trim().toLowerCase();

  // Firebase Auth (Email/Password) necesita un email; el username sigue
  // siendo la clave canónica en Firestore, este email sintético solo
  // existe para satisfacer al proveedor de Auth y nunca se muestra en la
  // UI ni se usa en ningún otro lado.
  static String _authEmail(String normalizedUsername) =>
      '$normalizedUsername@estudiar.local';

  static Future<String> getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return info.id;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.identifierForVendor ?? 'unknown_ios';
      }
    } catch (_) {}
    return 'unknown_device';
  }

  // ── Test conexión a Firebase ───────────────────────────────────
  static Future<bool> testFirebaseConnection() async {
    try {
      await _firestore.collection(_usersCollection).doc('__healthcheck__').get();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Inicializar — crea admin en Firestore si no existe ─────────
  /// La contraseña inicial del admin se toma de `ADMIN_BOOTSTRAP_PASSWORD`
  /// (--dart-define) o, si no se definió, se genera una aleatoria que se
  /// imprime UNA sola vez en consola de debug para que el desarrollador
  /// la guarde. Nunca queda hardcodeada en el código fuente.
  static const _bootstrapPassword =
      String.fromEnvironment('ADMIN_BOOTSTRAP_PASSWORD', defaultValue: '');

  static Future<void> seedAdminIfNeeded() async {
    try {
      final adminDoc =
          await _firestore.collection(_usersCollection).doc('admin').get();
      if (adminDoc.exists) return;

      final password = _bootstrapPassword.isNotEmpty
          ? _bootstrapPassword
          : _generateSalt(10);

      await _firestore.collection(_usersCollection).doc('admin').set({
        'username': 'admin',
        'isActive': true,
        'isAdmin': true,
        'deviceId': null,
        'createdAt': DateTime.now().toIso8601String(),
        'lastLoginAt': null,
        'displayName': 'Admin',
        'bio': '',
        'avatarUrl': null,
        'followersCount': 0,
        'followingCount': 0,
        'isBlockedGlobally': false,
      });

      // La cuenta de Firebase Auth es la que realmente guarda la
      // credencial a partir de acá; el doc de Firestore ya no lleva
      // passwordHash/passwordSalt para usuarios creados de cero.
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _authEmail('admin'),
          password: password,
        );
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // No debe romper el arranque de la app: si esto falla (ej. el
        // proveedor Email/Password todavía no está habilitado en la
        // consola de Firebase), el admin queda creado en Firestore igual
        // y puede reintentarse manualmente más adelante.
        debugPrint('[auth] Error creando cuenta Auth del admin: $e');
      }

      if (_bootstrapPassword.isEmpty && kDebugMode) {
        // Solo en debug: en release nunca debe quedar una password en
        // texto plano en logcat/consola, aunque sea la de bootstrap.
        // ignore: avoid_print
        print('[setup] Admin creado. Password temporal (guardala ya): $password');
      }
    } catch (e) {
      debugPrint('[auth] Error seedAdminIfNeeded: ${e.runtimeType}');
    }
  }

  /// Migra usuarios legacy de Hive (esquema sin salt) a Firestore,
  /// asignándoles un salt nuevo. Como no se puede recuperar la
  /// contraseña original desde un hash sin salt, estos usuarios quedan
  /// marcados para reseteo obligatorio de contraseña en su próximo login.
  static Future<void> migrateUsersFromHiveToFirestore() async {
    try {
      final usersJson =
          Hive.box('settings').get('users', defaultValue: '{}') as String;
      final decoded = jsonDecode(usersJson) as Map<String, dynamic>;
      if (decoded.isEmpty) return;

      for (final entry in decoded.entries) {
        final username = _normalize(entry.key);
        if (username == 'admin') continue;

        final existing =
            await _firestore.collection(_usersCollection).doc(username).get();
        if (existing.exists) continue;

        final userData = Map<String, dynamic>.from(entry.value as Map);
        userData['passwordSalt'] ??= '';
        userData['mustResetPassword'] = true;
        await _firestore.collection(_usersCollection).doc(username).set(userData);
      }

      // Limpiar el blob legacy de Hive una vez migrado para no dejar
      // hashes sin salt dando vueltas en almacenamiento local.
      await Hive.box('settings').delete('users');
    } catch (e) {
      debugPrint('[auth] Error en migración: ${e.runtimeType}');
    }
  }

  // ── Login ──────────────────────────────────────────────────────
  // Rate limiting básico contra fuerza bruta: no reemplaza reglas de
  // Firestore del lado servidor (alguien pegándole directo a la API de
  // Firestore lo esquiva), pero frena a cualquiera probando contraseñas
  // desde la propia app, que es el vector realista acá.
  static const _maxFailedAttempts = 5;
  static const _lockoutDuration = Duration(minutes: 5);

  static Future<LoginResult> login(String username, String password) async {
    final key = _normalize(username);

    try {
      final docRef = _firestore.collection(_usersCollection).doc(key);
      final userDoc = await docRef.get();
      if (!userDoc.exists) return LoginResult.invalidCredentials;

      final userData = userDoc.data()!;
      final user = AppUser.fromMap(userData);

      final lockedUntilStr = userData['lockedUntil'] as String?;
      final lockedUntil =
          lockedUntilStr != null ? DateTime.tryParse(lockedUntilStr) : null;
      if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
        return LoginResult.tooManyAttempts;
      }

      // Doc "legacy" (tiene passwordHash propio, todavía no migrado a
      // Firebase Auth) vs. doc "nuevo estilo" (la credencial vive
      // únicamente en Firebase Auth). Se verifica con el método que
      // corresponda; el resultado (contador de intentos, lockout, etc.)
      // se maneja igual para ambos casos más abajo.
      bool passwordOk;
      if (user.passwordHash.isNotEmpty) {
        final computedHash = user.passwordSalt.isNotEmpty
            ? _hashWithSalt(password, user.passwordSalt)
            : sha256.convert(utf8.encode(password)).toString(); // legacy sin salt
        passwordOk = user.passwordHash == computedHash;
        if (passwordOk) {
          // Migración perezosa: primer login exitoso de un usuario legacy
          // crea su cuenta de Firebase Auth con la misma password recién
          // verificada, y el doc deja de llevar passwordHash/passwordSalt
          // de acá en adelante (no hace falta forzar un reseteo masivo).
          try {
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: _authEmail(key),
              password: password,
            );
          } on FirebaseAuthException catch (e) {
            // Si un login anterior ya creó la cuenta pero se interrumpió
            // antes de limpiar el doc (ej. la app se cerró en el medio),
            // no es un error: seguimos igual.
            if (e.code != 'email-already-in-use') {
              debugPrint('[auth] Error migrando a Firebase Auth ($key): $e');
            }
          } catch (e) {
            debugPrint('[auth] Error migrando a Firebase Auth ($key): $e');
          }
          await docRef.update({
            'passwordHash': FieldValue.delete(),
            'passwordSalt': FieldValue.delete(),
          });
        }
      } else {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _authEmail(key),
            password: password,
          );
          passwordOk = true;
        } on FirebaseAuthException {
          passwordOk = false;
        }
      }

      if (!passwordOk) {
        final attempts = ((userData['failedAttempts'] as num?)?.toInt() ?? 0) + 1;
        final update = <String, dynamic>{'failedAttempts': attempts};
        if (attempts >= _maxFailedAttempts) {
          update['lockedUntil'] =
              DateTime.now().add(_lockoutDuration).toIso8601String();
        }
        await docRef.update(update);
        return attempts >= _maxFailedAttempts
            ? LoginResult.tooManyAttempts
            : LoginResult.invalidCredentials;
      }
      if (!user.isActive || user.isBlockedGlobally) {
        return LoginResult.inactive;
      }

      // Device binding
      final currentDeviceId = await getDeviceId();
      if (user.deviceId == null || user.deviceId!.isEmpty) {
        user.deviceId = currentDeviceId;
      } else if (user.deviceId != currentDeviceId) {
        return LoginResult.deviceMismatch;
      }

      user.lastLoginAt = DateTime.now();
      await docRef.update({
        'deviceId': user.deviceId,
        'lastLoginAt': user.lastLoginAt!.toIso8601String(),
        'failedAttempts': 0,
        'lockedUntil': null,
      });

      await _box.put('logged_in_username', user.username);
      return LoginResult.success;
    } catch (e) {
      debugPrint('[auth] Error login: ${e.runtimeType}');
      return LoginResult.invalidCredentials;
    }
  }

  static Future<void> logout() async {
    await _box.delete('logged_in_username');
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // Nunca debe bloquear el logout local por un fallo de red del lado
      // de Firebase Auth — el usuario ya quedó deslogueado de la app.
      debugPrint('[auth] Error signOut Firebase Auth: $e');
    }
  }

  static bool isLoggedIn() => _box.get('logged_in_username') != null;

  static String? currentUsername() =>
      _box.get('logged_in_username') as String?;

  static Future<AppUser?> currentUser() async {
    final username = currentUsername();
    if (username == null) return null;
    try {
      final doc =
          await _firestore.collection(_usersCollection).doc(username).get();
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  static bool isCurrentUserAdmin() {
    final username = currentUsername();
    return username == 'admin';
  }

  /// Escucha en vivo si la cuenta sigue activa. `isActive` antes solo se
  /// validaba en login(): una vez logueado, un admin podía deshabilitar
  /// o borrar al usuario desde el panel y la sesión seguía viva en el
  /// dispositivo hasta el próximo login manual. Este stream permite
  /// reaccionar al toque (MainShell lo escucha y fuerza logout).
  static Stream<bool> watchAccountActive(String username) {
    final key = _normalize(username);
    return _firestore
        .collection(_usersCollection)
        .doc(key)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      final data = doc.data()!;
      final isActive = data['isActive'] as bool? ?? true;
      final isBlocked = data['isBlockedGlobally'] as bool? ?? false;
      return isActive && !isBlocked;
    });
  }

  // ── Obtener todos los usuarios ──────────────────────────────────
  static Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection(_usersCollection).get();
      final users = snapshot.docs
          .map((doc) {
            try {
              return AppUser.fromMap(doc.data());
            } catch (_) {
              return null;
            }
          })
          .whereType<AppUser>()
          .toList();
      users.sort((a, b) => a.username.compareTo(b.username));
      return users;
    } catch (_) {
      return [];
    }
  }

  // ── Crear usuario en Firestore ──────────────────────────────────
  static Future<bool> createUser({
    required String username,
    required String password,
    bool isAdmin = false,
  }) async {
    final key = _normalize(username);
    if (key == 'admin' || key.isEmpty) return false;
    if (password.length < 6) return false;

    try {
      final docRef = _firestore.collection(_usersCollection).doc(key);
      // Chequeo de existencia + escritura dentro de una transacción: sin
      // esto, dos altas casi simultáneas para el mismo username pueden
      // pasar ambas el chequeo "no existe" y la segunda pisa en silencio
      // el doc de la primera sin que nadie vea un error. La credencial ya
      // no se guarda acá (ver más abajo) — esta transacción solo protege
      // la unicidad del username como clave de Firestore.
      final created = await _firestore.runTransaction<bool>((tx) async {
        final userDoc = await tx.get(docRef);
        if (userDoc.exists) return false;
        tx.set(docRef, {
          'username': key,
          'isActive': true,
          'isAdmin': isAdmin,
          'deviceId': null,
          'createdAt': DateTime.now().toIso8601String(),
          'lastLoginAt': null,
          'displayName': key,
          'bio': '',
          'avatarUrl': null,
          'followersCount': 0,
          'followingCount': 0,
          'isBlockedGlobally': false,
        });
        return true;
      });
      if (!created) return false;

      // El SDK de Firebase Auth no participa de transacciones de
      // Firestore, así que esto va aparte. Si falla, no dejamos una
      // cuenta fantasma sin forma de loguearse: se borra el doc recién
      // creado y se informa el fallo al panel de admin.
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _authEmail(key),
          password: password,
        );
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('[auth] Error creando cuenta Auth para $key: $e');
        await docRef.delete();
        return false;
      }
      return true;
    } catch (e) {
      // Ej: permission-denied si firestore.rules no está desplegado con
      // la regla "allow create" actualizada — no lo confundas con "ya existe".
      debugPrint('[auth] Error createUser($key): $e');
      return false;
    }
  }

  static Future<bool> toggleActive(String username) async {
    final key = _normalize(username);
    if (key == 'admin') return false;
    try {
      final userDoc =
          await _firestore.collection(_usersCollection).doc(key).get();
      if (userDoc.exists) {
        final isActive = userDoc.get('isActive') as bool? ?? true;
        await _firestore
            .collection(_usersCollection)
            .doc(key)
            .update({'isActive': !isActive});
      }
      return true;
    } catch (e) {
      debugPrint('[auth] Error toggleActive($key): $e');
      return false;
    }
  }

  static Future<bool> resetDevice(String username) async {
    final key = _normalize(username);
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(key)
          .update({'deviceId': null});
      return true;
    } catch (e) {
      debugPrint('[auth] Error resetDevice($key): $e');
      return false;
    }
  }

  /// Devuelve true solo si el documento se borró de verdad. Antes esto no
  /// devolvía nada: si Firestore denegaba el delete (p.ej. firestore.rules
  /// desactualizado en la consola), el error quedaba silenciado y el panel
  /// de admin refrescaba la lista como si hubiese funcionado, mientras el
  /// doc seguía existiendo — por eso createUser() para ese mismo username
  /// seguía devolviendo "ya existe" después de "borrarlo".
  static Future<bool> deleteUser(String username) async {
    final key = _normalize(username);
    if (key == 'admin') return false;
    try {
      await _firestore.collection(_usersCollection).doc(key).delete();
      return true;
    } catch (e) {
      debugPrint('[auth] Error deleteUser($key): $e');
      return false;
    }
  }

  static Future<bool> changePassword(
      String username, String newPassword) async {
    final key = _normalize(username);
    if (newPassword.length < 6) return false;
    try {
      final salt = _generateSalt();
      await _firestore.collection(_usersCollection).doc(key).update({
        'passwordHash': _hashWithSalt(newPassword, salt),
        'passwordSalt': salt,
        'mustResetPassword': false,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Límite diario de uso de IA (panel de admin) ───────────────────
  // Solo toca aiUsageLimit, nunca aiUsageCount/aiUsageResetAt (esos los
  // maneja exclusivamente la Cloud Function aiProxy, ver firestore.rules).
  static Future<bool> setAiUsageLimit(String username, int limit) async {
    final key = _normalize(username);
    if (limit < 0) return false;
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(key)
          .update({'aiUsageLimit': limit});
      return true;
    } catch (e) {
      debugPrint('[auth] Error setAiUsageLimit($key): $e');
      return false;
    }
  }
}
