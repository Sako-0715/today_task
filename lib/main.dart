import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'models/task.dart';
import 'view_models/task_view_model.dart';

enum UserMode { none, parent, child, preview }

final isSortingProvider = StateProvider<bool>((ref) => false);

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
    if (mode != UserMode.preview) await prefs.setString(_key, mode.name);
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'どちらで使いますか？',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildModeButton(
                  context,
                  'タスク確認\n(こども用)',
                  Colors.orange,
                  () => ref
                      .read(userModeProvider.notifier)
                      .setMode(UserMode.child),
                ),
                _buildModeButton(
                  context,
                  'タスク登録\n(おとな用)',
                  Colors.blue,
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
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 150,
      height: 120,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
            title: const Text('保護者ログイン'),
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
    final isSorting = ref.watch(isSortingProvider);
    final bool isParent = mode == UserMode.parent;
    final bool isPreview = mode == UserMode.preview;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isParent
              ? (isSorting ? 'ならびかえ中' : 'タスク管理')
              : isPreview
              ? '子の画面(プレビュー)'
              : '今日のタスク',
        ),
        centerTitle: true,
        leadingWidth: 80,
        leading:
            isParent
                ? _buildAppBarAction(
                  Icons.child_care,
                  'プレビュー',
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
          _buildAppBarAction(
            Icons.history,
            '履歴',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryPage()),
            ),
          ),
          if (isParent && !isSorting)
            PopupMenuButton<String>(
              icon: const Icon(Icons.copy_all, color: Colors.blue),
              onSelected: (val) => _handleTemplateAction(context, ref, val),
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'load_weekday',
                      child: Text('平日のセットを読込'),
                    ),
                    const PopupMenuItem(
                      value: 'load_weekend',
                      child: Text('土日のセットを読込'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'save_weekday',
                      child: Text('今のリストを平日用に保存'),
                    ),
                    const PopupMenuItem(
                      value: 'save_weekend',
                      child: Text('今のリストを土日用に保存'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Text(
                        '今のリストを履歴へ移動',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
            ),
          if (isParent)
            TextButton.icon(
              onPressed:
                  () => ref.read(isSortingProvider.notifier).state = !isSorting,
              icon: Icon(
                isSorting ? Icons.check_circle : Icons.sort,
                color: isSorting ? Colors.green : Colors.blue,
              ),
              label: Text(
                isSorting ? '完了' : '順序',
                style: TextStyle(color: isSorting ? Colors.green : Colors.blue),
              ),
            ),
          if (!isPreview)
            _buildAppBarAction(
              Icons.logout,
              '終了',
              () => ref.read(userModeProvider.notifier).logout(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(taskProvider.notifier).fetchTasks();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child:
            taskList.isEmpty
                ? const Center(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Text('タスクがありません'),
                  ),
                )
                : (isParent && isSorting)
                ? ReorderableListView.builder(
                  itemCount: taskList.length,
                  onReorder:
                      (old, next) => ref
                          .read(taskProvider.notifier)
                          .reorderTasks(old, next),
                  itemBuilder:
                      (context, index) => _buildTaskTile(
                        context,
                        ref,
                        taskList[index],
                        mode,
                        index: index,
                        isSorting: true,
                        key: ValueKey(taskList[index].id),
                      ),
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
                        index: index,
                        isSorting: false,
                        key: ValueKey(taskList[index].id),
                      ),
                ),
      ),
      floatingActionButton:
          (isParent && !isSorting)
              ? FloatingActionButton(
                onPressed: () => _showAddTaskDialog(context, ref),
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  Widget _buildAppBarAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    WidgetRef ref,
    Task task,
    UserMode mode, {
    required Key key,
    required int index,
    required bool isSorting,
  }) {
    final bool isParent = mode == UserMode.parent;
    final bool isPreview = mode == UserMode.preview;

    return Card(
      key: key,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading:
            isSorting
                ? ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle, color: Colors.blue),
                )
                : Icon(
                  task.isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: task.isCompleted ? Colors.green : Colors.grey,
                ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: _buildSubtitle(task),
        trailing:
            isParent
                ? (isSorting ? null : _buildParentActions(context, ref, task))
                : _buildChildActions(context, ref, task, isPreview),
      ),
    );
  }

  Widget _buildSubtitle(Task task) {
    String formatTime(DateTime? dt) =>
        dt != null ? DateFormat('HH:mm').format(dt) : "--:--";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.note.isNotEmpty)
          Text(
            '💡 ${task.note}',
            style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
          ),
        Row(
          children: [
            if (task.startedAt != null)
              Text(
                '▶️ ${formatTime(task.startedAt)} ',
                style: const TextStyle(fontSize: 11, color: Colors.blue),
              ),
            if (task.completedAt != null)
              Text(
                '✅ ${formatTime(task.completedAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
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
              '⚠️しゅうせい依頼：${task.requestNote}',
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
    if (task.isCompleted) {
      if (task.requestNote.isEmpty)
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
      return null;
    }
    if (task.startedAt == null) {
      return ElevatedButton(
        onPressed:
            isPreview
                ? null
                : () => ref.read(taskProvider.notifier).startTask(task.id),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        child: const Text('はじめる'),
      );
    } else {
      return ElevatedButton(
        onPressed:
            isPreview
                ? null
                : () => _showCompleteConfirmDialog(context, ref, task),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: const Text('おわった！'),
      );
    }
  }

  Widget _buildParentActions(BuildContext context, WidgetRef ref, Task task) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.requestNote.isNotEmpty) ...[
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
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
          onPressed: () => _showEditTaskDialog(context, ref, task),
        ),
        if (task.isCompleted && task.requestNote.isEmpty)
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.orange, size: 20),
            onPressed: () => _showUndoConfirmDialog(context, ref, task),
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: () => ref.read(taskProvider.notifier).deleteTask(task.id),
        ),
      ],
    );
  }

  void _handleTemplateAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final notifier = ref.read(taskProvider.notifier);
    if (action == 'clear') {
      _showConfirmDialog(
        context,
        '履歴へ移動',
        '完了したタスクを履歴に送りますか？', // テキストはほぼ維持
        () => notifier.archiveAllTasks(),
      );
    } else if (action == 'save_weekday') {
      await notifier.saveTemplate('weekday');
      _showSnackBar(context, '平日用として保存しました');
    } else if (action == 'save_weekend') {
      await notifier.saveTemplate('weekend');
      _showSnackBar(context, '土日用として保存しました');
    } else if (action == 'load_weekday') {
      await notifier.loadTemplate('weekday');
      _showSnackBar(context, '平日のセットを追加しました');
    } else if (action == 'load_weekend') {
      await notifier.loadTemplate('weekend');
      _showSnackBar(context, '土日のセットを追加しました');
    }
  }

  void _showConfirmDialog(
    BuildContext context,
    String title,
    String msg,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () {
                  onConfirm();
                  Navigator.pop(ctx);
                },
                child: const Text('実行'),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
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
                  decoration: const InputDecoration(hintText: 'メモ・注意点'),
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

  void _showEditTaskDialog(BuildContext context, WidgetRef ref, Task task) {
    final titleController = TextEditingController(text: task.title);
    final noteController = TextEditingController(text: task.note);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('タスクを編集'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'タスク名'),
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'メモ'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    await ref
                        .read(taskProvider.notifier)
                        .updateTaskInfo(
                          task.id,
                          titleController.text,
                          noteController.text,
                        );
                    Navigator.pop(context);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
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
              decoration: const InputDecoration(hintText: 'りゆう（例：まだやってなかった）'),
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

  void _showUndoConfirmDialog(BuildContext context, WidgetRef ref, Task task) {
    _showConfirmDialog(context, 'やり直し', '「${task.title}」を未完了に戻しますか？', () {
      ref.read(taskProvider.notifier).toggleTask(task.id, task.isCompleted);
    });
  }
}

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyStream = ref.watch(taskProvider.notifier).fetchHistoryTasks();

    return Scaffold(
      appBar: AppBar(title: const Text('おわった記録'), centerTitle: true),
      body: StreamBuilder<List<Task>>(
        stream: historyStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          if (snapshot.hasError)
            return const Center(child: Text('読み込みエラーが発生しました'));

          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const Center(child: Text('まだ履歴がありません'));

          final allHistoryTasks = snapshot.data!;
          final Map<String, List<Task>> groupedTasks = {};
          for (var task in allHistoryTasks) {
            if (task.completedAt != null) {
              final dateKey = DateFormat(
                'yyyy/MM/dd',
              ).format(task.completedAt!);
              groupedTasks.putIfAbsent(dateKey, () => []).add(task);
            }
          }
          final sortedDates =
              groupedTasks.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final dateStr = sortedDates[index];
              return ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.blue),
                title: Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${groupedTasks[dateStr]!.length} 個のタスクを完了'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final tasksOfThisDay = groupedTasks[dateStr]!;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => DateDetailPage(
                            tasks: tasksOfThisDay,
                            dateString: dateStr,
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class DateDetailPage extends StatelessWidget {
  final List<Task> tasks;
  final String dateString;
  const DateDetailPage({
    super.key,
    required this.tasks,
    required this.dateString,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$dateString の詳細')),
      body: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          final startTime =
              task.startedAt != null
                  ? DateFormat('HH:mm').format(task.startedAt!)
                  : "--:--";
          final endTime =
              task.completedAt != null
                  ? DateFormat('HH:mm').format(task.completedAt!)
                  : "--:--";
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(
                task.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('時間: $startTime 〜 $endTime\n${task.note}'),
            ),
          );
        },
      ),
    );
  }
}
