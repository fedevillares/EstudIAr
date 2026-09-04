import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/study_history_provider.dart';
import '../services/study_history_service.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);

/// Gráfico de barras de los últimos 7 días de estudio.
/// Pensado para meterse dentro de un GlassCard en HomeScreen.
class WeeklyProgressChart extends ConsumerWidget {
  const WeeklyProgressChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(studyHistoryProvider);
    final total = ref.watch(weekTotalMinutesProvider);
    final maxMinutes = days.fold<int>(
      0,
      (m, d) => d.minutes > m ? d.minutes : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [_kPurple, _kCyan],
                ).createShader(r),
                child: const Text(
                  'Tu semana',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Text(
              _formatTotal(total),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days
                .map((d) => Expanded(
                      child: _Bar(day: d, maxMinutes: maxMinutes),
                    ))
                .toList(),
          ),
        ),
        if (total == 0) ...[
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Todavía no registraste estudio esta semana.\n¡Arrancá una sesión!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTotal(int minutes) {
    if (minutes == 0) return '0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _Bar extends StatelessWidget {
  final DayProgress day;
  final int maxMinutes;

  const _Bar({required this.day, required this.maxMinutes});

  @override
  Widget build(BuildContext context) {
    const maxBarHeight = 90.0;
    final ratio = maxMinutes == 0 ? 0.0 : day.minutes / maxMinutes;
    final barHeight = (ratio * maxBarHeight).clamp(day.minutes > 0 ? 6.0 : 0.0, maxBarHeight);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (day.minutes > 0)
          Text(
            '${day.minutes}',
            style: TextStyle(
              color: day.isToday ? _kCyan : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          width: 18,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: day.minutes > 0
                  ? [_kPurple, _kCyan]
                  : [Colors.white12, Colors.white12],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: day.isToday && day.minutes > 0
                ? [BoxShadow(color: _kCyan.withValues(alpha: 0.5), blurRadius: 8)]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day.weekdayInitial,
          style: TextStyle(
            color: day.isToday ? _kCyan : Colors.white38,
            fontSize: 11,
            fontWeight: day.isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}