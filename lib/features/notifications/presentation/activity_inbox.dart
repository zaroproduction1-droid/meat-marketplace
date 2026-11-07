import 'package:flutter/material.dart';
import '../models/activity_group.dart';

class ActivityInbox extends StatefulWidget {
  const ActivityInbox({
    super.key,
    required this.rows,
    required this.loading,
    required this.unreadOnly,
    required this.category,
    required this.onFilter,
    required this.onOpen,
    required this.onRead,
    required this.onDismiss,
    required this.onRefresh,
    required this.hasMore,
    required this.onMore,
    this.error,
  });
  final List<Map<String, dynamic>> rows;
  final bool loading, unreadOnly, hasMore;
  final String? category, error;
  final void Function(bool unread, String? category) onFilter;
  final ValueChanged<Map<String, dynamic>> onOpen, onDismiss;
  final Future<void> Function(List<Map<String, dynamic>>) onRead;
  final Future<void> Function() onRefresh;
  final VoidCallback onMore;
  @override
  State<ActivityInbox> createState() => _ActivityInboxState();
}

class _ActivityInboxState extends State<ActivityInbox> {
  String? _selected;
  static const categories = {
    'orders': 'Orders',
    'delivery': 'Delivery',
    'quotes': 'Quotes',
    'invoices': 'Invoices',
    'messages': 'Messages',
    'payments': 'Payments',
    'credits': 'Credits',
    'support': 'Support',
    'moderation': 'Product reports',
    'platform': 'CutLink',
  };
  IconData _icon(String? category) => switch (category) {
    'orders' => Icons.shopping_bag_outlined,
    'delivery' => Icons.local_shipping_outlined,
    'invoices' || 'credits' || 'payments' => Icons.receipt_long_outlined,
    'support' || 'messages' => Icons.chat_bubble_outline,
    'moderation' => Icons.fact_check_outlined,
    _ => Icons.notifications_none,
  };
  String _day(ActivityGroup g) {
    final d = g.date;
    if (d == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _time(Map<String, dynamic> row) {
    final d = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
    return d == null
        ? ''
        : '${d.day}/${d.month} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _select(ActivityGroup g, bool wide) {
    setState(() => _selected = g.key);
    widget.onRead(g.events);
    if (!wide) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Activity details')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _details(g),
            ),
          ),
        ),
      );
    }
  }

  Widget _details(ActivityGroup g) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: cs.primary.withValues(alpha: .08),
          child: Icon(
            _icon(g.latest['category']?.toString()),
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          g.latest['title']?.toString() ?? 'Activity update',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          g.latest['detail']?.toString() ?? '',
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => widget.onOpen(g.latest),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(
            g.latest['reference_type'] == 'order'
                ? 'View order'
                : 'Open details',
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Activity history',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final e in g.events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            isThreeLine: true,
            leading: Icon(
              _icon(e['category']?.toString()),
              size: 20,
              color: cs.primary,
            ),
            title: Text(
              e['title']?.toString() ?? 'Update',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${e['detail'] ?? ''}\n${_time(e)}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Update actions',
              onSelected: (v) {
                if (v == 'open') widget.onOpen(e);
                if (v == 'dismiss') {
                  widget.onDismiss(e);
                  if (MediaQuery.sizeOf(context).width < 1000) {
                    Navigator.maybePop(context);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'open', child: Text('Open details')),
                PopupMenuItem(value: 'dismiss', child: Text('Dismiss update')),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groups = groupActivities(widget.rows);
    final selected = groups.where((g) => g.key == _selected).firstOrNull;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1000;
        final list = RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your inbox',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Filter activity',
                    initialValue: widget.category ?? 'all',
                    onSelected: (v) => widget.onFilter(
                      widget.unreadOnly,
                      v == 'all' ? null : v,
                    ),
                    icon: Badge(
                      isLabelVisible: widget.category != null,
                      child: const Icon(Icons.tune),
                    ),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'all',
                        child: Text('All categories'),
                      ),
                      for (final c in categories.entries)
                        PopupMenuItem(value: c.key, child: Text(c.value)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Orders, accounts and conversations',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('All activity'),
                    showCheckmark: false,
                    selected: !widget.unreadOnly,
                    onSelected: (_) => widget.onFilter(false, widget.category),
                  ),
                  ChoiceChip(
                    label: const Text('Unread'),
                    showCheckmark: false,
                    selected: widget.unreadOnly,
                    onSelected: (_) => widget.onFilter(true, widget.category),
                  ),
                ],
              ),
              if (widget.category != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text(
                      categories[widget.category] ?? widget.category!,
                    ),
                    onDeleted: () => widget.onFilter(widget.unreadOnly, null),
                  ),
                ),
              const SizedBox(height: 14),
              if (widget.loading) const LinearProgressIndicator(minHeight: 2),
              if (widget.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(widget.error!, style: TextStyle(color: cs.error)),
                      TextButton(
                        onPressed: widget.onRefresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (groups.isEmpty && !widget.loading && widget.error == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 70),
                  child: Column(
                    children: [
                      Icon(Icons.done_all, size: 40, color: cs.primary),
                      const SizedBox(height: 14),
                      const Text(
                        'You’re all caught up',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No updates in this view.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              for (var i = 0; i < groups.length; i++) ...[
                if (i == 0 || _day(groups[i]) != _day(groups[i - 1]))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
                    child: Text(
                      _day(groups[i]),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Material(
                  color: _selected == groups[i].key
                      ? cs.primary.withValues(alpha: .07)
                      : cs.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _select(groups[i], wide),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: cs.surfaceContainerHighest,
                            child: Icon(
                              _icon(groups[i].latest['category']?.toString()),
                              color: cs.primary,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  groups[i].latest['title']?.toString() ??
                                      'Update',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: groups[i].unread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  groups[i].latest['detail']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  '${_time(groups[i].latest)}${groups[i].events.length > 1 ? ' · ${groups[i].events.length} updates' : ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (groups[i].unread)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: CircleAvatar(
                                radius: 4,
                                backgroundColor: cs.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (widget.hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: OutlinedButton(
                    onPressed: widget.loading ? null : widget.onMore,
                    child: const Text('Load more activity'),
                  ),
                ),
            ],
          ),
        );
        if (!wide) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 6, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 5,
              child: selected == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 40,
                            color: cs.primary,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Select an update',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Details and related activity appear here.',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: _details(selected),
                    ),
            ),
          ],
        );
      },
    );
  }
}
