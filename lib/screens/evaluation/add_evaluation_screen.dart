import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/evaluation.dart';
import '../../providers/evaluations_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/regenerate_plan_dialog.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan = Color(0xFF06B6D4);
const _kGrad = LinearGradient(colors: [_kPurple, _kCyan]);
const _kDanger = Color(0xFFEF4444);
const _kSuccess = Color(0xFF00B894);
const _kWarn = Color(0xFFFDCB6E);
const _kSecond = Color(0xFF00CEC9);

class AddEvaluationScreen extends ConsumerStatefulWidget {
  final String? evaluationId;
  const AddEvaluationScreen({super.key, this.evaluationId});
  @override
  ConsumerState<AddEvaluationScreen> createState() => _State();
}

class _State extends ConsumerState<AddEvaluationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _type = 'Evaluación';
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  int _difficulty = 3;

  /// Fecha original (al abrir en modo edición). Sirve para detectar
  /// si el usuario modificó la fecha y ofrecer regenerar el plan.
  DateTime? _originalDate;

  bool get _editing => widget.evaluationId != null;
  final _types = ['Evaluación', 'Oral'];

  @override
  void initState() {
    super.initState();
    if (_editing) {
      final e = StorageService.getById(widget.evaluationId!);
      if (e != null) {
        _subjectCtrl.text = e.subject;
        _notesCtrl.text = e.notes ?? '';
        _type = e.type;
        _date = e.date;
        _difficulty = e.difficulty;
        _originalDate = e.date; // capturamos la fecha original
      }
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Color _diffColor(int d) {
    if (d <= 1) return _kSuccess;
    if (d <= 2) return _kSecond;
    if (d <= 3) return _kWarn;
    if (d <= 4) return Colors.orange;
    return _kDanger;
  }

  String _diffLabel(int d) {
    if (d <= 1) return 'Muy fácil';
    if (d <= 2) return 'Fácil';
    if (d <= 3) return 'Moderada';
    if (d <= 4) return 'Difícil';
    return 'Muy difícil';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
                child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D0520),
                    Color(0xFF080D1C),
                    Color(0xFF000000)
                  ],
                ),
              ),
            )),
            Positioned(top: -60, right: -50, child: _orb(200, _kPurple, 0.18)),
            Positioned(bottom: 100, left: -60, child: _orb(160, _kCyan, 0.12)),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
                    child: Row(
                      children: [
                        GlassCard(
                          opacity: 0.08,
                          borderRadius: BorderRadius.circular(12),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_rounded,
                                color: Colors.white.withValues(alpha: 0.8)),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ShaderMask(
                            shaderCallback: (b) => _kGrad.createShader(b),
                            child: Text(
                              _editing
                                  ? 'Editar evaluación'
                                  : 'Nueva evaluación',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        if (_editing)
                          GlassCard(
                            opacity: 0.08,
                            borderRadius: BorderRadius.circular(12),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: _kDanger),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                _delete();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _section(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('📚 Materia'),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _subjectCtrl,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(color: Colors.white),
                                decoration:
                                    _deco('Ej: Matemáticas, Historia...'),
                                validator: (v) => (v?.isEmpty ?? true)
                                    ? 'Ingresá la materia'
                                    : null,
                              ),
                            ],
                          )),
                          const SizedBox(height: 12),
                          _section(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('📝 Tipo'),
                              const SizedBox(height: 12),
                              Row(
                                children: _types.map((t) {
                                  final sel = _type == t;
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                          right: t == _types.last ? 0 : 10),
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _type = t);
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 250),
                                          curve: Curves.easeOutCubic,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          decoration: BoxDecoration(
                                            gradient: sel
                                                ? const LinearGradient(colors: [
                                                    _kPurple,
                                                    _kCyan
                                                  ])
                                                : null,
                                            color: sel
                                                ? null
                                                : Colors.white.withValues(alpha: 0.06),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: sel
                                                    ? Colors.transparent
                                                    : Colors.white
                                                        .withValues(alpha: 0.12)),
                                            boxShadow: sel
                                                ? [
                                                    BoxShadow(
                                                        color: _kPurple
                                                            .withValues(alpha: 0.3),
                                                        blurRadius: 12,
                                                        offset:
                                                            const Offset(0, 4))
                                                  ]
                                                : null,
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                  t == 'Evaluación'
                                                      ? '📝'
                                                      : '🎤',
                                                  style: const TextStyle(
                                                      fontSize: 22)),
                                              const SizedBox(height: 6),
                                              Text(t,
                                                  style: TextStyle(
                                                    color: sel
                                                        ? Colors.white
                                                        : Colors.white
                                                            .withValues(alpha: 0.55),
                                                    fontWeight: sel
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    fontSize: 14,
                                                  )),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          )),
                          const SizedBox(height: 12),
                          _section(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('📅 Fecha'),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _pickDate();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.12)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.calendar_today_rounded,
                                        size: 18, color: _kPurple),
                                    const SizedBox(width: 10),
                                    Text(
                                      DateFormat("EEEE d 'de' MMMM yyyy", 'es')
                                          .format(_date),
                                      style: TextStyle(
                                          fontSize: 15,
                                          color:
                                              Colors.white.withValues(alpha: 0.85)),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.chevron_right_rounded,
                                        size: 18,
                                        color: Colors.white.withValues(alpha: 0.3)),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _daysChip(),
                            ],
                          )),
                          const SizedBox(height: 12),
                          _section(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                _label('🎯 Dificultad'),
                                const Spacer(),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _diffColor(_difficulty)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(_diffLabel(_difficulty),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _diffColor(_difficulty))),
                                ),
                              ]),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 16),
                                ),
                                child: Slider(
                                  value: _difficulty.toDouble(),
                                  min: 1,
                                  max: 5,
                                  divisions: 4,
                                  activeColor: _diffColor(_difficulty),
                                  inactiveColor: _diffColor(_difficulty)
                                      .withValues(alpha: 0.15),
                                  onChanged: (v) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _difficulty = v.round());
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: ['😴', '🙂', '😅', '😰', '🔥']
                                    .asMap()
                                    .entries
                                    .map((e) {
                                  final active = _difficulty == e.key + 1;
                                  return AnimatedScale(
                                    scale: active ? 1.3 : 0.9,
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: Text(e.value,
                                        style: TextStyle(
                                            fontSize: 20,
                                            color: active
                                                ? null
                                                : Colors.grey
                                                    .withValues(alpha: 0.4))),
                                  );
                                }).toList(),
                              ),
                            ],
                          )),
                          const SizedBox(height: 12),
                          _section(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('📌 Notas (opcional)'),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _notesCtrl,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: const TextStyle(color: Colors.white),
                                decoration: _deco(
                                    'Temas a estudiar, materiales, etc.'),
                              ),
                            ],
                          )),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                  colors: [_kPurple, _kCyan]),
                              boxShadow: [
                                BoxShadow(
                                    color: _kPurple.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6))
                              ],
                            ),
                            child: FilledButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                _save();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: Text(
                                _editing
                                    ? 'Guardar cambios'
                                    : 'Agregar evaluación',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required Widget child}) => GlassCard(
      opacity: 0.07, padding: const EdgeInsets.all(16), child: child);

  Widget _label(String t) => Text(t,
      style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Colors.white.withValues(alpha: 0.8)));

  Widget _daysChip() {
    // Clamp a 0 para que fechas pasadas (posible en modo edición) no
    // muestren "En -N días" y se traten como urgentes.
    final days = _date.difference(DateTime.now()).inDays.clamp(0, 9999);
    final label = days == 0
        ? '¡Hoy!'
        : days == 1
            ? 'Mañana'
            : 'En $days días';
    final color = days <= 3
        ? _kDanger
        : days <= 7
            ? _kWarn
            : _kSuccess;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kPurple, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kDanger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kDanger, width: 1.5)),
        errorStyle: const TextStyle(color: _kDanger),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Si la evaluación ya tiene fecha pasada (modo edición), usamos hoy
    // como initialDate para evitar un assert de Flutter ("initialDate must
    // be on or after firstDate") que crashea la app.
    final safeInitial = _date.isBefore(today) ? today : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: today,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kPurple,
            onPrimary: Colors.white,
            surface: Color(0xFF1A1025),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
    final notifier = ref.read(evaluationsProvider.notifier);

    // Detectar si cambió la fecha (solo aplica en edición).
    final dateChanged = _editing &&
        _originalDate != null &&
        !_sameDay(_originalDate!, _date);

    if (_editing) {
      final e = StorageService.getById(widget.evaluationId!);
      if (e == null) {
        // La evaluación fue eliminada mientras se editaba (p.ej. sincronización
        // desde otro dispositivo). Salimos silenciosamente sin crashear.
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      e.subject = _subjectCtrl.text.trim();
      e.type = _type;
      e.date = _date;
      e.difficulty = _difficulty;
      e.weight = 0;
      e.notes = notes;
      notifier.updateEval(e);
    } else {
      notifier.add(notifier.createNew(
        subject: _subjectCtrl.text.trim(),
        type: _type,
        date: _date,
        difficulty: _difficulty,
        weight: 0,
        notes: notes,
      ));
    }

    // Si cambió la fecha en modo edición, ofrecer regenerar el plan.
    if (dateChanged && mounted) {
      final evaluations = ref.read(evaluationsProvider).maybeWhen(
            data: (list) => List<Evaluation>.from(list),
            orElse: () => <Evaluation>[],
          );
      await RegeneratePlanPrompt.maybeOffer(
        context,
        ref,
        evaluations: evaluations,
        dateChanged: true,
      );
    }

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1025),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text('Eliminar evaluación',
            style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminás esta evaluación? No se puede deshacer.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12), color: _kDanger),
            child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref
                    .read(evaluationsProvider.notifier)
                    .delete(widget.evaluationId!);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Eliminar'),
            ),
          ),
        ],
      ),
    );
  }
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