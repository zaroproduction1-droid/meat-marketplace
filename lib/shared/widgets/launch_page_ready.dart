import 'package:flutter/widgets.dart';

/// Initial routes signal after their first usable frame; never bypasses auth.
class LaunchPageReady extends InheritedWidget {
  const LaunchPageReady({
    super.key,
    required this.onReady,
    required super.child,
  });
  final VoidCallback onReady;
  static void signal(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<LaunchPageReady>();
    if (scope != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => scope.onReady());
    }
  }

  @override
  bool updateShouldNotify(LaunchPageReady oldWidget) => false;
}
