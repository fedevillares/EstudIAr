import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Resultado de chequear si hay una actualización obligatoria pendiente.
class UpdateCheckResult {
  final bool required;
  final String? apkUrl;
  const UpdateCheckResult({required this.required, this.apkUrl});
}

/// La app se distribuye por APK directo (WhatsApp/Drive), sin Play Store
/// ni Firebase App Distribution — no existe ningún aviso nativo de "hay
/// una versión nueva". Esto lo resuelve comparando el buildNumber local
/// (pubspec `version: X+buildNumber`) contra un doc de config remoto en
/// Firestore (`app_config/version`), y bloquea el acceso si quedó vieja.
class UpdateService {
  static const _collection = 'app_config';
  static const _docId = 'version';

  static Future<UpdateCheckResult> check() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();
      if (!doc.exists) {
        return const UpdateCheckResult(required: false);
      }

      final data = doc.data()!;
      final minBuildNumber = data['minBuildNumber'] as int? ?? 0;
      final apkUrl = data['apkUrl'] as String?;

      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      return UpdateCheckResult(
        required: currentBuild < minBuildNumber,
        apkUrl: apkUrl,
      );
    } catch (_) {
      // Sin conexión o error de lectura: no bloqueamos el uso de la app
      // por esto, simplemente no chequeamos actualización esta vez.
      return const UpdateCheckResult(required: false);
    }
  }
}
