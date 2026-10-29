import 'package:flutter/material.dart';

import '../navigation/workspace_navigation.dart';

/// Keeps visited primary workspaces mounted for this signed-in session only.
/// Editors outside this allow-list are disposed normally after navigation.
class RetainedIosWorkspace extends StatefulWidget {
  const RetainedIosWorkspace({
    super.key,
    required this.child,
    this.reverse = false,
  });
  final Widget child;
  final bool reverse;
  @override
  State<RetainedIosWorkspace> createState() => _RetainedIosWorkspaceState();
}

class _RetainedIosWorkspaceState extends State<RetainedIosWorkspace>
    with SingleTickerProviderStateMixin {
  static const _retained = {
    'dashboard',
    'my_cutlink',
    'browse',
    'orders',
    'work_orders',
    'inventory',
    'favourites',
    'suppliers',
    'invoices',
    'accounts',
  };
  final Map<Key, Widget> _pages = {};
  Key? _previous;
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 280),
        value: 1,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _previous = null;
            _prune();
          });
        }
      });
  Key get _key => widget.child.key!;
  void _prune() => _pages.removeWhere(
    (key, _) =>
        key != _key &&
        key != _previous &&
        !(key is ValueKey<String> && _retained.contains(key.value)),
  );

  @override
  void didUpdateWidget(RetainedIosWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.key != _key) {
      _previous = oldWidget.child.key;
      if (MediaQuery.disableAnimationsOf(context)) {
        _previous = null;
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
    _prune();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _pages[_key] = widget.child;
    final direction = widget.reverse ? -1.0 : 1.0;
    final curved = _controller.drive(CurveTween(curve: Curves.easeInOutCubic));
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final entry in _pages.entries)
            Offstage(
              key: entry.key,
              offstage: entry.key != _key && entry.key != _previous,
              child: TickerMode(
                enabled: entry.key == _key,
                child: WorkspaceActivityScope(
                  active: entry.key == _key,
                  child: ExcludeSemantics(
                    excluding: entry.key != _key,
                    child: IgnorePointer(
                      ignoring: entry.key != _key,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: entry.key == _key
                              ? Offset(direction, 0)
                              : Offset.zero,
                          end: entry.key == _key
                              ? Offset.zero
                              : Offset(-direction, 0),
                        ).animate(curved),
                        child: ColoredBox(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: entry.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
