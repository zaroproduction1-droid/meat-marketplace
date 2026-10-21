import 'package:flutter/material.dart';

import 'workspace_back_button.dart';

/// Protects in-app back navigation without persisting business data on a device.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.isDirty,
    required this.isBusy,
    required this.child,
    this.message =
        'Stay here to keep editing. Your changes have not been saved.',
    this.onDiscard,
  });
  final bool Function() isDirty;
  final bool Function() isBusy;
  final Widget child;
  final String message;
  final Future<void> Function()? onDiscard;

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _allowExit = false;
  bool _prompting = false;

  Future<void> _requestExit(Object? result, [VoidCallback? onLeave]) async {
    if (_prompting) {
      return;
    }
    if (widget.isBusy()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for saving to finish.')),
      );
      return;
    }
    _prompting = true;
    var leave = true;
    if (widget.isDirty()) {
      leave =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Discard unsaved changes?'),
              content: Text(widget.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep editing'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard and leave'),
                ),
              ],
            ),
          ) ??
          false;
    }
    _prompting = false;
    if (!mounted || !leave || widget.isBusy()) {
      return;
    }
    if (widget.isDirty() && widget.onDiscard != null) {
      try {
        await widget.onDiscard!();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not discard the draft. Please try again.'),
            ),
          );
        }
        return;
      }
      if (!mounted) {
        return;
      }
    }
    if (onLeave != null) {
      onLeave();
      return;
    }
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final outerBack = context
        .dependOnInheritedWidgetOfExactType<WorkspaceBackScope>()
        ?.onBack;
    return PopScope<Object?>(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _requestExit(result);
        }
      },
      child: WorkspaceBackScope(
        onBack: () => _requestExit(null, outerBack),
        child: widget.child,
      ),
    );
  }
}
