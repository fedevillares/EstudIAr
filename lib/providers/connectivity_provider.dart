import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

/// Stream del estado de conexión. true = online.
final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityService.onlineStatusStream();
});

/// Helper sincrónico: devuelve bool directo (default true mientras carga).
/// Usar este en widgets para evitar manejar AsyncValue cada vez.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
        data: (online) => online,
        orElse: () => true,
      );
});