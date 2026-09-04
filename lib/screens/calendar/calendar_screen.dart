import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../providers/evaluations_provider.dart';
import '../../models/evaluation.dart';
import '../../widgets/glass_card.dart';
import '../evaluation/add_evaluation_screen.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan   = Color(0xFF06B6D4);
const _kGrad   = LinearGradient(colors: [_kPurple, _kCyan]);
const _kSuccess = Color(0xFF00B894);
const _kDanger  = Color(0xFFEF4444);

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Evaluation> _eventsForDay(DateTime day, List<Evaluation> evals) =>
      evals.where((e) =>
        e.date.year == day.year &&
        e.date.month == day.month &&
        e.date.day == day.day
      ).toList();

  Color _evalColor(Evaluation e) {
    if (e.isCompleted) return _kSuccess;
    if (e.isUrgent)    return _kDanger;
    switch (e.type.toLowerCase()) {
      case 'oral': return _kCyan;
      default:     return _kPurple;
    }
  }

  String _evalLabel(Evaluation e) {
    switch (e.type.toLowerCase()) {
      case 'oral': return 'ORAL';
      default:     return 'EVALUACIÓN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final evaluations = ref.watch(evaluationsProvider).maybeWhen(
      data: (list) => list,
      orElse: () => <Evaluation>[],
    );
    final selected       = _selectedDay ?? DateTime.now();
    final selectedEvents = _eventsForDay(selected, evaluations);
    final pendingCount   = evaluations.where((e) => !e.isCompleted).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0D0520), Color(0xFF080D1C), Color(0xFF000000)],
              ),
            ),
          )),
          Positioned(top: -60, left: -60, child: _orb(200, _kPurple, 0.18)),
          Positioned(bottom: 200, right: -40, child: _orb(160, _kCyan, 0.12)),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ShaderMask(
                          shaderCallback: (b) => _kGrad.createShader(b),
                          child: const Text('Calendario',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      GlassCard(
                        opacity: 0.08,
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          '$pendingCount pendiente${pendingCount == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPurple),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    opacity: 0.07,
                    child: TableCalendar<Evaluation>(
                      locale: 'es_ES',
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2027, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: (day) => _eventsForDay(day, evaluations),
                      onDaySelected: (sel, foc) => setState(() {
                        _selectedDay = sel;
                        _focusedDay = foc;
                      }),
                      onPageChanged: (foc) => setState(() => _focusedDay = foc),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: events.take(3).map((e) {
                              final color = _evalColor(e);
                              return Container(
                                width: 5, height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        defaultTextStyle: const TextStyle(color: Colors.white),
                        weekendTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        disabledTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                        todayDecoration: BoxDecoration(
                          color: _kPurple.withValues(alpha: 0.25), shape: BoxShape.circle),
                        todayTextStyle: const TextStyle(color: _kPurple, fontWeight: FontWeight.bold),
                        selectedDecoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [_kPurple, _kCyan]),
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        markersMaxCount: 3,
                        markerSize: 5,
                        markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: _kPurple),
                        rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: _kPurple),
                        headerPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
                        weekendStyle: TextStyle(
                          fontSize: 12, color: _kPurple.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Leyenda — Wrap evita overflow en pantallas estrechas
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: const [
                      _Dot(color: _kPurple,  label: 'Evaluación'),
                      _Dot(color: _kCyan,    label: 'Oral'),
                      _Dot(color: _kSuccess, label: 'Completada'),
                      _Dot(color: _kDanger,  label: 'Urgente'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          DateFormat("EEEE d 'de' MMMM", 'es').format(selected),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      ),
                      const Spacer(),
                      if (selectedEvents.isNotEmpty)
                        Text('${selectedEvents.length} eval.',
                          style: TextStyle(fontSize: 12, color: _kPurple.withValues(alpha: 0.8))),
                    ],
                  ),
                ),

                Expanded(
                  child: selectedEvents.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📭', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text('Sin evaluaciones este día',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 15)),
                        ],
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        physics: const BouncingScrollPhysics(),
                        itemCount: selectedEvents.length,
                        itemBuilder: (_, i) {
                          final e = selectedEvents[i];
                          final color = _evalColor(e);
                          final label = _evalLabel(e); // ← usa _evalLabel, no e.type
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              opacity: 0.07,
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4, height: 52,
                                    decoration: BoxDecoration(
                                      color: color, borderRadius: BorderRadius.circular(4)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8)),
                                          child: Text(label, // ← label limpio
                                            style: TextStyle(fontSize: 10,
                                              fontWeight: FontWeight.bold, color: color)),
                                        ),
                                        if (e.isCompleted) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.check_circle_rounded,
                                            color: _kSuccess, size: 14),
                                        ],
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(e.subject,
                                        style: const TextStyle(fontSize: 15,
                                          fontWeight: FontWeight.w700, color: Colors.white)),
                                      Text(
                                        e.isCompleted ? 'Completada ✓'
                                          : e.isUrgent ? '⚠️ Urgente'
                                          : 'Pendiente',
                                        style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
                                      ),
                                    ],
                                  )),
                                  GlassCard(
                                    opacity: 0.08,
                                    borderRadius: BorderRadius.circular(10),
                                    child: IconButton(
                                      icon: Icon(Icons.edit_outlined, size: 18,
                                        color: Colors.white.withValues(alpha: 0.6)),
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) =>
                                          AddEvaluationScreen(evaluationId: e.id)),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

Widget _orb(double size, Color color, double opacity) => Container(
  width: size, height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(
      colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45))),
  ]);
}