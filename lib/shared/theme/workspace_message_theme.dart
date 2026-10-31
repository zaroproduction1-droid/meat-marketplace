import 'package:flutter/material.dart';

/// Explicit foreground/background pairs for both platforms and appearances.
SnackBarThemeData workspaceMessageTheme(Brightness brightness) =>
    SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF303034)
          : const Color(0xFF111C27),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: const Color(0xFFFFA4B1),
      disabledActionTextColor: const Color(0xFFC1C1C8),
      showCloseIcon: true,
      closeIconColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
