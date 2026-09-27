import 'package:flutter/material.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';

class NotificationActivityTile extends StatelessWidget {
  const NotificationActivityTile({
    super.key,
    required this.row,
    required this.onTap,
    this.compact = false,
  });
  final Map<String, dynamic> row;
  final VoidCallback? onTap;
  final bool compact;
  static IconData icon(String category) => switch (category) {
    'messages' || 'support' => Icons.chat_bubble_outline_rounded,
    'credits' => Icons.assignment_return_outlined,
    'payments' => Icons.payments_outlined,
    'delivery' => Icons.local_shipping_outlined,
    'invoices' => Icons.receipt_long_outlined,
    'quotes' => Icons.request_quote_outlined,
    _ => Icons.shopping_bag_outlined,
  };
  @override
  Widget build(BuildContext context) {
    final read = row['is_read'] == true;
    final category = row['category']?.toString() ?? 'activity';
    final date = DateTime.tryParse(
      row['created_at']?.toString() ?? '',
    )?.toLocal();
    final time = date == null
        ? ''
        : '${compact ? '' : '${date.day}/${date.month} • '}${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Material(
      color: read ? Colors.white : const Color(0xFFFCF7F7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: CutLinkWorkspaceTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 34 : 42,
                height: compact ? 34 : 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4E5E5),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon(category),
                  color: CutLinkWorkspaceTheme.red,
                  size: compact ? 18 : 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF6A6E75),
                              fontWeight: FontWeight.w700,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6A6E75),
                          ),
                        ),
                        if (!read) ...[
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.circle,
                            size: 7,
                            color: CutLinkWorkspaceTheme.red,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      row['title']?.toString() ?? 'Activity',
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                        color: CutLinkWorkspaceTheme.ink,
                      ),
                    ),
                    if ((row['detail']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        row['detail'].toString(),
                        maxLines: compact ? 2 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF6A6E75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
