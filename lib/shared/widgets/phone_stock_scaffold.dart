import 'package:flutter/material.dart';

/// Shared whole-page stock scrolling on phones and desktop.
class PhoneStockScaffold extends StatefulWidget {
  const PhoneStockScaffold({
    super.key,
    this.appBar,
    this.phoneHeader,
    this.backgroundColor,
    this.bottomNavigationBar,
    required this.body,
    required this.ready,
  });

  final PreferredSizeWidget? appBar;
  final Widget? phoneHeader;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget body;
  final bool ready;

  @override
  State<PhoneStockScaffold> createState() => _PhoneStockScaffoldState();
}

class _PhoneStockScaffoldState extends State<PhoneStockScaffold> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final headerHeight =
        (widget.appBar?.preferredSize.height ?? 80) + topPadding;
    final header =
        widget.phoneHeader ??
        SizedBox(height: headerHeight, child: widget.appBar);
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: widget.ready
          ? _PhoneStockHeaderScope(
              header: header,
              controller: _scroll,
              child: PrimaryScrollController.none(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.body,
                    Positioned(
                      right: 12,
                      bottom: 16,
                      child: SafeArea(
                        top: false,
                        child: AnimatedBuilder(
                          animation: _scroll,
                          builder: (context, child) {
                            final visible =
                                _scroll.hasClients &&
                                _scroll.position.pixels > headerHeight;
                            return IgnorePointer(
                              ignoring: !visible,
                              child: ExcludeSemantics(
                                excluding: !visible,
                                child: AnimatedOpacity(
                                  opacity: visible ? 1 : 0,
                                  duration: const Duration(milliseconds: 150),
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: FloatingActionButton.small(
                            heroTag: null,
                            tooltip: 'Back to top',
                            backgroundColor: const Color(0xFF741C1C),
                            foregroundColor: Colors.white,
                            onPressed: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              if (_scroll.hasClients) {
                                _scroll.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            },
                            child: const Icon(Icons.arrow_upward_rounded),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                header,
                Expanded(child: widget.body),
              ],
            ),
    );
  }
}

/// Resolves the controller inside the scaffold, not in the parent page context.
/// The title/actions and products are slivers of the very same viewport.
class PhoneStockScrollView extends StatelessWidget {
  const PhoneStockScrollView({
    super.key,
    required this.slivers,
    this.physics,
    this.maxContentWidth,
  });

  final List<Widget> slivers;
  final ScrollPhysics? physics;
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_PhoneStockHeaderScope>();
    assert(
      scope != null,
      'PhoneStockScrollView must be inside PhoneStockScaffold.',
    );
    return CustomScrollView(
      controller: scope?.controller,
      primary: scope == null ? null : false,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: physics,
      slivers: [
        if (scope != null) SliverToBoxAdapter(child: scope.header),
        if (maxContentWidth == null)
          ...slivers
        else
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    ((constraints.crossAxisExtent - maxContentWidth!) / 2)
                        .clamp(0.0, double.infinity)
                        .toDouble(),
              ),
              sliver: SliverMainAxisGroup(slivers: slivers),
            ),
          ),
      ],
    );
  }
}

class _PhoneStockHeaderScope extends InheritedWidget {
  const _PhoneStockHeaderScope({
    required this.header,
    required this.controller,
    required super.child,
  });

  final Widget header;
  final ScrollController controller;

  @override
  bool updateShouldNotify(_PhoneStockHeaderScope oldWidget) =>
      header != oldWidget.header || controller != oldWidget.controller;
}
