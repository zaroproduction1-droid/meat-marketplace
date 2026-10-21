import 'package:flutter/material.dart';

import 'cutlink_workspace_theme.dart';

/// Apply explicitly inside dialog routes, which can sit above a workspace theme.
class CutLinkReviewTheme extends StatelessWidget {
  const CutLinkReviewTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CutLinkWorkspaceTheme(
    child: Builder(
      builder: (context) {
        final base = Theme.of(context);
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
                    color: const Color(0xFF66717E),
                  ),
                  titleLarge: base.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: CutLinkWorkspaceTheme.ink,
                  ),
                ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: CutLinkWorkspaceTheme.border),
              ),
              titleTextStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: CutLinkWorkspaceTheme.ink,
              ),
              contentTextStyle: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: CutLinkWorkspaceTheme.ink,
              ),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: CutLinkWorkspaceTheme.border),
              ),
            ),
            listTileTheme: const ListTileThemeData(
              iconColor: CutLinkWorkspaceTheme.red,
              titleTextStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CutLinkWorkspaceTheme.ink,
              ),
              subtitleTextStyle: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF66717E),
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
