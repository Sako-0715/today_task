import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/task_view_model.dart';
import '../view_models/user_mode_view_model.dart';

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
