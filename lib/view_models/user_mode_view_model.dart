import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'task_view_model.dart';

enum UserMode { none, parent, child, preview }

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
