import 'package:flutter/material.dart';

/// A compact summary that keeps secondary detail in the destination page.
class CompactWorkspaceTile extends StatelessWidget {
  const CompactWorkspaceTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.leading,
    this.detail,
    this.trailing,
    this.footer,
  });
  final String title, subtitle;
  final VoidCallback? onTap;
  final Widget? leading, detail, trailing, footer;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant, width: .7),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (detail != null) ...[
                          const SizedBox(height: 7),
                          detail!,
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 5),
                    trailing!,
                  ],
                ],
              ),
              if (footer != null) ...[const SizedBox(height: 8), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
