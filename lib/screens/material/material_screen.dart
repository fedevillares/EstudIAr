import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/ai_service.dart';
import '../../widgets/glass_card.dart';
import '../../services/summary_history_service.dart';

const _kPurple = Color(0xFFA855F7);
const _kCyan   = Color(0xFF06B6D4);
const _kGrad   = LinearGradient(colors: [_kPurple, _kCyan]);
const _kDanger = Color(0xFFEF4444);
const _kSuccess= Color(0xFF00B894);
const _kWarn   = Color(0xFFFDCB6E);

class MaterialScreen extends StatefulWidget {
  const MaterialScreen({super.key});
  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen>
    with SingleTickerProviderStateMixin {
  final _materialCtrl = TextEditingController();
  final _subjectCtrl  = TextEditingController();
  final _chatCtrl     = TextEditingController();
  final _answerCtrl   = TextEditingController();
  final _scrollCtrl   = ScrollController();
  late TabController _tabCtrl;

  String? _summary;
  bool _loading = false;
  String? _error;
  final List<File> _selectedImages = [];
  String? _selectedFileName;

  final List<Map<String, String>> _chatHistory = [];
  bool _chatLoading = false;

  List<Map<String, String>>? _flashcards;
  int _currentCard = 0;
  bool _showAnswer = false;

  bool _examLoading = false;
  String? _examError;
  String? _currentQuestion;
  bool _evaluating = false;
  Map<String, dynamic>? _lastEval;
  int _examScore = 0;
  int _examQuestion = 0;
  static const _totalQ = 5;
  final List<String> _askedQ = [];
  bool _examFinished = false;
  List<Map<String, dynamic>> _examResults = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _materialCtrl.dispose();
    _subjectCtrl.dispose();
    _chatCtrl.dispose();
    _answerCtrl.dispose();
    _scrollCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  String get _subject =>
      _subjectCtrl.text.trim().isEmpty ? 'General' : _subjectCtrl.text.trim();
  String get _material => _materialCtrl.text.trim();

  /// Si el error es por falta/rechazo de API key, mostramos el mensaje
  /// específico (le dice al usuario que vaya a Ajustes) en vez del genérico
  /// "probá de nuevo", que sugiere reintentar algo que va a fallar siempre.
  String _aiErrorMessage(Object e, String fallback) {
    if (e is MissingApiKeyException) return e.message;
    if (e is UsageLimitExceededException) return e.message;
    if (e is AccountIssueException) return e.message;
    return fallback;
  }

  String _cleanJson(String raw) {
    String s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();
    }
    final arrIdx = s.indexOf('[');
    final objIdx = s.indexOf('{');
    if (arrIdx != -1 && (objIdx == -1 || arrIdx < objIdx)) {
      s = s.substring(arrIdx);
      final last = s.lastIndexOf(']');
      if (last != -1) s = s.substring(0, last + 1);
    } else if (objIdx != -1) {
      s = s.substring(objIdx);
      final last = s.lastIndexOf('}');
      if (last != -1) s = s.substring(0, last + 1);
    }
    return s;
  }

