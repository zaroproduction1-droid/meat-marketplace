import '../theme/cutlink_appearance.dart';

import 'package:flutter/material.dart';

/// Static placeholders respect reduced-motion settings and reserve useful space.
class WorkspaceLoading extends StatelessWidget {
  const WorkspaceLoading({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 20),
                  for (var i = 0; i < 5; i++)
                    Container(
                      height: 84,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CutLinkPalette.surface,
                        border: Border.all(
                          color: CutLinkPalette.color(0xFFE3E5E8),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          _Placeholder(width: 48, height: 48),
                          SizedBox(width: 16),
                          Expanded(child: _Placeholder(height: 16)),
                        ],
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
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, required this.height});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: CutLinkPalette.color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
