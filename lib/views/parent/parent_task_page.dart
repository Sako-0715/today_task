import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../view_models/task_view_model.dart';
import '../../view_models/user_mode_view_model.dart';
import '../../components/task_tile.dart';
import '../history_page.dart';

// 親ページでのみ使用する並び替え状態
final isSortingProvider = StateProvider<bool>((ref) => false);

class ParentTaskPage extends ConsumerWidget {
  const ParentTaskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskList = ref.watch(taskProvider);
    final isSorting = ref.watch(isSortingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSorting ? 'ならびかえ中' : 'タスク管理'),
        centerTitle: true,
        leading: _buildAppBarAction(
          Icons.child_care,
          'プレビュー',
          () => ref.read(userModeProvider.notifier).enterPreview(),
        ),
        actions: [
          _buildAppBarAction(
            Icons.history,
            '履歴',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryPage()),
            ),
          ),
          if (!isSorting)
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
                : isSorting
                ? ReorderableListView.builder(
                  itemCount: taskList.length,
                  onReorder:
                      (old, next) => ref
                          .read(taskProvider.notifier)
                          .reorderTasks(old, next),
                  itemBuilder:
                      (context, index) => _buildTile(
                        context,
                        ref,
                        taskList[index],
                        index,
                        true,
                      ),
                )
                : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: taskList.length,
                  itemBuilder:
                      (context, index) => _buildTile(
                        context,
                        ref,
                        taskList[index],
                        index,
                        false,
                      ),
                ),
      ),
      floatingActionButton:
          !isSorting
              ? FloatingActionButton(
                onPressed: () => _showAddTaskDialog(context, ref),
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref,
    Task task,
    int index,
    bool isSorting,
  ) {
    return TaskTile(
      key: ValueKey(task.id),
      task: task,
      index: index,
      isSorting: isSorting,
      onEdit: () => _showEditTaskDialog(context, ref, task),
      onUndo: () => _showUndoConfirmDialog(context, ref, task),
      onComplete: () {}, // 親側では使用しない
      onRequestCorrection: (id) {}, // 親側では使用しない
    );
  }

  Widget _buildAppBarAction(IconData icon, String label, VoidCallback onTap) {
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

  // --- ダイアログ・アクション系 ---
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
        '完了したタスクを履歴に送りますか？',
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

  void _showUndoConfirmDialog(BuildContext context, WidgetRef ref, Task task) {
    _showConfirmDialog(context, 'やり直し', '「${task.title}」を未完了に戻しますか？', () {
      ref.read(taskProvider.notifier).toggleTask(task.id, task.isCompleted);
    });
  }
}
