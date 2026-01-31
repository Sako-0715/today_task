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
    _db
        .orderBy('order', descending: false) // 並び順フィールドでソート
        .snapshots()
        .listen(
          (snapshot) {
            state =
                snapshot.docs
                    .map((doc) => Task.getTask(doc.data(), doc.id))
                    .toList();
          },
          onError: (error) {
            if (kDebugMode) print("Firebase Error: $error");
          },
        );
  }

  /// タスクの並べ替え処理
  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    // インデックスの調整 (ReorderableListViewの仕様)
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // ローカルの状態を並べ替えて即時反映
    final items = [...state];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;

    // Firebase側の order フィールドを一括更新
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < items.length; i++) {
      final docRef = _db.doc(items[i].id);
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
  }

  /// 親がタスクを追加する (最後尾に追加)
  Future<void> addTask(String title, String note) async {
    // 現在のリストの末尾になるようにorderを設定
    final int nextOrder = state.isEmpty ? 0 : state.length;

    final newTask = Task(
      id: '',
      title: title,
      note: note,
      createdAt: DateTime.now(),
      order: nextOrder,
    );
    await _db.add(newTask.setTaskData());
  }

  /// 子（または親）が完了状態を切り替える
  Future<void> toggleTask(String id, bool currentStatus) async {
    final bool nextStatus = !currentStatus;
    await _db.doc(id).update({
      'isCompleted': nextStatus,
      'completedAt': nextStatus ? FieldValue.serverTimestamp() : null,
      'requestNote': '',
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
  }

  /// 親が訂正依頼を「却下」する
  Future<void> rejectCorrection(String id) async {
    await _db.doc(id).update({'requestNote': ''});
  }

  /// 親がタスクを削除する
  Future<void> deleteTask(String id) async {
    await _db.doc(id).delete();
    // 削除後、残ったタスクのorderを詰め直す場合はここでbatch処理
  }
}

final taskProvider = StateNotifierProvider<TaskViewModel, List<Task>>((ref) {
  return TaskViewModel();
});
