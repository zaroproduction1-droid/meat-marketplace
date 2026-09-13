import 'package:flutter/material.dart';

abstract final class CutLinkNotice {
  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    bool error = false,
    Duration duration = const Duration(seconds: 4),
  }) {
    _removeActive();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final width = MediaQuery.sizeOf(overlayContext).width;
        final horizontalInset = width < 600 ? 14.0 : 24.0;

        return Positioned(
          top: 16,
          right: horizontalInset,
          left: width < 600 ? horizontalInset : null,
          child: SafeArea(
            bottom: false,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset((1 - value) * 26, 0),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Align(
                alignment: Alignment.topRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: error
                              ? const Color(0xFFE8B9B9)
                              : const Color(0xFFDDE2E7),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 72,
                            decoration: BoxDecoration(
                              color: error
                                  ? const Color(0xFFB3261E)
                                  : const Color(0xFF741C1C),
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Icon(
                              error
                                  ? Icons.error_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 20,
                              color: error
                                  ? const Color(0xFFB3261E)
                                  : const Color(0xFF741C1C),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (title != null && title.trim().isNotEmpty) ...[
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Color(0xFF1E2429),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                  ],
                                  Text(
                                    message,
                                    style: const TextStyle(
                                      color: Color(0xFF50555A),
                                      fontSize: 12.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () {
                              if (entry.mounted) {
                                entry.remove();
                              }
                              if (identical(_activeEntry, entry)) {
                                _activeEntry = null;
                              }
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: const Color(0xFF62676C),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);

    Future<void>.delayed(duration, () {
      if (entry.mounted) {
        entry.remove();
      }
      if (identical(_activeEntry, entry)) {
        _activeEntry = null;
      }
    });
  }

  static void _removeActive() {
    final entry = _activeEntry;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
    _activeEntry = null;
  }
}
