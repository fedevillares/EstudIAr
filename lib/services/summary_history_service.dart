import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class SummaryEntry {
  final String id;
  final String subject;
  final String summary;
  final DateTime createdAt;

  SummaryEntry({
    required this.id,
    required this.subject,
    required this.summary,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'subject': subject,
    'summary': summary, 'createdAt': createdAt.toIso8601String(),
  };

  factory SummaryEntry.fromJson(Map<String, dynamic> j) => SummaryEntry(
    id: j['id'], subject: j['subject'],
    summary: j['summary'], createdAt: DateTime.parse(j['createdAt']),
  );
}

class SummaryHistoryService {
  static Box get _box => Hive.box('settings');
  static const _key = 'summary_history';

  static List<SummaryEntry> getAll() {
    final raw = _box.get(_key) as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => SummaryEntry.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static void save(SummaryEntry entry) {
    final list = getAll();
    list.insert(0, entry);
    if (list.length > 50) list.removeLast(); // máximo 50
    _box.put(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static void delete(String id) {
    final list = getAll()..removeWhere((e) => e.id == id);
    _box.put(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static void clear() => _box.put(_key, jsonEncode([]));
}