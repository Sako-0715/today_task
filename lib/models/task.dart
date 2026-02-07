import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final String note;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? startedAt; // ★ 追加：開始した時間
  final DateTime? completedAt;
  final String requestNote;
  final int order;

  Task({
    required this.id,
    required this.title,
    this.note = '',
    this.isCompleted = false,
    required this.createdAt,
    this.startedAt, // ★ 追加
    this.completedAt,
    this.requestNote = '',
    this.order = 0,
  });

  Task updateTask({
    String? id,
    String? title,
    String? note,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? startedAt, // ★ 追加
    DateTime? completedAt,
    String? requestNote,
    int? order,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
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
      createdAt:
          map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      startedAt:
          map['startedAt']
                  is Timestamp // ★ 追加
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
      'createdAt': createdAt,
      'startedAt': startedAt, // ★ 追加
      'completedAt': completedAt,
      'requestNote': requestNote,
      'order': order,
    };
  }
}
