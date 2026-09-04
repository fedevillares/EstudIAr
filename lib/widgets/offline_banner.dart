import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';

const _kDanger = Color(0xFFE17055);

/// Banner que aparece arriba cuando no hay conexión.
/// Envolvé el body de tus Scaffold con esto, o ponelo arriba de la Column.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: online
          ? const SizedBox(width: double.infinity, height: 0)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: _kDanger.withValues(alpha: 0.18),
                border: Border(
                  bottom: BorderSide(color: _kDanger.withValues(alpha: 0.4)),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, color: _kDanger, size: 16),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Sin conexión — las funciones de IA no están disponibles',
                      style: TextStyle(
                        color: _kDanger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}