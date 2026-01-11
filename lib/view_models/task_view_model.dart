import '../models/task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// タスク一覧の状態（State）を管理するViewModel
/// [List<Task>] を状態として持ちます。
class TaskViewModel extends StateNotifier<List<Task>> {
  final _db = FirebaseFirestore.instance.collection('tasks');

  TaskViewModel() : super([]) {
    // 起動時に自動でデータの監視を開始する
    fetchTasks();
  }

  /// データのリアルタイム監視
  void fetchTasks() {
    // サーバー側でデータが変わると、この中身が自動で実行されます
    _db.orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
      state =
          snapshot.docs.map((doc) {
            return Task.getTask(doc.data(), doc.id);
          }).toList();
    });
  }

  /// 親がタスクを追加する
  Future<void> addTask(String title) async {
    final newTask = Task(
      id: '', // Firebase側で自動採番されるので空でOK
      title: title,
      createdAt: DateTime.now(),
    );
    // Firestoreへ追加
    await _db.add(newTask.setTaskData());
  }

  /// 子（または親）が完了状態を切り替える
  Future<void> toggleTask(String id, bool currentStatus) async {
    await _db.doc(id).update({'isCompleted': !currentStatus});
  }

  /// 親がタスクを削除する
  Future<void> deleteTask(String id) async {
    await _db.doc(id).delete();
  }
}

final taskProvider = StateNotifierProvider<TaskViewModel, List<Task>>((ref) {
  return TaskViewModel();
});
