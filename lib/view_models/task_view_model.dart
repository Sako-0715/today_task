import '../models/task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// タスク一覧の状態（State）を管理するViewModel
/// [List<Task>] を状態として持ちます。
class TaskViewModel extends StateNotifier<List<Task>> {
  TaskViewModel() : super([]); // 最初は空のリスト

  /// 新しいタスクを追加します
  void addTask(String title) {
    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // 簡易的なID生成
      title: title,
      createdAt: DateTime.now(),
    );

    // Flutterのルール: state自体を上書きすることで画面に通知が飛びます
    state = [...state, newTask];
  }

  /// タスクの完了・未完了を切り替えます
  void toggleTask(String id) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.updateTask(isCompleted: !task.isCompleted) // 先ほど作ったメソッドを活用
        else
          task,
    ];
  }

  /// タスクを削除します
  void deleteTask(String id) {
    state = state.where((task) => task.id != id).toList();
  }
}

/// 外部（View）からViewModelを操作するための「窓口」
final taskProvider = StateNotifierProvider<TaskViewModel, List<Task>>((ref) {
  return TaskViewModel();
});
