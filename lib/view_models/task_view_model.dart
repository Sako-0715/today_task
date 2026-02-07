import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

final taskProvider = StateNotifierProvider<TaskViewModel, List<Task>>((ref) {
  return TaskViewModel();
});

class TaskViewModel extends StateNotifier<List<Task>> {
  final _db = FirebaseFirestore.instance.collection('tasks');
  final _config = FirebaseFirestore.instance.collection('config');

  TaskViewModel() : super([]) {
    fetchTasks();
  }

  // 更新通知用
  Future<void> _notifyUpdate() async {
    await _config.doc('updates').set({
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // デバイスID取得
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

  // 保護者デバイスとして登録
  Future<void> registerAsParent() async {
    final deviceId = await getDeviceId();
    if (deviceId != null) {
      await _config.doc('parent_device').set({
        'deviceId': deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // 保護者判定
  Future<bool> isParentDevice() async {
    final deviceId = await getDeviceId();
    final doc = await _config.doc('parent_device').get();
    if (doc.exists && deviceId != null) {
      return doc.data()?['deviceId'] == deviceId;
    }
    return false;
  }

  // 現在のタスク一覧取得（メイン画面用：未アーカイブのみ）
  void fetchTasks() {
    _db
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            final docs =
                snapshot.docs.map((doc) {
                  return Task.getTask(doc.data(), doc.id);
                }).toList();

            // アプリ側でソート
            docs.sort((a, b) => a.order.compareTo(b.order));
            state = docs;
          },
          onError: (error) {
            if (kDebugMode) print("Firestore Error (fetchTasks): $error");
          },
        );
  }

  // 履歴表示：最新の完了が「下」に来るように修正
  Stream<List<Task>> fetchHistoryTasks() {
    return _db.where('isCompleted', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final list =
          snapshot.docs.map((doc) => Task.getTask(doc.data(), doc.id)).toList();

      // ★修正箇所：a.compareTo(b) にすることで「古い順 ＝ 最新が下」になります
      list.sort((a, b) {
        final aTime = a.completedAt ?? DateTime(0);
        final bTime = b.completedAt ?? DateTime(0);
        return aTime.compareTo(bTime);
      });
      return list;
    });
  }

  // タスク追加
  Future<void> addTask(String title, String note) async {
    final int nextOrder = state.length;
    final docRef = _db.doc();

    await docRef.set({
      'title': title,
      'note': note,
      'isCompleted': false,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
      'startedAt': null,
      'completedAt': null,
      'order': nextOrder,
      'requestNote': '',
    });
    await _notifyUpdate();
  }

  // タスク開始
  Future<void> startTask(String id) async {
    await _db.doc(id).update({'startedAt': FieldValue.serverTimestamp()});
    await _notifyUpdate();
  }

  // 完了切り替え時に completedAt を確実にセット
  Future<void> toggleTask(String id, bool currentStatus) async {
    final bool nextStatus = !currentStatus;
    await _db.doc(id).update({
      'isCompleted': nextStatus,
      'completedAt': nextStatus ? FieldValue.serverTimestamp() : null,
      'requestNote': '',
    });
    await _notifyUpdate();
  }

  Future<void> updateTaskInfo(
    String id,
    String newTitle,
    String newNote,
  ) async {
    await _db.doc(id).update({'title': newTitle, 'note': newNote});
    await _notifyUpdate();
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final items = [...state];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < items.length; i++) {
      batch.update(_db.doc(items[i].id), {'order': i});
    }
    await batch.commit();
    await _notifyUpdate();
  }

  Future<void> deleteTask(String id) async {
    await _db.doc(id).delete();
    await _notifyUpdate();
  }

  Future<void> requestCorrection(String id, String reason) async {
    await _db.doc(id).update({'requestNote': reason});
  }

  Future<void> approveCorrection(String id) async {
    await _db.doc(id).update({
      'isCompleted': false,
      'startedAt': null,
      'completedAt': null,
      'requestNote': '',
    });
    await _notifyUpdate();
  }

  Future<void> rejectCorrection(String id) async {
    await _db.doc(id).update({'requestNote': ''});
  }

  // 全タスクをアーカイブ
  Future<void> archiveAllTasks() async {
    final snapshots = await _db.where('isArchived', isEqualTo: false).get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshots.docs) {
      final data = doc.data();
      batch.update(doc.reference, {
        'isArchived': true,
        'completedAt': data['completedAt'] ?? FieldValue.serverTimestamp(),
        'isCompleted': true,
      });
    }
    await batch.commit();
    await _notifyUpdate();
  }

  Future<void> saveTemplate(String templateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.map((t) => '${t.title}:::${t.note}').toList();
    await prefs.setStringList('template_$templateKey', data);
  }

  Future<void> loadTemplate(String templateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('template_$templateKey');
    if (data == null || data.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    int currentOrder = state.length;
    for (var item in data) {
      final parts = item.split(':::');
      final title = parts[0];
      final note = parts.length > 1 ? parts[1] : '';
      final docRef = _db.doc();
      batch.set(docRef, {
        'title': title,
        'note': note,
        'isCompleted': false,
        'isArchived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': null,
        'completedAt': null,
        'order': currentOrder++,
        'requestNote': '',
      });
    }
    await batch.commit();
    await _notifyUpdate();
  }
}
