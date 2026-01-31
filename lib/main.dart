import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'models/task.dart';
import 'view_models/task_view_model.dart';

enum UserMode { none, parent, child, preview }

// 更新監視用のProvider
final updateStreamProvider = StreamProvider<DocumentSnapshot>((ref) {
  return FirebaseFirestore.instance
      .collection('config')
      .doc('updates')
      .snapshots();
});

final userModeProvider = StateNotifierProvider<UserModeNotifier, UserMode>((
  ref,
) {
  return UserModeNotifier(ref);
});

class UserModeNotifier extends StateNotifier<UserMode> {
  final Ref ref;
  UserModeNotifier(this.ref) : super(UserMode.none) {
    _initMode();
  }

  static const _key = 'user_mode';

  Future<void> _initMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_key);

    if (savedMode == 'parent') {
      state = UserMode.parent;
    } else if (savedMode == 'child') {
      state = UserMode.child;
    } else {
      final isParent = await ref.read(taskProvider.notifier).isParentDevice();
      if (isParent) await setMode(UserMode.parent);
    }
  }

  Future<void> setMode(UserMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode != UserMode.preview) {
      await prefs.setString(_key, mode.name);
    }
  }

  void enterPreview() => state = UserMode.preview;
  void exitPreview() => state = UserMode.parent;

  Future<void> logout() async {
    state = UserMode.none;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(userModeProvider);
    return MaterialApp(
      title: 'Today Task',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      home:
          mode == UserMode.none
              ? const ModeSelectionPage()
              : const TaskListPage(),
    );
  }
}

