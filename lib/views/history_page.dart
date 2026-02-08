import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../view_models/task_view_model.dart';

// --- 履歴一覧画面 ---
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('読み込みエラーが発生しました'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('まだ履歴がありません'));
          }

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

// --- 特定の日の履歴詳細 ---
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
