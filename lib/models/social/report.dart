import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportTargetType { post, comment, message, user }

class Report {
  final String id;
  final String reporterId;
  final ReportTargetType targetType;
  final String targetId;
  final String reason;
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'reporterId': reporterId,
        'targetType': targetType.name,
        'targetId': targetId,
        'reason': reason,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Report.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Report(
      id: doc.id,
      reporterId: data['reporterId'] as String? ?? '',
      targetType: ReportTargetType.values.firstWhere(
        (t) => t.name == data['targetType'],
        orElse: () => ReportTargetType.post,
      ),
      targetId: data['targetId'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
