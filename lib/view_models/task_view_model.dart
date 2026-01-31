import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'; // kIsWeb を使うため
import '../models/task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskViewModel extends StateNotifier<List<Task>> {
  final _db = FirebaseFirestore.instance.collection('tasks');
  final _config = FirebaseFirestore.instance.collection('config');

  TaskViewModel() : super([]) {
    fetchTasks();
  }

  /// デバイス固有のIDを取得する（Web実行時も考慮）
  Future<String?> getDeviceId() async {
    if (kIsWeb) return 'web_user'; // Webの場合は固定値を返すか、別の仕組みを検討

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

  /// タスク一覧のリアルタイム監視
  void fetchTasks() {
    _db
        .orderBy('createdAt', descending: true)
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

  /// 親がタスクを追加する
  Future<void> addTask(String title, String note) async {
    final newTask = Task(
      id: '',
      title: title,
      note: note,
      createdAt: DateTime.now(),
    );
    await _db.add(newTask.setTaskData());
  }

  /// 子（または親）が完了状態を切り替える
  Future<void> toggleTask(String id, bool currentStatus) async {
    final bool nextStatus = !currentStatus;
    await _db.doc(id).update({
      'isCompleted': nextStatus,
      'completedAt':
          nextStatus
              ? FieldValue.serverTimestamp()
              : null, // Firebaseサーバーの時間を使用
      'requestNote': '', // 完了したら申請はリセット
    });
  }

  /// 子が「まちがえた（訂正依頼）」を出す
  Future<void> requestCorrection(String id, String reason) async {
    await _db.doc(id).update({'requestNote': reason});
  }

  /// 親が訂正依頼を「OK（やり直しを許可）」する
  Future<void> approveCorrection(String id) async {
    await _db.doc(id).update({
      'isCompleted': false,
      'completedAt': null,
      'requestNote': '',
    });
  }

  /// 親が訂正依頼を「ダメ（却下）」する
  Future<void> rejectCorrection(String id) async {
    await _db.doc(id).update({'requestNote': ''});
  }

  /// 親がタスクを削除する
  Future<void> deleteTask(String id) async {
    await _db.doc(id).delete();
  }
}

final taskProvider = StateNotifierProvider<TaskViewModel, List<Task>>((ref) {
  return TaskViewModel();
});
