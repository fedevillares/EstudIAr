import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/social_repository.dart';
import '../../models/social/report.dart';
import '../../providers/social_providers.dart';

const _kPurple = Color(0xFFA855F7);

const _reportReasons = [
  'Acoso o bullying',
  'Discurso de odio',
  'Spam o publicidad',
  'Contenido sexual inapropiado',
  'Amenazas o violencia',
  'Otro',
];

/// Muestra un diálogo para reportar contenido o un usuario. El reporte
/// se guarda en la colección `reports` para revisión administrativa;
/// no oculta el contenido automáticamente (eso requiere revisión humana
/// o que se acumulen varios reportes, según política del admin).
Future<void> showReportDialog(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
}) async {
  await showDialog(
    context: context,
    builder: (ctx) => _ReportDialogContent(targetType: targetType, targetId: targetId),
  );
}

class _ReportDialogContent extends ConsumerStatefulWidget {
  final ReportTargetType targetType;
  final String targetId;
  const _ReportDialogContent({required this.targetType, required this.targetId});

  @override
  ConsumerState<_ReportDialogContent> createState() => _ReportDialogContentState();
}

class _ReportDialogContentState extends ConsumerState<_ReportDialogContent> {
  String? _selected;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1530),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Reportar', style: TextStyle(color: Colors.white)),
      content: RadioGroup<String>(
        groupValue: _selected,
        onChanged: (v) => setState(() => _selected = v),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _reportReasons
              .map((reason) => RadioListTile<String>(
                    value: reason,
                    activeColor: _kPurple,
                    contentPadding: EdgeInsets.zero,
                    title: Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _kPurple),
          onPressed: _selected == null || _sending
              ? null
              : () async {
                  final me = ref.read(currentUsernameProvider);
                  if (me == null) return;
                  setState(() => _sending = true);
                  await SocialRepository.reportContent(
                    reporterId: me,
                    targetType: widget.targetType,
                    targetId: widget.targetId,
                    reason: _selected!,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gracias, lo vamos a revisar.')),
                    );
                  }
                },
          child: _sending
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }
}
