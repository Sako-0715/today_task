import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../view_models/task_view_model.dart';
import '../../view_models/user_mode_view_model.dart';
import '../../components/task_tile.dart';
import '../history_page.dart';

class ChildTaskPage extends ConsumerWidget {
  const ChildTaskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskList = ref.watch(taskProvider);
    final mode = ref.watch(userModeProvider);
    final bool isPreview = mode == UserMode.preview;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPreview ? '子の画面(プレビュー)' : '今日のタスク'),
        centerTitle: true,
        leading:
            isPreview
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
                : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: taskList.length,
                  itemBuilder:
                      (context, index) => TaskTile(
                        key: ValueKey(taskList[index].id),
                        task: taskList[index],
                        index: index,
                        isSorting: false,
                        onEdit: () {}, // 子側では使用しない
                        onUndo: () {}, // 子側では使用しない
                        onComplete:
                            () => _showCompleteConfirmDialog(
                              context,
                              ref,
                              taskList[index],
                            ),
                        onRequestCorrection:
                            (id) => _showRequestCorrectionDialog(
                              context,
                              ref,
                              taskList[index],
                            ),
                      ),
                ),
      ),
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
}
