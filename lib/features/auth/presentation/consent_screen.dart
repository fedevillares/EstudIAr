import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/legal/legal_consent_service.dart';
import '../../../screens/shell/main_shell.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});
  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.school_rounded,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 32),
              const Text(
                'Bienvenido a EstudIAr',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'Al usar esta aplicación, aceptas nuestros términos de servicio y política de privacidad.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CheckboxListTile(
                title: const Text(
                  'He leído y acepto los términos y condiciones',
                  style: TextStyle(color: Colors.white),
                ),
                value: _accepted,
                onChanged: (value) {
                  setState(() => _accepted = value ?? false);
                },
                activeColor: Colors.white,
                checkColor: Colors.deepPurple,
              ),
              const SizedBox(height: 8),
              const Text(
                'Al aceptar, confirmas que tienes 13 años o más.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _accepted
                      ? () async {
                          final navigator = Navigator.of(context);
                          await LegalConsentService.accept();
                          if (mounted) {
                            navigator.pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const MainShell(),
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                    disabledBackgroundColor: Colors.white38,
                    disabledForegroundColor:
                        Colors.deepPurple.withValues(alpha: 0.38),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}