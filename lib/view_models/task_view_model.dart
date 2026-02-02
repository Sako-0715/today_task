import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskViewModel extends StateNotifier<List<Task>> {
  final _db = FirebaseFirestore.instance.collection('tasks');
  final _config = FirebaseFirestore.instance.collection('config');

  TaskViewModel() : super([]) {
    fetchTasks();
  }

  /// 更新通知用のフラグをFirebaseに書き込む
  /// 親が「追加」「削除」「並び替え」「編集」をした時に実行する
  Future<void> _notifyUpdate() async {
    await _config.doc('updates').set({
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// デバイス固有のIDを取得する
  Future<String?> getDeviceId() async {
    if (kIsWeb) return 'web_user';
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      }
    } catch (e) {
      if (kDebugMode) print("Device Info Error: $e");
    }
    return null;
  }

  /// このデバイスを「親」として登録する
  Future<void> registerAsParent() async {
    final deviceId = await getDeviceId();
    if (deviceId != null) {
      await _config.doc('parent_device').set({
        'deviceId': deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// このデバイスが「親」かどうか判定する
  Future<bool> isParentDevice() async {
    final deviceId = await getDeviceId();
    final doc = await _config.doc('parent_device').get();
    if (doc.exists && deviceId != null) {
      return doc.data()?['deviceId'] == deviceId;
    }
    return false;
  }

  /// タスク一覧のリアルタイム監視 (order順に取得)
  void fetchTasks() {
    _db.orderBy('order', descending: false).snapshots().listen(
      (snapshot) {
        state = snapshot.docs
            .map((doc) => Task.getTask(doc.data(), doc.id))
            .toList();
      },
      onError: (error) {
        if (kDebugMode) print("Firebase Error: $error");
      },
    );
  }

  /// ★ 追加：タスクの編集処理 (親用)
  Future<void> updateTask(String id, String newTitle, String newNote) async {
    try {
      await _db.doc(id).update({
        'title': newTitle,
        'note': newNote,
      });

      // 内容が変わったことを子供側に通知する
      await _notifyUpdate();
    } catch (e) {
      if (kDebugMode) print("Update Task Error: $e");
    }
  }

  /// タスクの並べ替え処理
  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final items = [...state];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < items.length; i++) {
      final docRef = _db.doc(items[i].id);
      batch.update(docRef, {'order': i});
    }
    await batch.commit();

    // 並び替え完了を通知
    await _notifyUpdate();
  }

  /// 親がタスクを追加する (最後尾に追加)
  Future<void> addTask(String title, String note) async {
    final int nextOrder = state.isEmpty ? 0 : state.length;
    final newTask = Task(
      id: '',
      title: title,
      note: note,
      createdAt: DateTime.now(),
      order: nextOrder,
    );
    await _db.add(newTask.setTaskData());

    // 追加を通知
    await _notifyUpdate();
  }

  /// 子（または親）が完了状態を切り替える
  Future<void> toggleTask(String id, bool currentStatus) async {
    final bool nextStatus = !currentStatus;
    await _db.doc(id).update({
      'isCompleted': nextStatus,
      'completedAt': nextStatus ? FieldValue.serverTimestamp() : null,
      'requestNote': '', // 完了・未完了を切り替えたら依頼は消去する
    });
  }

  /// 子が「まちがえた（訂正依頼）」を出す
  Future<void> requestCorrection(String id, String reason) async {
    await _db.doc(id).update({'requestNote': reason});
  }

  /// 親が訂正依頼を「OK」する
  Future<void> approveCorrection(String id) async {
    await _db.doc(id).update({
      'isCompleted': false,
      'completedAt': null,
      'requestNote': '',
    });
    // 訂正承認も「内容変更」なので通知
    await _notifyUpdate();
  }

  /// 親が訂正依頼を「却下」する
  Future<void> rejectCorrection(String id) async {
    await _db.doc(id).update({'requestNote': ''});
  }

  /// 親がタスクを削除する
  Future<void> deleteTask(String id) async {
    await _db.doc(id).delete();
    // 削除を通知
    await _notifyUpdate();
  }
}

final taskProvider = StateNotifierProvider<TaskViewModel, List<Task>>((ref) {
  return TaskViewModel();
});
