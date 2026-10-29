import '../theme/cutlink_appearance.dart';

import 'package:flutter/material.dart';

import 'cutlink_workspace_theme.dart';
import 'ios_workspace.dart';

/// Apply explicitly inside dialog routes, which can sit above a workspace theme.
class CutLinkReviewTheme extends StatelessWidget {
  const CutLinkReviewTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return CutLinkWorkspaceTheme(
      child: Builder(
        builder: (context) {
          final base = Theme.of(context);
          if (useIosWorkspace(context)) {
            return Theme(data: IosWorkspaceStyle.theme(base), child: child);
          }
          return Theme(
            data: base.copyWith(
              textTheme: base.textTheme
                  .apply(
                    bodyColor: CutLinkWorkspaceTheme.ink,
                    displayColor: CutLinkWorkspaceTheme.ink,
                  )
                  .copyWith(
                    bodyMedium: base.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.45,
                      color: CutLinkWorkspaceTheme.ink,
                    ),
                    bodySmall: base.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.4,
                      color: CutLinkPalette.color(0xFF66717E),
                    ),
                    titleLarge: base.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: CutLinkWorkspaceTheme.ink,
                    ),
                  ),
              dialogTheme: DialogThemeData(
                backgroundColor: CutLinkPalette.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: CutLinkWorkspaceTheme.border),
                ),
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: CutLinkWorkspaceTheme.ink,
                ),
                contentTextStyle: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: CutLinkWorkspaceTheme.ink,
                ),
              ),
              cardTheme: CardThemeData(
                color: CutLinkPalette.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: CutLinkWorkspaceTheme.border),
                ),
              ),
              listTileTheme: ListTileThemeData(
                iconColor: CutLinkWorkspaceTheme.red,
                titleTextStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CutLinkWorkspaceTheme.ink,
                ),
                subtitleTextStyle: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: CutLinkPalette.color(0xFF66717E),
                ),
              ),
              dropdownMenuTheme: const DropdownMenuThemeData(
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.white),
                ),
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }
}
