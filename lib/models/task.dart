import 'package:cloud_firestore/cloud_firestore.dart';

/// タスクの情報保持
class Task {
  final String id; // タスクID
  final String title; // タスク名
  final String note; // 補足・メモ
  final bool isCompleted; // 完了有無
  final DateTime createdAt; // 作成日時
  final DateTime? completedAt; // 完了した時間
  final String requestNote; // 訂正の理由（空文字なら申請なし）

  Task({
    required this.id,
    required this.title,
    this.note = '',
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.requestNote = '',
  });

  /// 特定のプロパティだけを書き換えた新しいインスタンスを作成します
  Task updateTask({
    String? id,
    String? title,
    String? note,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    String? requestNote,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      requestNote: requestNote ?? this.requestNote,
    );
  }

  /// Firebase（Firestore）から取得したMapデータをTaskクラスに変換します
  factory Task.getTask(Map<String, dynamic> map, String documentId) {
    return Task(
      id: documentId,
      title: map['title'] ?? '',
      note: map['note'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      // FirebaseのTimestamp型をDartのDateTimeに変換（型チェック付き）
      createdAt:
          map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      completedAt:
          map['completedAt'] is Timestamp
              ? (map['completedAt'] as Timestamp).toDate()
              : null,
      requestNote: map['requestNote'] ?? '',
    );
  }

  /// Firebase（Firestore）へ保存するためにMap形式に変換します
  Map<String, dynamic> setTaskData() {
    return {
      'title': title,
      'note': note,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'requestNote': requestNote,
    };
  }
}
