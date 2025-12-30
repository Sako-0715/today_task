/// タスクの情報保持
class Task {
  final String id; // タスクID
  final String title; // タスク名
  final bool isCompleted; // 完了有無
  final DateTime createdAt; // 作成日時

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false, // デフォルトは未完了(false)
    required this.createdAt,
  });

  /// プロパティーの更新
  Task updateTask({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// firebaseから取得
  factory Task.getTask(Map<String, dynamic> map, String documentId) {
    return Task(
      id: documentId,
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      createdAt: (map['createdAt'] as dynamic).toDate(),
    );
  }

  /// 変換
  Map<String, dynamic> setTaskData() {
    return {'title': title, 'isCompleted': isCompleted, 'createdAt': createdAt};
  }
}
