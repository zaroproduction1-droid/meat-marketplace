import 'package:flutter/material.dart';

/// Desktop widgets are returned unchanged. All adaptations are phone-only.
bool isPhoneLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final platform = Theme.of(context).platform;
  final handheld =
      platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  return size.width < 700 || (handheld && size.shortestSide < 600);
}

enum PhoneRowMode { stack, wrap, scroll, metrics }

/// Keep desktop table columns readable on a phone instead of crushing them.
class PhoneTable extends StatelessWidget {
  const PhoneTable({super.key, required this.desktop, this.minWidth = 640});
  final Widget desktop;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    if (!isPhoneLayout(context)) {
      return desktop;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'Swipe sideways to see all columns',
            style: TextStyle(fontSize: 11, color: Color(0xFF666A70)),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: desktop),
        ),
      ],
    );
  }
}

/// A document/form can scroll as one page on a phone, including with a keyboard.
class PhoneColumn extends StatelessWidget {
  const PhoneColumn({super.key, required this.desktop});
  final Column desktop;

  @override
  Widget build(BuildContext context) {
    if (!isPhoneLayout(context)) {
      return desktop;
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final child in desktop.children)
          child is Flexible ? child.child : child,
      ],
    );
  }
}

class PhoneExpanded extends StatelessWidget {
  const PhoneExpanded({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      isPhoneLayout(context) ? child : Expanded(child: child);
}

class PhoneSafeArea extends StatelessWidget {
  const PhoneSafeArea({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      isPhoneLayout(context) ? SafeArea(bottom: false, child: child) : child;
}

class PhoneFilterPanel extends StatelessWidget {
  const PhoneFilterPanel({super.key, required this.child, required this.label});
  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!isPhoneLayout(context)) {
      return child;
    }
    final media = MediaQuery.of(context);
    final available = media.size.height - media.viewInsets.bottom;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: ExpansionTile(
        title: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        leading: const Icon(Icons.tune, color: Color(0xFF741C1C)),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (available * .3).clamp(80.0, 240.0).toDouble(),
            ),
            child: SingleChildScrollView(child: child),
          ),
        ],
      ),
    );
  }
}

class PhoneRow extends StatelessWidget {
  const PhoneRow({
    super.key,
    required this.desktop,
    this.mode = PhoneRowMode.stack,
  });

  final Row desktop;
  final PhoneRowMode mode;

  Widget _content(Widget child) {
    if (child is Flexible) {
      return _content(child.child);
    }
    if (child is SizedBox && child.child != null) {
      return SizedBox(height: child.height, child: child.child);
    }
    return child;
  }

  bool _isGap(Widget child) =>
      child is Spacer ||
      child is VerticalDivider ||
      (child is SizedBox && child.child == null);

  @override
  Widget build(BuildContext context) {
    if (!isPhoneLayout(context)) {
      return desktop;
    }
    if (mode == PhoneRowMode.scroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: desktop.children),
      );
    }
    final children = desktop.children.where((child) => !_isGap(child)).toList();
    if (mode == PhoneRowMode.metrics) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 300 ? 2 : 1;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final child in children)
                SizedBox(
                  width: (width - (columns - 1) * 10) / columns,
                  child: _content(child),
                ),
            ],
          );
        },
      );
    }
    if (mode == PhoneRowMode.wrap) {
      var hasIdentity = false;
      // Keep the item's icon and identity together, then flow other details
      // underneath. Avoid LayoutBuilder here so dialog intrinsic sizing works.
      if (children.length >= 2 &&
          (children.first is Icon || children.first is Container) &&
          children[1] is Flexible) {
        final leading = children.removeAt(0);
        final identity = _content(children.removeAt(0));
        hasIdentity = true;
        children.insert(
          0,
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                leading,
                const SizedBox(width: 10),
                Expanded(child: identity),
              ],
            ),
          ),
        );
      }
      final phoneChildren = <Widget>[];
      for (final child in children) {
        if (child is Flexible) {
          phoneChildren.add(
            hasIdentity
                ? FractionallySizedBox(widthFactor: .48, child: _content(child))
                : SizedBox(width: double.infinity, child: _content(child)),
          );
          hasIdentity = true;
        } else {
          phoneChildren.add(child);
        }
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: phoneChildren,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _content(children[index]),
        ],
      ],
    );
  }
}

