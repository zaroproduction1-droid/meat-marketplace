import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'cutlink_logo.dart';

/// Native iOS only. Browser and Android layouts keep their existing behavior.
bool useIosWorkspace(BuildContext context) =>
    !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;

abstract final class IosWorkspaceStyle {
  static const red = Color(0xFF850E25);
  static const ink = Color(0xFF191919);
  static const muted = Color(0xFF687078);
  static const canvas = Color(0xFFF7F7F7);

  static ThemeData theme(ThemeData base) => base.copyWith(
    platform: TargetPlatform.iOS,
    textTheme: base.textTheme.apply(fontFamily: '.SF Pro Text'),
    scaffoldBackgroundColor: Colors.white,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    colorScheme: base.colorScheme.copyWith(
      primary: red,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 56,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: red, width: 1.5),
      ),
      errorMaxLines: 3,
      helperMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: const StadiumBorder(),
        backgroundColor: red,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: const StadiumBorder(),
        foregroundColor: ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: canvas,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: Colors.white),
      showCloseIcon: true,
      closeIconColor: Colors.white,
    ),
  );
}

class IosTab {
  const IosTab(this.label, this.icon, {this.badge = 0});
  final String label;
  final IconData icon;
  final int badge;
}

/// Exactly five equal destinations, with no scrolling or hidden tab buttons.
class IosBottomBar extends StatelessWidget {
  const IosBottomBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelected,
  }) : assert(tabs.length == 5);
  final List<IosTab> tabs;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(12, 6, 12, 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: const Color(0xF21D1D1F),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: index == i,
                      button: true,
                      label: tabs[i].label,
                      child: Tooltip(
                        message: tabs[i].label,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(32),
                          onTap: () => onSelected(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 2,
                            ),
                            decoration: BoxDecoration(
                              color: index == i
                                  ? const Color(0xFF48484A)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Badge(
                                  isLabelVisible: tabs[i].badge > 0,
                                  label: Text(
                                    tabs[i].badge > 99
                                        ? '99+'
                                        : '${tabs[i].badge}',
                                  ),
                                  child: Icon(
                                    tabs[i].icon,
                                    color: Colors.white,
                                    size: 25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tabs[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class IosMenuLink {
  const IosMenuLink(
    this.title,
    this.icon,
    this.onTap, {
    this.subtitle,
    this.badge = 0,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;
  final int badge;
}

class IosMenuGroup {
  const IosMenuGroup(this.title, this.links);
  final String title;
  final List<IosMenuLink> links;
}

class IosMenuRow extends StatelessWidget {
  const IosMenuRow({super.key, required this.link});
  final IosMenuLink link;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 6),
    minVerticalPadding: 12,
    leading: CircleAvatar(
      radius: 24,
      backgroundColor: IosWorkspaceStyle.canvas,
      child: Icon(link.icon, color: IosWorkspaceStyle.ink, size: 24),
    ),
    title: Text(
      link.title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    subtitle: link.subtitle == null
        ? null
        : Text(
            link.subtitle!,
            style: const TextStyle(
              color: IosWorkspaceStyle.muted,
              fontSize: 13,
            ),
          ),
    trailing: link.badge > 0
        ? Badge(label: Text(link.badge > 99 ? '99+' : '${link.badge}'))
        : const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: IosWorkspaceStyle.muted,
          ),
    onTap: link.onTap,
  );
}

class IosAccountHub extends StatelessWidget {
  const IosAccountHub({
    super.key,
    required this.name,
    required this.role,
    required this.groups,
    required this.shortcuts,
    required this.onSignOut,
    this.avatar,
    this.trailing,
  });
  final String name, role;
  final List<IosMenuGroup> groups;
  final List<IosMenuLink> shortcuts;
  final VoidCallback onSignOut;
  final Widget? avatar, trailing;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
    children: [
      Row(
        children: [
          avatar ??
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFF4E5E8),
                child: Text(
                  name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 25,
                    color: IosWorkspaceStyle.red,
                  ),
                ),
              ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    color: IosWorkspaceStyle.muted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
      const SizedBox(height: 26),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = MediaQuery.textScalerOf(context).scale(1) > 1.4
              ? 1
              : 3;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in shortcuts)
                SizedBox(
                  width: (constraints.maxWidth - (columns - 1) * 10) / columns,
                  child: Material(
                    color: IosWorkspaceStyle.canvas,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: item.onTap,
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 5,
                        ),
                        child: Column(
                          children: [
                            Badge(
                              isLabelVisible: item.badge > 0,
                              label: Text(
                                item.badge > 99 ? '99+' : '${item.badge}',
                              ),
                              child: Icon(item.icon, size: 27),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      for (final group in groups) ...[
        const SizedBox(height: 28),
        Text(
          group.title,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final link in group.links) IosMenuRow(link: link),
        const Divider(height: 22),
      ],
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: onSignOut,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign out'),
      ),
    ],
  );
}

class IosSearchEntry extends StatelessWidget {
  const IosSearchEntry({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.search_rounded,
  });
  final String label;
  final VoidCallback onTap;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Material(
    color: IosWorkspaceStyle.canvas,
    borderRadius: BorderRadius.circular(30),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}

class IosWelcomePage extends StatelessWidget {
  const IosWelcomePage({
    super.key,
    required this.onSignIn,
    required this.onRegister,
  });
  final VoidCallback onSignIn, onRegister;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(26),
        children: [
          const SizedBox(height: 34),
          const Align(
            alignment: Alignment.centerLeft,
            child: CutLinkLogo(width: 170, height: 52),
          ),
          const SizedBox(height: 58),
          const Text(
            'Your trade.\nIn your pocket.',
            style: TextStyle(
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: IosWorkspaceStyle.ink,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Connect with suppliers and butchers. Manage products, orders and accounts wherever work takes you.',
            style: TextStyle(
              fontSize: 17,
              height: 1.5,
              color: IosWorkspaceStyle.muted,
            ),
          ),
          const SizedBox(height: 36),
          FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRegister,
            child: const Text('Register your business'),
          ),
          const SizedBox(height: 34),
          for (final entry in const [
            (
              'Products',
              Icons.inventory_2_outlined,
              'Find cuts or manage your inventory',
            ),
            (
              'Orders',
              Icons.receipt_long_outlined,
              'Follow every order through to fulfilment',
            ),
            (
              'Your business',
              Icons.business_outlined,
              'Keep accounts and support together',
            ),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(entry.$2, color: IosWorkspaceStyle.red),
              title: Text(entry.$1),
              subtitle: Text(entry.$3),
            ),
        ],
      ),
    ),
  );
}
