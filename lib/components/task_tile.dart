import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../view_models/task_view_model.dart';
import '../view_models/user_mode_view_model.dart';

class TaskTile extends ConsumerWidget {
  final Task task;
  final int index;
  final bool isSorting;
  final VoidCallback onEdit;
  final VoidCallback onUndo;
  final VoidCallback onComplete;
  final Function(String) onRequestCorrection;

  const TaskTile({
    super.key,
    required this.task,
    required this.index,
    required this.isSorting,
    required this.onEdit,
    required this.onUndo,
    required this.onComplete,
    required this.onRequestCorrection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(userModeProvider);
    final bool isParent = mode == UserMode.parent;
    final bool isPreview = mode == UserMode.preview;

    return Card(
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
        subtitle: _buildSubtitle(),
        trailing:
            isParent
                ? (isSorting ? null : _buildParentActions(ref))
                : _buildChildActions(ref, isPreview),
      ),
    );
  }

  Widget _buildSubtitle() {
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

  Widget? _buildChildActions(WidgetRef ref, bool isPreview) {
    if (task.isCompleted) {
      return task.requestNote.isEmpty
          ? TextButton(
            onPressed: isPreview ? null : () => onRequestCorrection(task.id),
            child: const Text(
              'まちがえた',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          )
          : null;
    }
    return task.startedAt == null
        ? ElevatedButton(
          onPressed:
              isPreview
                  ? null
                  : () => ref.read(taskProvider.notifier).startTask(task.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('はじめる'),
        )
        : ElevatedButton(
          onPressed: isPreview ? null : onComplete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('おわった！'),
        );
  }

  Widget _buildParentActions(WidgetRef ref) {
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
          onPressed: onEdit,
        ),
        if (task.isCompleted && task.requestNote.isEmpty)
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.orange, size: 20),
            onPressed: onUndo,
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: () => ref.read(taskProvider.notifier).deleteTask(task.id),
        ),
      ],
    );
  }
}
