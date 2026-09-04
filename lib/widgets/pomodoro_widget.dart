import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass_card.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan   = Color(0xFF06B6D4);

enum _PomodoroMode { focus, shortBreak, longBreak }

class PomodoroWidget extends StatefulWidget {
  const PomodoroWidget({super.key});
  @override
  State<PomodoroWidget> createState() => _PomodoroWidgetState();
}

class _PomodoroWidgetState extends State<PomodoroWidget>
    with TickerProviderStateMixin {
  _PomodoroMode _mode = _PomodoroMode.focus;
  int _seconds = 25 * 60;
  int _totalSeconds = 25 * 60;
  bool _isRunning = false;
  int _completedPomodoros = 0;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  static const _durations = {
    _PomodoroMode.focus:      25 * 60,
    _PomodoroMode.shortBreak:  5 * 60,
    _PomodoroMode.longBreak:  15 * 60,
  };

  static const _labels = {
    _PomodoroMode.focus:      'Enfoque',
    _PomodoroMode.shortBreak: 'Descanso corto',
    _PomodoroMode.longBreak:  'Descanso largo',
  };

  static const _emojis = {
    _PomodoroMode.focus:      '🧠',
    _PomodoroMode.shortBreak: '☕',
    _PomodoroMode.longBreak:  '🌿',
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _setMode(_PomodoroMode mode) {
    _timer?.cancel();
    setState(() {
      _mode = mode;
      _seconds = _durations[mode]!;
      _totalSeconds = _durations[mode]!;
      _isRunning = false;
    });
  }

  void _toggleTimer() {
    HapticFeedback.mediumImpact();
    if (_isRunning) {
      _timer?.cancel();
      _pulseCtrl.stop();
    } else {
      _pulseCtrl.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_seconds > 0) {
          setState(() => _seconds--);
        } else {
          t.cancel();
          _onComplete();
        }
      });
    }
    setState(() => _isRunning = !_isRunning);
  }

  void _onComplete() {
    HapticFeedback.heavyImpact();
    _pulseCtrl.stop();
    if (_mode == _PomodoroMode.focus) {
      setState(() => _completedPomodoros++);
    }
    setState(() => _isRunning = false);
  }

  void _reset() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    _pulseCtrl.stop();
    setState(() {
      _seconds = _durations[_mode]!;
      _totalSeconds = _durations[_mode]!;
      _isRunning = false;
    });
  }

  String get _timeStr {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress => _seconds / _totalSeconds;

  Color get _modeColor {
    switch (_mode) {
      case _PomodoroMode.focus:      return _kPurple;
      case _PomodoroMode.shortBreak: return _kCyan;
      case _PomodoroMode.longBreak:  return const Color(0xFF00B894);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Título modo
          Text(
            '${_emojis[_mode]} ${_labels[_mode]}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _modeColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 32),

          // Círculo principal
          ScaleTransition(
            scale: _isRunning ? _pulse : const AlwaysStoppedAnimation(1.0),
            child: SizedBox(
              width: 220, height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow de fondo
                  Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _modeColor.withValues(alpha: _isRunning ? 0.25 : 0.1),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  // Fondo del círculo
                  Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _modeColor.withValues(alpha: 0.06),
                      border: Border.all(
                        color: _modeColor.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  // Progreso
                  SizedBox(
                    width: 200, height: 200,
                    child: CustomPaint(
                      painter: _ArcPainter(
                        progress: _progress,
                        color: _modeColor,
                      ),
                    ),
                  ),
                  // Tiempo
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeStr,
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRunning ? 'en curso' : _seconds == _totalSeconds ? 'listo' : 'pausado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Controles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reset
              _CircleBtn(
                icon: Icons.refresh_rounded,
                color: Colors.white.withValues(alpha: 0.12),
                iconColor: Colors.white.withValues(alpha: 0.6),
                size: 52,
                onTap: _reset,
              ),
              const SizedBox(width: 20),
              // Play/Pause
              GestureDetector(
                onTap: _toggleTimer,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_modeColor, _modeColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _modeColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Skip
              _CircleBtn(
                icon: Icons.skip_next_rounded,
                color: Colors.white.withValues(alpha: 0.12),
                iconColor: Colors.white.withValues(alpha: 0.6),
                size: 52,
                onTap: () {
                  if (_mode == _PomodoroMode.focus) {
                    _setMode(_completedPomodoros % 4 == 3
                        ? _PomodoroMode.longBreak
                        : _PomodoroMode.shortBreak);
                  } else {
                    _setMode(_PomodoroMode.focus);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Selector de modo
          GlassCard(
            opacity: 0.07,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                _ModeBtn(label: 'Enfoque',    active: _mode == _PomodoroMode.focus,      color: _kPurple, onTap: () => _setMode(_PomodoroMode.focus)),
                _ModeBtn(label: 'Descanso',   active: _mode == _PomodoroMode.shortBreak, color: _kCyan,   onTap: () => _setMode(_PomodoroMode.shortBreak)),
                _ModeBtn(label: 'Largo',      active: _mode == _PomodoroMode.longBreak,  color: const Color(0xFF00B894), onTap: () => _setMode(_PomodoroMode.longBreak)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pomodoros completados
          if (_completedPomodoros > 0)
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Pomodoros hoy: ',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
                ),
                ...List.generate(_completedPomodoros, (i) =>
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text('🍅', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Fondo del arco
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Arco de progreso
    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + 2 * pi * progress,
        colors: [color.withValues(alpha: 0.7), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;
  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Icon(icon, color: iconColor, size: size * 0.45),
    ),
  );
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ModeBtn({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active ? Border.all(color: color.withValues(alpha: 0.4)) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active ? color : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    ),
  );
}