/// Keep dialog fields and confirmation actions reachable above a phone keyboard.
AlertDialog phoneDialog(BuildContext context, AlertDialog desktop) {
  if (!isPhoneLayout(context)) {
    return desktop;
  }
  return AlertDialog(
    key: desktop.key,
    icon: desktop.icon,
    iconPadding: desktop.iconPadding,
    iconColor: desktop.iconColor,
    title: desktop.title,
    titlePadding: desktop.titlePadding,
    titleTextStyle: desktop.titleTextStyle,
    content: desktop.content,
    contentPadding: desktop.contentPadding,
    contentTextStyle: desktop.contentTextStyle,
    actions: desktop.actions,
    actionsPadding: desktop.actionsPadding,
    actionsAlignment: desktop.actionsAlignment,
    actionsOverflowAlignment: desktop.actionsOverflowAlignment,
    actionsOverflowDirection: desktop.actionsOverflowDirection,
    actionsOverflowButtonSpacing: desktop.actionsOverflowButtonSpacing,
    buttonPadding: desktop.buttonPadding,
    backgroundColor: desktop.backgroundColor,
    elevation: desktop.elevation,
    shadowColor: desktop.shadowColor,
    surfaceTintColor: desktop.surfaceTintColor,
    semanticLabel: desktop.semanticLabel,
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    clipBehavior: desktop.clipBehavior,
    shape: desktop.shape,
    alignment: desktop.alignment,
    scrollable: true,
  );
}

/// Retains every action and moves crowded toolbars beneath the title on phones.
AppBar phoneAppBar(BuildContext context, AppBar desktop) {
  if (!isPhoneLayout(context)) {
    return desktop;
  }
  final actions = desktop.actions ?? const <Widget>[];
  final controls = actions.where((action) => action is! SizedBox).toList();
  final separateActions =
      controls.length > 2 || controls.any((action) => action is! IconButton);
  final bottom = desktop.bottom;
  final title = desktop.title;
  final phoneTitle = title is Row
      ? Row(
          children: [
            for (final child in title.children)
              if (child is Text) Flexible(child: child) else child,
          ],
        )
      : title;
  return AppBar(
    key: desktop.key,
    leading: desktop.leading,
    automaticallyImplyLeading: desktop.automaticallyImplyLeading,
    title: phoneTitle,
    actions: separateActions ? null : desktop.actions,
    flexibleSpace: desktop.flexibleSpace,
    bottom: separateActions
        ? PreferredSize(
            preferredSize: Size.fromHeight(
              52 + (bottom?.preferredSize.height ?? 0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: actions),
                  ),
                ),
                ?bottom,
              ],
            ),
          )
        : bottom,
    elevation: desktop.elevation,
    scrolledUnderElevation: desktop.scrolledUnderElevation,
    shadowColor: desktop.shadowColor,
    surfaceTintColor: desktop.surfaceTintColor,
    shape: desktop.shape,
    backgroundColor: desktop.backgroundColor,
    foregroundColor: desktop.foregroundColor,
    iconTheme: desktop.iconTheme,
    actionsIconTheme: desktop.actionsIconTheme,
    primary: desktop.primary,
    centerTitle: desktop.centerTitle,
    excludeHeaderSemantics: desktop.excludeHeaderSemantics,
    titleSpacing: 12,
    toolbarHeight: desktop.toolbarHeight,
    leadingWidth: desktop.leadingWidth,
    toolbarTextStyle: desktop.toolbarTextStyle,
    titleTextStyle: desktop.titleTextStyle,
    systemOverlayStyle: desktop.systemOverlayStyle,
    forceMaterialTransparency: desktop.forceMaterialTransparency,
    clipBehavior: desktop.clipBehavior,
  );
}