class ModeSelectionPage extends ConsumerWidget {
  const ModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'どちらで使いますか？',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildModeButton(
                  context,
                  'タスク確認\n(かくにん)',
                  () => ref
                      .read(userModeProvider.notifier)
                      .setMode(UserMode.child),
                ),
                _buildModeButton(
                  context,
                  'タスク登録\n(とうろく)',
                  () => _showAuthDialog(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    String text,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 150,
      height: 100,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  void _showAuthDialog(BuildContext context, WidgetRef ref) {
    final idController = TextEditingController();
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ログイン'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(labelText: 'ID'),
                ),
                TextField(
                  controller: passController,
                  decoration: const InputDecoration(labelText: 'パスワード'),
                  obscureText: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () async {
                  if (idController.text == 'admin' &&
                      passController.text == '1234') {
                    Navigator.pop(context);
                    await ref.read(taskProvider.notifier).registerAsParent();
                    ref
                        .read(userModeProvider.notifier)
                        .setMode(UserMode.parent);
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}

class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskList = ref.watch(taskProvider);
    final mode = ref.watch(userModeProvider);
    final bool isParent = mode == UserMode.parent;
    final bool isPreview = mode == UserMode.preview;

    // --- 子モードの時の更新通知ロジック ---
    if (mode == UserMode.child) {
      ref.listen(updateStreamProvider, (previous, next) {
        final hasStarted = taskList.any((task) => task.isCompleted);
        if (hasStarted && previous != null && next.hasValue) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ リロードしてください'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 10), // 長めに表示
            ),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isParent
              ? 'タスク管理'
              : isPreview
              ? '子の画面(プレビュー)'
              : '今日のタスク',
        ),
        centerTitle: true,
        leadingWidth: 80,
        leading:
            isParent
                ? _buildIconButton(
                  Icons.child_care,
                  '子の画面',
                  () => ref.read(userModeProvider.notifier).enterPreview(),
                )
                : isPreview
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed:
                      () => ref.read(userModeProvider.notifier).exitPreview(),
                )
                : null,
        actions: [
          if (!isPreview)
            _buildIconButton(
              Icons.logout,
              'ログアウト',
              () => ref.read(userModeProvider.notifier).logout(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // ★ 追加：リロード時に通知を消す
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          ref.read(taskProvider.notifier).fetchTasks();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child:
            taskList.isEmpty
                ? const Center(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 200,
                      child: Center(child: Text('タスクはありません')),
                    ),
                  ),
                )
                : isParent
                ? ReorderableListView.builder(
                  itemCount: taskList.length,
                  proxyDecorator:
                      (child, index, animation) => Material(
                        child: child,
                        elevation: 6,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                  onReorder:
                      (old, next) => ref
                          .read(taskProvider.notifier)
                          .reorderTasks(old, next),
                  itemBuilder: (context, index) {
                    final task = taskList[index];
                    return ReorderableDragStartListener(
                      key: ValueKey(task.id),
                      index: index,
                      child: _buildTaskTile(
                        context,
                        ref,
                        task,
                        mode,
                        key: ValueKey(task.id),
                      ),
                    );
                  },
                )
                : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: taskList.length,
                  itemBuilder:
                      (context, index) => _buildTaskTile(
                        context,
                        ref,
                        taskList[index],
                        mode,
                        key: ValueKey(taskList[index].id),
                      ),
                ),
      ),
      floatingActionButton:
          isParent
              ? FloatingActionButton(
                onPressed: () => _showAddTaskDialog(context, ref),
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  // --- 以降の補助関数は変更なし ---
  Widget _buildIconButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    WidgetRef ref,
    Task task,
    UserMode mode, {
    required Key key,
  }) {
    final bool isParent = mode == UserMode.parent;
    final bool isPreview = mode == UserMode.preview;

    return ListTile(
      key: key,
      leading:
          isParent
              ? const Icon(Icons.drag_handle, color: Colors.grey)
              : Checkbox(
                value: task.isCompleted,
                onChanged:
                    (isPreview || task.isCompleted)
                        ? null
                        : (val) =>
                            _showCompleteConfirmDialog(context, ref, task),
              ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          color: task.isCompleted ? Colors.grey : Colors.black,
        ),
      ),
      subtitle: _buildSubtitle(task),
      trailing:
          isParent
              ? _buildParentActions(ref, task)
              : _buildChildActions(context, ref, task, isPreview),
    );
  }

  Widget _buildSubtitle(Task task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.note.isNotEmpty)
          Text(
            '※ ${task.note}',
            style: const TextStyle(color: Colors.deepOrange, fontSize: 13),
          ),
        if (task.isCompleted && task.completedAt != null)
          Text(
            '✅ ${task.completedAt!.hour}時${task.completedAt!.minute.toString().padLeft(2, '0')}分 に完了',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        if (task.requestNote.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '⚠️ていせいいらい：${task.requestNote}',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget? _buildChildActions(
    BuildContext context,
    WidgetRef ref,
    Task task,
    bool isPreview,
  ) {
    if (task.isCompleted && task.requestNote.isEmpty) {
      return TextButton(
        onPressed:
            isPreview
                ? null
                : () => _showRequestCorrectionDialog(context, ref, task),
        child: const Text(
          'まちがえた',
          style: TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      );
    }
    return null;
  }

  Widget _buildParentActions(WidgetRef ref, Task task) {
    if (task.requestNote.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
            onPressed:
                () =>
                    ref.read(taskProvider.notifier).approveCorrection(task.id),
          ),
          IconButton(
            icon: const Icon(Icons.highlight_off, color: Colors.red),
            onPressed:
                () => ref.read(taskProvider.notifier).rejectCorrection(task.id),
          ),
        ],
      );
    }
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      onPressed: () => ref.read(taskProvider.notifier).deleteTask(task.id),
    );
  }

  void _showCompleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('おわった！'),
            content: Text('「${task.title}」を登録してもいい？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('まだ'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(taskProvider.notifier)
                      .toggleTask(task.id, task.isCompleted);
                  Navigator.pop(context);
                },
                child: const Text('登録する'),
              ),
            ],
          ),
    );
  }

  void _showRequestCorrectionDialog(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('まちがえた？'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'りゆう'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('やめる'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    ref
                        .read(taskProvider.notifier)
                        .requestCorrection(task.id, controller.text);
                    Navigator.pop(context);
                  }
                },
                child: const Text('おくる'),
              ),
            ],
          ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('新しいタスクを追加'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(hintText: 'タスク名'),
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(hintText: '注意書き'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    ref
                        .read(taskProvider.notifier)
                        .addTask(titleController.text, noteController.text);
                    Navigator.pop(context);
                  }
                },
                child: const Text('追加'),
              ),
            ],
          ),
    );
  }
}
