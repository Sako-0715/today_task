import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'view_models/task_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const TaskListPage(),
    );
  }
}

// StatelessWidget から ConsumerWidget に変更！
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Firebaseのタスク一覧をリアルタイムに監視
    final taskList = ref.watch(taskProvider);

    // ★ 開発用の切り替えスイッチ（ここを true/false で切り替えて確認してください）
    const bool isParent = false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isParent ? '【親】タスクを出す' : '【子】今日のタスク'),
        centerTitle: true,
      ),
      body:
          taskList.isEmpty
              ? const Center(
                child: Text('タスクはありません', style: TextStyle(color: Colors.grey)),
              )
              : ListView.builder(
                itemCount: taskList.length,
                itemBuilder: (context, index) {
                  final task = taskList[index];
                  return ListTile(
                    // チェックボックス（完了・未完了の切り替え）
                    leading: Checkbox(
                      value: task.isCompleted,
                      onChanged: (val) {
                        ref
                            .read(taskProvider.notifier)
                            .toggleTask(task.id, task.isCompleted);
                      },
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration:
                            task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                        color: task.isCompleted ? Colors.grey : Colors.black,
                      ),
                    ),
                    // ★親モードの時だけ削除ボタン（ゴミ箱）を表示
                    trailing:
                        isParent
                            ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed:
                                  () => ref
                                      .read(taskProvider.notifier)
                                      .deleteTask(task.id),
                            )
                            : null,
                  );
                },
              ),
      // ★親モードの時だけ追加ボタンを表示
      floatingActionButton:
          isParent
              ? FloatingActionButton(
                onPressed: () => _showAddTaskDialog(context, ref),
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  // タスク追加ダイアログ
  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('新しいタスクを追加'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '例：宿題をする'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    ref.read(taskProvider.notifier).addTask(controller.text);
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
