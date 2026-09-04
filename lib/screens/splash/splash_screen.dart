import 'dart:math';
import 'package:flutter/material.dart';
import '../shell/main_shell.dart';
import '../update/update_required_screen.dart';
import '../../features/auth/presentation/consent_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../core/legal/legal_consent_service.dart';
import '../../core/auth/local_auth_service.dart';
import '../../services/streak_service.dart';
import '../../services/update_service.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _ringSweep;
  late Animation<double> _sparkScale;
  late Animation<double> _sparkOpacity;
  late Animation<double> _orbitAngle;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _bylineOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.30, curve: Curves.easeOut)));
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.30, curve: Curves.easeOut)));
    _ringSweep = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic)));
    _sparkScale = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.75, curve: Curves.easeOutBack)));
    _sparkOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.68, curve: Curves.easeOut)));
    _orbitAngle = Tween<double>(begin: -0.4, end: 1.65).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic)));
    _subtitleOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.65, 0.85, curve: Curves.easeOut)));
    _bylineOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.85, 1.0, curve: Curves.easeOut)));

    _ctrl.forward();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    await Future.wait([
      StreakService.initPhraseWithAi(),
      Future.delayed(const Duration(milliseconds: 2600)),
    ]);
    if (!mounted) return;
    await _navigate();
  }

  Future<void> _navigate() async {
    // ── PASO 0: ¿el build local quedó por debajo del mínimo requerido? ──
    // Bloquea antes que cualquier otra cosa: no tiene sentido dejar entrar
    // a un usuario con una versión vieja a la que después le cambiamos
    // el esquema de datos o le arreglamos un bug crítico.
    final update = await UpdateService.check();
    if (!mounted) return;
    if (update.required) {
      _goTo(UpdateRequiredScreen(apkUrl: update.apkUrl));
      return;
    }

    // ── PASO 1: ¿hay sesión activa? ──────────────────────────────
    if (!LocalAuthService.isLoggedIn()) {
      _goTo(const LoginScreen());
      return;
    }

    // ── PASO 2: ¿aceptó los términos? ────────────────────────────
    final hasConsent = await LegalConsentService.hasAccepted();
    if (!mounted) return;

    _goTo(hasConsent ? const MainShell() : const ConsentScreen());
  }

  void _goTo(Widget destination) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          Positioned(
            top: -80,
            left: MediaQuery.of(context).size.width / 2 - 150,
            child: _orb(300, _kPurple, 0.25),
          ),
          Positioned(bottom: -60, right: -60, child: _orb(200, _kCyan, 0.12)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _titleOpacity,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          const LinearGradient(colors: [_kPurple, _kCyan])
                              .createShader(bounds),
                      child: const Text(
                        'EstudIAr',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) => SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _OrbitSparkPainter(
                        ringSweep: _ringSweep.value,
                        sparkScale: _sparkScale.value,
                        sparkOpacity: _sparkOpacity.value,
                        orbitAngle: _orbitAngle.value,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _subtitleOpacity,
                  child: Text(
                    'De un estudiante, para estudiantes',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.45),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                FadeTransition(
                  opacity: _bylineOpacity,
                  child: Text(
                    'By: Fede Villares',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white.withValues(alpha: 0.25)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo animado: un anillo orbital que se traza a sí mismo (el ciclo
/// continuo de aprendizaje) alrededor de una chispa central (el insight /
/// la IA que ilumina el estudio), con un pequeño punto satélite que
/// orbita el anillo ya trazado. Deliberadamente NO usa ninguna letra ni
/// inicial — es un ícono abstracto propio de la identidad de la app.
class _OrbitSparkPainter extends CustomPainter {
  final double ringSweep; // 0..1: fracción del anillo ya trazada
  final double sparkScale; // 0..1: escala de la chispa central
  final double sparkOpacity;
  final double orbitAngle; // ángulo (radianes) del punto satélite

  _OrbitSparkPainter({
    required this.ringSweep,
    required this.sparkScale,
    required this.sparkOpacity,
    required this.orbitAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = size.width * 0.42;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);
    const gradient = SweepGradient(
      colors: [_kPurple, _kCyan, _kPurple],
      startAngle: 0,
      endAngle: 6.28319,
    );

    // Anillo orbital: se traza progresivamente desde arriba, en sentido horario.
    if (ringSweep > 0) {
      final ringPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -1.5708, ringSweep * 6.28319, false, ringPaint);
    }

    // Chispa central: rombo de 4 puntas con halo suave, representa el
    // "insight" que la IA aporta al estudio.
    if (sparkOpacity > 0) {
      final sparkSize = size.width * 0.22 * sparkScale;
      final glowPaint = Paint()
        ..color = _kCyan.withValues(alpha: 0.35 * sparkOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(center, sparkSize * 1.1, glowPaint);

      final sparkPath = _fourPointStar(center, sparkSize);
      final sparkPaint = Paint()
        ..shader = const LinearGradient(
          colors: [_kCyan, _kPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.saveLayer(rect.inflate(sparkSize), Paint()..color = Colors.white.withValues(alpha: sparkOpacity));
      canvas.drawPath(sparkPath, sparkPaint);
      canvas.restore();
    }

    // Punto satélite: orbita sobre el anillo ya completo, dando sensación
    // de movimiento continuo (aprendizaje que no se detiene).
    if (ringSweep >= 0.999) {
      final dotPos = center +
          Offset(ringRadius * cos(orbitAngle), ringRadius * sin(orbitAngle));
      canvas.drawCircle(
        dotPos,
        5,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.drawCircle(
        dotPos,
        9,
        Paint()
          ..color = _kCyan.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  Path _fourPointStar(Offset center, double r) {
    final inner = r * 0.32;
    return Path()
      ..moveTo(center.dx, center.dy - r)
      ..quadraticBezierTo(center.dx, center.dy - inner, center.dx + r, center.dy)
      ..quadraticBezierTo(center.dx, center.dy + inner, center.dx, center.dy + r)
      ..quadraticBezierTo(center.dx, center.dy + inner, center.dx - r, center.dy)
      ..quadraticBezierTo(center.dx, center.dy - inner, center.dx, center.dy - r)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _OrbitSparkPainter old) =>
      old.ringSweep != ringSweep ||
      old.sparkScale != sparkScale ||
      old.sparkOpacity != sparkOpacity ||
      old.orbitAngle != orbitAngle;
}

Widget _orb(double size, Color color, double opacity) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
      ),
    );