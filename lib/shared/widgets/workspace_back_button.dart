import 'package:flutter/material.dart';

class WorkspaceBackScope extends InheritedWidget {
  const WorkspaceBackScope({
    super.key,
    required this.onBack,
    required super.child,
  });
  final VoidCallback onBack;
  @override
  bool updateShouldNotify(WorkspaceBackScope oldWidget) =>
      oldWidget.onBack != onBack;
}

class WorkspaceBackButton extends StatelessWidget {
  const WorkspaceBackButton({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<WorkspaceBackScope>();
    return IconButton(
      tooltip: scope == null ? 'Back' : 'Back to dashboard',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed:
          scope?.onBack ??
          () {
            Navigator.of(context).maybePop();
          },
    );
  }
}
