import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'models/task.dart';
import 'view_models/task_view_model.dart';

enum UserMode { none, parent, child }

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
      return;
    } else if (savedMode == 'child') {
      state = UserMode.child;
      return;
    }

    final isParent = await ref.read(taskProvider.notifier).isParentDevice();
    if (isParent) {
      await setMode(UserMode.parent);
    }
  }

  Future<void> setMode(UserMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

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
          elevation: 0,
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
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'どちらで使いますか？',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          () => ref
                              .read(userModeProvider.notifier)
                              .setMode(UserMode.child),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      child: const Text(
                        'タスク確認\n(かくにん)',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showAuthDialog(context, ref),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      child: const Text(
                        'タスク登録\n(とうろく)',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('IDまたはパスワードが違います')),
                    );
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isParent ? 'タスク管理' : '今日のタスク'),
        centerTitle: true,
        leadingWidth: 80,
        leading: InkWell(
          onTap: () => ref.read(userModeProvider.notifier).logout(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.logout, size: 20),
              Text(
                'ログアウト',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      body:
          taskList.isEmpty
              ? const Center(
                child: Text('タスクはありません', style: TextStyle(color: Colors.grey)),
              )
              : isParent
              ? ReorderableListView.builder(
                itemCount: taskList.length,
                onReorder: (oldIndex, newIndex) {
                  ref
                      .read(taskProvider.notifier)
                      .reorderTasks(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final task = taskList[index];
                  return _buildTaskTile(
                    context,
                    ref,
                    task,
                    isParent,
                    key: ValueKey(task.id),
                  );
                },
              )
              : ListView.builder(
                itemCount: taskList.length,
                itemBuilder: (context, index) {
                  final task = taskList[index];
                  return _buildTaskTile(
                    context,
                    ref,
                    task,
                    isParent,
                    key: ValueKey(task.id),
                  );
                },
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

  Widget _buildTaskTile(
    BuildContext context,
    WidgetRef ref,
    Task task,
    bool isParent, {
    required Key key,
  }) {
    return ListTile(
      key: key,
      leading:
          isParent
              ? const Icon(Icons.drag_handle, color: Colors.grey) // 親は並べ替え用ハンドル
              : Checkbox(
                // 子はチェックボックス
                value: task.isCompleted,
                onChanged:
                    task.isCompleted
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
              : _buildChildActions(context, ref, task),
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
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '⚠️ていせいのおねがい：${task.requestNote}',
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

  Widget? _buildChildActions(BuildContext context, WidgetRef ref, Task task) {
    if (task.isCompleted && task.requestNote.isEmpty) {
      return TextButton(
        onPressed: () => _showRequestCorrectionDialog(context, ref, task),
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
    final now = DateTime.now();
    final timeString = "${now.hour}時${now.minute.toString().padLeft(2, '0')}分";
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('おわった！'),
            content: Text('「${task.title}」を\n$timeString に おわらせたよ！\n登録してもいい？'),
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
              autofocus: true,
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
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'タスク名'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    hintText: '注意書き',
                    prefixText: '※ ',
                  ),
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
