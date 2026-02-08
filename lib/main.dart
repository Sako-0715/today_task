import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// ビューモデル（状態管理）
import 'view_models/user_mode_view_model.dart';

// 各画面（Views）
import 'views/mode_selection_page.dart';
import 'views/parent/parent_task_page.dart';
import 'views/child/child_task_page.dart';

void main() async {
  // Flutterのシステム初期化
  WidgetsFlutterBinding.ensureInitialized();

  // Firebaseの初期化
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Riverpodを有効にするためProviderScopeでラップ
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ユーザーが現在「親」か「子」か、あるいは「未選択」かを監視
    final mode = ref.watch(userModeProvider);

    return MaterialApp(
      title: 'Today Task',
      debugShowCheckedModeBanner: false,
      // アプリ全体の共通デザイン設定
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
      // 状態（mode）に応じて表示する画面を完全に切り替える
      home: _getHomePage(mode),
    );
  }

  /// 現在のユーザーモードに基づいてトップ画面を判定するロジック
  Widget _getHomePage(UserMode mode) {
    switch (mode) {
      case UserMode.parent:
        // 親モード：管理機能付きの画面へ
        return const ParentTaskPage();

      case UserMode.child:
      case UserMode.preview:
        // 子モード or プレビュー：タスク実行画面へ
        return const ChildTaskPage();

      case UserMode.none:
        return const ModeSelectionPage();
    }
  }
}
