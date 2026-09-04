import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);

/// Pantalla bloqueante: se muestra cuando UpdateService detecta que el
/// buildNumber local quedó por debajo del mínimo requerido. No tiene
/// forma de "saltear" ni back button — el único camino es descargar la
/// nueva versión.
class UpdateRequiredScreen extends StatelessWidget {
  final String? apkUrl;
  const UpdateRequiredScreen({super.key, this.apkUrl});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D0520), Color(0xFF080D1C), Color(0xFF000000)],
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _kCyan.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.system_update_rounded, size: 48, color: _kCyan),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Hay una versión nueva de EstudIAr',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Necesitás actualizar la app para seguir usándola.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    if (apkUrl != null && apkUrl!.trim().isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(colors: [_kPurple, _kCyan]),
                        ),
                        child: FilledButton(
                          onPressed: () => launchUrl(
                            Uri.parse(apkUrl!),
                            mode: LaunchMode.externalApplication,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Descargar actualización',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      )
                    else
                      Text(
                        'Pedile el link de descarga a quien te compartió la app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