  Future<void> _pickImage(ImageSource src) async {
    if (src == ImageSource.gallery) {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (picked.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(picked.map((x) => File(x.path)));
          _selectedFileName = null;
        });
      }
    } else {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.camera, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _selectedImages.add(File(picked.path));
          _selectedFileName = null;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['txt', 'pdf']);
    if (r != null && r.files.single.path != null) {
      try {
        if (r.files.single.extension == 'txt') {
          _materialCtrl.text =
              await File(r.files.single.path!).readAsString();
        }
        if (mounted) setState(() => _selectedFileName = r.files.single.name);
      } catch (_) {
        if (mounted) {
          setState(() => _error = 'No se pudo leer el archivo. Probá con otro.');
        }
      }
    }
  }

  Future<void> _generateSummary() async {
    if (_material.isEmpty && _selectedImages.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; _summary = null; });
    try {
      final result = await AIService.summarizeMaterial(
        subject: _subject,
        material: _material,
        images: _selectedImages.isEmpty ? null : _selectedImages,
      );
      SummaryHistoryService.save(SummaryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        subject: _subject,
        summary: result,
        createdAt: DateTime.now(),
      ));
      if (!mounted) return;
      setState(() { _summary = result; _loading = false; });
    } catch (e) {
      debugPrint('[material] summary error: ${e.runtimeType}');
      if (!mounted) return;
      setState(() { _error = _aiErrorMessage(e, 'No se pudo generar el resumen. Probá de nuevo.'); _loading = false; });
    }
  }

  Future<void> _generateFlashcards() async {
    if (_material.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true; _error = null;
      _flashcards = null; _currentCard = 0; _showAnswer = false;
    });
    try {
      final raw = await AIService.generateFlashcards(
          subject: _subject, material: _material);
      final cleaned = _cleanJson(raw);
      final List<dynamic> parsed = jsonDecode(cleaned);
      _flashcards = parsed.map((e) {
        final m = Map<String, dynamic>.from(e);
        return {
          'pregunta': (m['pregunta'] ?? m['front'] ?? '').toString(),
          'respuesta': (m['respuesta'] ?? m['back'] ?? '').toString(),
        };
      }).toList();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('[material] flashcards error: ${e.runtimeType}');
      if (!mounted) return;
      setState(() { _error = _aiErrorMessage(e, 'No se pudieron generar las flashcards. Probá de nuevo.'); _loading = false; });
    }
  }

  Future<void> _sendChat() async {
    final q = _chatCtrl.text.trim();
    if (q.isEmpty || _material.isEmpty) return;
    FocusScope.of(context).unfocus();
    _chatCtrl.clear();
    setState(() {
      _chatHistory.add({'role': 'user', 'content': q});
      _chatLoading = true;
    });
    try {
      final ans = await AIService.chatWithMaterial(
          material: _material, question: q);
      if (!mounted) return;
      setState(() {
        _chatHistory.add({'role': 'assistant', 'content': ans});
        _chatLoading = false;
      });
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && _scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    } catch (e) {
      debugPrint('[material] chat error: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _chatHistory.add({
          'role': 'assistant',
          'content': _aiErrorMessage(e, 'No se pudo responder. Probá de nuevo en un momento.'),
        });
        _chatLoading = false;
      });
    }
  }

  void _resetExam() => setState(() {
    _currentQuestion = null; _lastEval = null;
    _examScore = 0; _examQuestion = 0;
    _askedQ.clear(); _examFinished = false;
    _examResults = []; _examError = null; _answerCtrl.clear();
  });

  Future<void> _nextQuestion() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _examLoading = true; _examError = null;
      _lastEval = null; _answerCtrl.clear();
    });
    try {
      final q = await AIService.generateExamQuestion(
          subject: _subject,
          material: _material,
          previousQuestions: _askedQ);
      _askedQ.add(q);
      if (!mounted) return;
      setState(() { _currentQuestion = q; _examLoading = false; });
    } catch (e) {
      debugPrint('[material] exam question error: ${e.runtimeType}');
      if (!mounted) return;
      setState(() { _examError = _aiErrorMessage(e, 'No se pudo generar la pregunta. Probá de nuevo.'); _examLoading = false; });
    }
  }

  Future<void> _submitAnswer() async {
    final ans = _answerCtrl.text.trim();
    if (ans.isEmpty || _currentQuestion == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _evaluating = true);
    try {
      final raw = await AIService.evaluateExamAnswer(
          subject: _subject,
          material: _material,
          question: _currentQuestion!,
          answer: ans);
      final result = jsonDecode(_cleanJson(raw)) as Map<String, dynamic>;
      // Casteamos con null-safety: la IA puede omitir el campo o devolver
      // un tipo inesperado; en ese caso tratamos el puntaje como 0.
      final p = (result['puntaje'] as num?)?.toInt() ?? 0;
      _examScore += p;
      _examQuestion++;
      _examResults.add({
        'pregunta': _currentQuestion!,
        'respuesta': ans,
        'puntaje': p,
        'feedback': result['feedback'] ?? '',
        'correcta': result['respuesta_correcta'] ?? '',
      });
      if (!mounted) return;
      setState(() {
        _lastEval = result;
        _evaluating = false;
        if (_examQuestion >= _totalQ) _examFinished = true;
      });
    } catch (e) {
      debugPrint('[material] exam eval error: ${e.runtimeType}');
      if (!mounted) return;
      setState(() { _examError = _aiErrorMessage(e, 'No se pudo evaluar la respuesta. Probá de nuevo.'); _evaluating = false; });
    }
  }

  Color _scoreColor(int s) =>
      s >= 8 ? _kSuccess : s >= 6 ? _kWarn : _kDanger;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
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
                      Color(0xFF000000),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(top: -50, right: -50, child: _orb(180, _kCyan, 0.15)),
            Positioned(bottom: 200, left: -60, child: _orb(160, _kPurple, 0.12)),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: ShaderMask(
                      shaderCallback: (b) => _kGrad.createShader(b),
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Material',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      opacity: 0.07,
                      borderRadius: BorderRadius.circular(16),
                      child: TabBar(
                        controller: _tabCtrl,
                        labelColor: _kPurple,
                        unselectedLabelColor: Colors.white.withValues(alpha: 0.35),
                        indicatorColor: _kPurple,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(icon: Icon(Icons.summarize, size: 18), text: 'Resumen'),
                          Tab(icon: Icon(Icons.chat_outlined, size: 18), text: 'Chat'),
                          Tab(icon: Icon(Icons.style_outlined, size: 18), text: 'Cards'),
                          Tab(icon: Icon(Icons.school_rounded, size: 18), text: 'Examen'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _tabResumen(),
                        _tabChat(),
                        _tabFlashcards(),
                        _tabExamen(),
                      ],
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

  Widget _tabResumen() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    physics: const BouncingScrollPhysics(),
    children: [
      GlassCard(
        opacity: 0.07,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Text('📖', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pegá texto, sacá fotos de tus apuntes o subí un archivo.',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6), height: 1.4),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      _label('📚 Materia'),
      const SizedBox(height: 8),
      _darkField(_subjectCtrl, 'Ej: Matemáticas, Historia...'),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _attachBtn(Icons.photo_library_rounded, 'Galería', _kPurple, () => _pickImage(ImageSource.gallery))),
        const SizedBox(width: 8),
        Expanded(child: _attachBtn(Icons.camera_alt_rounded, 'Cámara', _kPurple, () => _pickImage(ImageSource.camera))),
        const SizedBox(width: 8),
        Expanded(child: _attachBtn(Icons.upload_file_rounded, 'Archivo', _kCyan, _pickFile)),
      ]),
      if (_selectedImages.isNotEmpty) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == _selectedImages.length) {
                return GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kPurple.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded, color: _kPurple, size: 28),
                  ),
                );
              }
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImages[i], width: 80, height: 100, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImages.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
      if (_selectedFileName != null) ...[
        const SizedBox(height: 12),
        GlassCard(
          opacity: 0.07,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(Icons.insert_drive_file_rounded, color: _kCyan, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_selectedFileName!,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedFileName = null),
              child: Icon(Icons.close, size: 18, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      _label('Texto del material'),
      const SizedBox(height: 8),
      GlassCard(
        opacity: 0.07,
        borderRadius: BorderRadius.circular(14),
        child: TextField(
          controller: _materialCtrl,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Pegá acá el texto de tus apuntes...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () async {
            final d = await Clipboard.getData('text/plain');
            if (d?.text != null) _materialCtrl.text = d!.text!;
          },
          icon: Icon(Icons.content_paste, size: 16, color: _kCyan),
          label: Text('Pegar', style: TextStyle(color: _kCyan, fontSize: 13)),
        ),
      ),
      const SizedBox(height: 12),
      _gradBtn(
        loading: _loading,
        label: _selectedImages.isNotEmpty
            ? 'Resumir con IA (${_selectedImages.length} foto${_selectedImages.length > 1 ? 's' : ''})'
            : 'Generar resumen con IA',
        loadingLabel: 'Generando...',
        icon: Icons.auto_awesome,
        onPressed: _generateSummary,
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        _errorCard(_error!),
      ],
      if (_summary != null) ...[
        const SizedBox(height: 24),
        Row(children: [
          const Expanded(
            child: Text('Resumen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _summary!));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resumen copiado')));
            },
            icon: Icon(Icons.copy, size: 16, color: _kCyan),
            label: Text('Copiar', style: TextStyle(color: _kCyan, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 10),
        GlassCard(
          opacity: 0.07,
          padding: const EdgeInsets.all(16),
          child: Text(_summary!,
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), height: 1.6)),
        ),
      ],
    ],
  );

  Widget _tabChat() {
    final hasM = _material.isNotEmpty;
    return Column(children: [
      if (!hasM)
        Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            opacity: 0.07,
            color: _kWarn,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.info_outline, color: _kWarn, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Primero pegá tu material en la pestaña "Resumen".',
                    style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
            ]),
          ),
        ),
      Expanded(
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          physics: const BouncingScrollPhysics(),
          itemCount: _chatHistory.length + (_chatLoading ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _chatHistory.length) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kPurple),
                  ),
                ),
              );
            }
            final msg = _chatHistory[i];
            final isUser = msg['role'] == 'user';
            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                decoration: BoxDecoration(
                  gradient: isUser ? const LinearGradient(colors: [_kPurple, _kCyan]) : null,
                  color: isUser ? null : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: isUser ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(msg['content']!,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: isUser ? 1 : 0.8),
                        height: 1.4)),
              ),
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          Expanded(
            child: GlassCard(
              opacity: 0.07,
              borderRadius: BorderRadius.circular(24),
              child: TextField(
                controller: _chatCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Preguntá sobre tu material...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendChat(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kPurple, _kCyan]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _kPurple.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: IconButton(
              onPressed: _chatLoading ? null : _sendChat,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _tabFlashcards() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
    physics: const BouncingScrollPhysics(),
    children: [
      _gradBtn(
        loading: _loading,
        label: 'Generar flashcards con IA',
        loadingLabel: 'Generando...',
        icon: Icons.style,
        onPressed: _generateFlashcards,
      ),
      if (_material.isEmpty) ...[
        const SizedBox(height: 14),
        GlassCard(
          opacity: 0.07,
          color: _kWarn,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.info_outline, color: _kWarn, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Primero pegá tu material en la pestaña "Resumen".',
                  style: TextStyle(fontSize: 13, color: Colors.white)),
            ),
          ]),
        ),
      ],
      if (_error != null) ...[const SizedBox(height: 14), _errorCard(_error!)],
      if (_flashcards != null && _flashcards!.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          'Tarjeta ${_currentCard + 1} de ${_flashcards!.length}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _showAnswer = !_showAnswer),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: _showAnswer
                  ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0x2200B894), Color(0x1506B6D4)])
                  : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0x22A855F7), Color(0x1206B6D4)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _showAnswer ? _kSuccess.withValues(alpha: 0.25) : _kPurple.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showAnswer ? '✅ Respuesta' : '❓ Pregunta',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _showAnswer ? _kSuccess : _kPurple),
                ),
                const SizedBox(height: 16),
                Text(
                  _showAnswer
                      ? _flashcards![_currentCard]['respuesta']!
                      : _flashcards![_currentCard]['pregunta']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5, color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 12),
                Text(
                  _showAnswer ? 'Tocá para ver la pregunta' : 'Tocá para ver la respuesta',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _currentCard > 0
                  ? () => setState(() { _currentCard--; _showAnswer = false; })
                  : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Anterior'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.7),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: _currentCard < _flashcards!.length - 1
                    ? const LinearGradient(colors: [_kPurple, _kCyan])
                    : null,
                color: _currentCard < _flashcards!.length - 1
                    ? null : Colors.white.withValues(alpha: 0.05),
              ),
              child: FilledButton.icon(
                onPressed: _currentCard < _flashcards!.length - 1
                    ? () => setState(() { _currentCard++; _showAnswer = false; })
                    : null,
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                label: const Text('Siguiente', style: TextStyle(color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ]),
      ],
    ],
  );

  Widget _tabExamen() {
    if (_material.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: GlassCard(
            opacity: 0.07,
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('📝', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Primero pegá tu material',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Andá a "Resumen" y pegá el texto.',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
    }

    if (_examFinished) return _examResultsView();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      children: [
        GlassCard(
          opacity: 0.07,
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(
                child: Text(
                  _currentQuestion == null ? 'Listo para empezar' : 'Pregunta $_examQuestion de $_totalQ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
                ),
              ),
              if (_examQuestion > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    'Promedio: ${(_examScore / _examQuestion).toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kPurple),
                  ),
                ),
            ]),
            if (_examQuestion > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _examQuestion / _totalQ,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(_kPurple),
                  minHeight: 6,
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        if (_currentQuestion == null && !_examLoading)
          GlassCard(
            opacity: 0.07,
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Text('🎓', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              const Text('Modo Examen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                'La IA te hace $_totalQ preguntas y evalúa tus respuestas del 0 al 10.',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: _gradBtn(
                  loading: false,
                  label: 'Empezar examen',
                  loadingLabel: '',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _nextQuestion,
                ),
              ),
            ]),
          ),
        if (_examLoading)
          GlassCard(
            opacity: 0.07,
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              CircularProgressIndicator(color: _kPurple),
              const SizedBox(height: 16),
              Text('Generando pregunta...',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ]),
          ),
        if (_currentQuestion != null && !_examLoading) ...[
          GlassCard(
            opacity: 0.07,
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('Pregunta $_examQuestion',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kPurple)),
              ),
              const SizedBox(height: 12),
              Text(_currentQuestion!,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9), height: 1.5)),
            ]),
          ),
          const SizedBox(height: 12),
          if (_lastEval != null) _evalCard(_lastEval!),
          if (_lastEval == null) ...[
            GlassCard(
              opacity: 0.07,
              borderRadius: BorderRadius.circular(14),
              child: TextField(
                controller: _answerCtrl,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Escribí tu respuesta acá...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _gradBtn(
              loading: _evaluating,
              label: 'Entregar respuesta',
              loadingLabel: 'Evaluando...',
              icon: Icons.check_rounded,
              onPressed: _submitAnswer,
            ),
          ],
          if (_lastEval != null && _examQuestion < _totalQ) ...[
            const SizedBox(height: 12),
            _gradBtn(
              loading: false,
              label: 'Siguiente pregunta',
              loadingLabel: '',
              icon: Icons.arrow_forward_rounded,
              onPressed: _nextQuestion,
            ),
          ],
        ],
        if (_examError != null) ...[
          const SizedBox(height: 12),
          _errorCard(_examError!),
        ],
      ],
    );
  }

  Widget _examResultsView() {
    final avg = _examScore / _totalQ;
    final color = _scoreColor(avg.round());
    final emoji = avg >= 8 ? '🏆' : avg >= 6 ? '👍' : '💪';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        GlassCard(
          opacity: 0.07,
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('Examen completado',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text('Promedio final',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45))),
                Text(avg.toStringAsFixed(1),
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: color)),
                Text('de 10',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.3))),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetExam,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Hacer otro examen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPurple,
                  side: const BorderSide(color: Color(0x44A855F7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Text('Detalle por pregunta',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8))),
        const SizedBox(height: 12),
        ..._examResults.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final p = (r['puntaje'] as num).toInt();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              opacity: 0.07,
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(
                    child: Text('Pregunta ${i + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _scoreColor(p).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('$p/10',
                        style: TextStyle(fontWeight: FontWeight.bold, color: _scoreColor(p), fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(r['pregunta'].toString(),
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(r['feedback'].toString(),
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), height: 1.4)),
              ]),
            ),
          );
        }),
      ],
    );
  }

  Widget _evalCard(Map<String, dynamic> eval) {
    final p = (eval['puntaje'] as num).toInt();
    final c = _scoreColor(p);
    return GlassCard(
      opacity: 0.07,
      color: c.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(p >= 8 ? '🎉' : p >= 6 ? '👍' : '💪', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Puntaje', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
            Text('$p / 10', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
          ]),
        ]),
        const SizedBox(height: 12),
        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        const SizedBox(height: 12),
        Text('Feedback',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
        const SizedBox(height: 6),
        Text(eval['feedback'] ?? '',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8), height: 1.5)),
        if ((eval['respuesta_correcta'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Respuesta ideal',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 6),
          Text(eval['respuesta_correcta'],
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55), height: 1.5)),
        ],
      ]),
    );
  }

  Widget _label(String t) => Text(t,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white.withValues(alpha: 0.7)));

  Widget _darkField(TextEditingController ctrl, String hint) => GlassCard(
    opacity: 0.07,
    borderRadius: BorderRadius.circular(12),
    child: TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    ),
  );

  Widget _attachBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      );

  Widget _gradBtn({
    required bool loading,
    required String label,
    required String loadingLabel,
    required IconData icon,
    required VoidCallback onPressed,
  }) =>
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: loading ? null : const LinearGradient(colors: [_kPurple, _kCyan]),
          color: loading ? Colors.white.withValues(alpha: 0.06) : null,
          boxShadow: loading
              ? null
              : [BoxShadow(color: _kPurple.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: FilledButton.icon(
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(icon, color: Colors.white),
          label: Text(loading ? loadingLabel : label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );

  Widget _errorCard(String msg) => GlassCard(
    opacity: 0.07,
    color: _kDanger.withValues(alpha: 0.15),
    padding: const EdgeInsets.all(14),
    child: Row(children: [
      Icon(Icons.error_outline, color: _kDanger, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: TextStyle(color: _kDanger, fontSize: 13))),
    ]),
  );
}

Widget _orb(double size, Color color, double opacity) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
  ),
);