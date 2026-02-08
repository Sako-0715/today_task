import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final String note;
  final bool isCompleted;
  final bool isArchived; // ★ 追加：アーカイブ状態（履歴送り）か
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String requestNote;
  final int order;

  Task({
    required this.id,
    required this.title,
    this.note = '',
    this.isCompleted = false,
    this.isArchived = false, // ★ デフォルトはfalse
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.requestNote = '',
    this.order = 0,
  });

  Task updateTask({
    String? id,
    String? title,
    String? note,
    bool? isCompleted,
    bool? isArchived, // ★ 追加
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? requestNote,
    int? order,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      isArchived: isArchived ?? this.isArchived, // ★ 追加
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      requestNote: requestNote ?? this.requestNote,
      order: order ?? this.order,
    );
  }

  factory Task.getTask(Map<String, dynamic> map, String documentId) {
    return Task(
      id: documentId,
      title: map['title'] ?? '',
      note: map['note'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      isArchived: map['isArchived'] ?? false, // ★ 追加
      createdAt:
          map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      startedAt:
          map['startedAt'] is Timestamp
              ? (map['startedAt'] as Timestamp).toDate()
              : null,
      completedAt:
          map['completedAt'] is Timestamp
              ? (map['completedAt'] as Timestamp).toDate()
              : null,
      requestNote: map['requestNote'] ?? '',
      order: map['order'] ?? 0,
    );
  }

  Map<String, dynamic> setTaskData() {
    return {
      'title': title,
      'note': note,
      'isCompleted': isCompleted,
      'isArchived': isArchived, // ★ 追加
      'createdAt': createdAt,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'requestNote': requestNote,
      'order': order,
    };
  }
}
