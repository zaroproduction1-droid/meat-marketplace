import '../theme/cutlink_appearance.dart';

import 'package:flutter/material.dart';

class WorkspaceRequestError extends StatelessWidget {
  const WorkspaceRequestError({
    super.key,
    required this.onRetry,
    this.title = 'Could not load this page',
  });
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: CutLinkPalette.actionRed,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and try again. If the problem continues, contact CutLink support.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    ),
  );
}
