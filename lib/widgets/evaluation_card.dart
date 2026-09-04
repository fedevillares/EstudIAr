import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/evaluation.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class EvaluationCard extends StatelessWidget {
  final Evaluation evaluation;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const EvaluationCard({
    super.key, 
    required this.evaluation, 
    required this.onTap, 
    required this.onComplete, 
    required this.onDelete
  });

  @override
  Widget build(BuildContext context) {
    final bool done = evaluation.isCompleted;
    
    return Slidable(
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onComplete(),
            backgroundColor: AppTheme.success.withValues(alpha: 0.8),
            icon: done ? Icons.undo_rounded : Icons.check_rounded,
            borderRadius: BorderRadius.circular(16),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppTheme.danger.withValues(alpha: 0.8),
            icon: Icons.delete_outline_rounded,
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          opacity: done ? 0.03 : 0.08,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4, height: 40,
                decoration: BoxDecoration(
                  color: done ? Colors.white24 : _getDiffColor(evaluation.difficulty),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evaluation.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: done ? Colors.white38 : Colors.white,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      evaluation.type.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.2)),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDiffColor(int diff) {
    if (diff <= 2) return AppTheme.success;
    if (diff <= 3) return Colors.orangeAccent;
    return AppTheme.danger;
  }
}