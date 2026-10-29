import 'package:flutter/widgets.dart';

typedef WorkspaceExitHandler = Future<void> Function(VoidCallback onLeave);

/// Allows the persistent tab bar to respect the active form's discard guard.
class WorkspaceNavigation {
  final Map<Object, WorkspaceExitHandler> _guards = {};
  bool _navigating = false;

  void register(Object owner, WorkspaceExitHandler handler) {
    _guards[owner] = handler;
  }

  void unregister(Object owner) => _guards.remove(owner);

  Future<void> navigate(VoidCallback action) async {
    if (_navigating) {
      return;
    }
    _navigating = true;
    try {
      if (_guards.isEmpty) {
        action();
      } else {
        await _guards.values.last(action);
      }
    } finally {
      _navigating = false;
    }
  }
}

class WorkspaceNavigationScope extends InheritedWidget {
  const WorkspaceNavigationScope({
    super.key,
    required this.navigation,
    required super.child,
  });
  final WorkspaceNavigation navigation;
  @override
  bool updateShouldNotify(WorkspaceNavigationScope oldWidget) =>
      oldWidget.navigation != navigation;
}

/// Retained list screens must not keep an inactive form's exit guard active.
class WorkspaceActivityScope extends InheritedWidget {
  const WorkspaceActivityScope({
    super.key,
    required this.active,
    required super.child,
  });
  final bool active;
  static bool activeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WorkspaceActivityScope>()
          ?.active ??
      true;
  @override
  bool updateShouldNotify(WorkspaceActivityScope oldWidget) =>
      active != oldWidget.active;
}
