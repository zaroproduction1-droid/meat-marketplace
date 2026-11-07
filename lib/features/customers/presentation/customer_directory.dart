import 'package:flutter/material.dart';

class CustomerDirectoryEntry {
  const CustomerDirectoryEntry({
    required this.id,
    required this.name,
    required this.external,
    required this.terms,
    required this.status,
    required this.active,
    this.outstanding,
    this.overdue,
    required this.details,
  });
  final String id, name, terms, status;
  final bool external, active;
  final double? outstanding, overdue;
  final WidgetBuilder details;
}

/// Presentation only. Account permissions and mutations stay with the caller.
class CustomerDirectory extends StatefulWidget {
  const CustomerDirectory({
    super.key,
    required this.entries,
    required this.onAdd,
    required this.onVip,
    required this.pendingVip,
    required this.onRefresh,
  });
  final List<CustomerDirectoryEntry> entries;
  final VoidCallback onAdd, onVip;
  final int pendingVip;
  final Future<void> Function() onRefresh;
  @override
  State<CustomerDirectory> createState() => _CustomerDirectoryState();
}

class _CustomerDirectoryState extends State<CustomerDirectory> {
  String _query = '', _tab = 'All', _sort = 'name';
  bool _overdue = false;
  String? _selected;
  final _detailRevision = ValueNotifier<int>(0);

  @override
  void didUpdateWidget(covariant CustomerDirectory oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _detailRevision.value++;
    });
  }

  @override
  void dispose() {
    _detailRevision.dispose();
    super.dispose();
  }

  String _money(double value) =>
      '\$${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
  List<CustomerDirectoryEntry> get _rows {
    final words = _query.trim().toLowerCase().split(RegExp(r'\s+'));
    final rows = widget.entries
        .where(
          (e) =>
              (_tab == 'All' ||
                  (e.external ? _tab == 'External' : _tab == 'CutLink')) &&
              (!_overdue || (e.overdue ?? 0) > 0) &&
              words.every(
                (w) => '${e.name} ${e.terms} ${e.status}'
                    .toLowerCase()
                    .contains(w),
              ),
        )
        .toList();
    rows.sort(
      (a, b) => switch (_sort) {
        'balance' => (b.outstanding ?? 0).compareTo(a.outstanding ?? 0),
        'overdue' => (b.overdue ?? 0).compareTo(a.overdue ?? 0),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      },
    );
    return rows;
  }

  Widget _panel(Widget child) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _metric(
    String label,
    String value,
    IconData icon, {
    bool alert = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return _panel(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: alert ? cs.error : cs.primary, size: 21),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _select(CustomerDirectoryEntry entry, bool wide) {
    setState(() => _selected = entry.id);
    if (!wide) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Customer account',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              ListenableBuilder(
                listenable: _detailRevision,
                builder: (context, _) {
                  final current = widget.entries
                      .where((e) => e.id == entry.id)
                      .firstOrNull;
                  return current?.details(context) ??
                      const Text('This account is no longer available.');
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
  }

  Widget _row(CustomerDirectoryEntry e, bool wide) {
    final cs = Theme.of(context).colorScheme;
    final late = (e.overdue ?? 0) > 0;
    return InkWell(
      onTap: () => _select(e, wide),
      child: Container(
        color: _selected == e.id ? cs.primary.withValues(alpha: .06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: cs.surfaceContainerHighest,
              child: Icon(
                e.external ? Icons.person_outline : Icons.storefront_outlined,
                size: 21,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${e.external ? 'External' : 'CutLink'} · ${e.terms}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    e.outstanding == null ? '—' : _money(e.outstanding!),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    late ? 'Overdue ${_money(e.overdue!)}' : e.status,
                    maxLines: 2,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: late ? cs.error : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = _rows;
    final selected = widget.entries.where((e) => e.id == _selected).firstOrNull;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1050;
        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: EdgeInsets.all(box.maxWidth < 600 ? 16 : 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your customers',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${widget.entries.length} customers · Accounts at a glance',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Add external customer',
                    onPressed: widget.onAdd,
                    style: IconButton.styleFrom(foregroundColor: cs.onPrimary),
                    icon: const Icon(Icons.person_add_alt_1),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _metric(
                      'Outstanding',
                      _money(
                        widget.entries.fold(
                          0.0,
                          (v, e) => v + (e.outstanding ?? 0),
                        ),
                      ),
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metric(
                      'Overdue',
                      _money(
                        widget.entries.fold(
                          0.0,
                          (v, e) => v + (e.overdue ?? 0),
                        ),
                      ),
                      Icons.schedule,
                      alert: true,
                    ),
                  ),
                  if (box.maxWidth >= 650) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metric(
                        'Active accounts',
                        '${widget.entries.where((e) => e.active).length}',
                        Icons.people_outline,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _panel(
                ListTile(
                  dense: true,
                  onTap: widget.onVip,
                  leading: Icon(
                    Icons.workspace_premium_outlined,
                    color: cs.primary,
                  ),
                  title: const Text(
                    'VIP applications',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    widget.pendingVip > 0
                        ? '${widget.pendingVip} waiting for review'
                        : 'Pricing and credit requests',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextField(
                                  onChanged: (v) => setState(() => _query = v),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Search customers or account terms',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    for (final tab in [
                                      'All',
                                      'CutLink',
                                      'External',
                                    ])
                                      ChoiceChip(
                                        showCheckmark: false,
                                        label: Text(tab),
                                        selected: _tab == tab,
                                        onSelected: (_) =>
                                            setState(() => _tab = tab),
                                      ),
                                    FilterChip(
                                      label: const Text('Overdue'),
                                      selected: _overdue,
                                      onSelected: (v) =>
                                          setState(() => _overdue = v),
                                    ),
                                    PopupMenuButton<String>(
                                      tooltip: 'Sort customers',
                                      initialValue: _sort,
                                      onSelected: (v) =>
                                          setState(() => _sort = v),
                                      icon: const Icon(Icons.sort),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'name',
                                          child: Text('Name A–Z'),
                                        ),
                                        PopupMenuItem(
                                          value: 'balance',
                                          child: Text('Highest balance'),
                                        ),
                                        PopupMenuItem(
                                          value: 'overdue',
                                          child: Text('Most overdue'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${rows.length} customers',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Outstanding',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          if (rows.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No customers match these filters.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          for (var i = 0; i < rows.length; i++) ...[
                            _row(rows[i], wide),
                            if (i < rows.length - 1)
                              const Divider(height: 1, indent: 60),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _panel(
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Account overview',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (selected != null)
                                selected.details(context)
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 64,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.person_search_outlined,
                                        size: 36,
                                        color: cs.primary,
                                      ),
                                      const SizedBox(height: 14),
                                      const Text('Select a customer'),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Balances, terms and account actions',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
