import 'package:flutter/material.dart';

import 'catalogue_product_image.dart';

import 'customer_price_display.dart';
import 'ios_dashboard_style.dart';
import 'ios_dashboard_sections.dart';

class DashboardActionRow {
  const DashboardActionRow(
    this.title,
    this.subtitle,
    this.icon,
    this.onTap, {
    this.detail,
    this.product,
    this.historicalPrice,
    this.onOrder,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? detail, historicalPrice;
  final Map<String, dynamic>? product;
  final Future<void> Function()? onOrder;
}

class DashboardMetric {
  const DashboardMetric(this.value, this.label, this.icon, this.onTap);
  final int value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class IosDashboardHome extends StatelessWidget {
  const IosDashboardHome({
    super.key,
    required this.supplier,
    required this.businessName,
    required this.greeting,
    required this.avatar,
    required this.unread,
    required this.onNotifications,
    required this.onAccount,
    required this.onSearch,
    required this.onAnimal,
    required this.onOrders,
    required this.onRefresh,
    required this.metrics,
    required this.attention,
    required this.recent,
    required this.buyAgain,
    required this.onSaved,
    this.onWorkOrders,
    this.onCart,
    this.cartCount = 0,
    this.nextOrderTitle = 'Your next delivery',
    this.sections,
    this.shortcuts = const {},
  });
  final List<IosDashboardSection>? sections;
  final Map<String, DashboardActionRow> shortcuts;
  final bool supplier;
  final String businessName, greeting, nextOrderTitle;
  final Widget avatar;
  final int unread, cartCount;
  final VoidCallback onNotifications, onAccount, onSearch, onOrders, onSaved;
  final VoidCallback? onCart, onWorkOrders;
  final ValueChanged<String> onAnimal;
  final Future<void> Function() onRefresh;
  final List<DashboardMetric> metrics;
  final List<DashboardActionRow> attention, recent, buyAgain;

  @override
  Widget build(BuildContext context) {
    final p = IosDashboardPalette.of(context);
    return Theme(
      data: p.theme(Theme.of(context)),
      child: ColoredBox(
        key: const ValueKey('dashboard-canvas'),
        color: p.canvas,
        child: RefreshIndicator(
          color: p.accent,
          onRefresh: onRefresh,
          child: ListView(
            key: const PageStorageKey('ios-dashboard-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            children: [
              _header(p),
              const SizedBox(height: 8),
              Text(
                supplier ? businessName : greeting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, height: 1.25, color: p.muted),
              ),
              const SizedBox(height: 3),
              Text(
                supplier ? 'Your business today' : 'What do you need today?',
                style: TextStyle(
                  fontSize: 20,
                  height: 1.15,
                  letterSpacing: -.45,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
              if (!supplier) ...[const SizedBox(height: 14), _search(p)],
              for (final section in IosDashboardSection.normalise(
                supplier,
                sections,
              ))
                if (section.visible) ..._section(p, section.id),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _section(IosDashboardPalette p, String id) {
    switch (id) {
      case 'ios_categories':
        return [const SizedBox(height: 14), _categories(p)];
      case 'ios_metrics':
        return [const SizedBox(height: 14), _metrics(p)];
      case 'ios_attention':
        return [
          _heading(p, 'Needs your attention'),
          _panel(
            p,
            attention,
            empty: 'You are all caught up.',
            attentionOnly: true,
          ),
        ];
      case 'ios_recent':
        return [
          _heading(p, 'Recent orders', onOrders),
          _panel(
            p,
            recent.take(2).toList(),
            empty: 'Your new orders will appear here.',
            customers: true,
          ),
        ];
      case 'ios_delivery':
        return [
          _heading(p, nextOrderTitle, onOrders),
          _panel(
            p,
            recent.take(1).toList(),
            empty: 'Your next order will appear here.',
            delivery: true,
          ),
        ];
      case 'ios_buy_again':
        return [_heading(p, 'Buy again', onSaved), _buyAgain(p)];
      case 'ios_work_orders':
        return [
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: onWorkOrders ?? onOrders,
              style: FilledButton.styleFrom(
                backgroundColor: IosDashboardPalette.burgundy,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('View work orders'),
            ),
          ),
        ];
      default:
        final shortcut = shortcuts[id];
        if (shortcut == null) {
          return [];
        }
        return [
          const SizedBox(height: 14),
          _panel(p, [shortcut], empty: ''),
        ];
    }
  }

  Widget _header(IosDashboardPalette p) => SizedBox(
    height: 44,
    child: Row(
      children: [
        Expanded(
          child: Text(
            'CutLink',
            semanticsLabel: 'CutLink',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              color: p.dark ? Colors.white : IosDashboardPalette.burgundy,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: onNotifications,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: IosDashboardPalette.burgundy,
            textColor: Colors.white,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 23,
              color: p.ink,
            ),
          ),
        ),
        Semantics(
          label: 'My CutLink account',
          button: true,
          child: InkWell(
            onTap: onAccount,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.only(left: 5),
              child: SizedBox(
                width: 36,
                height: 44,
                child: Center(
                  child: ClipOval(
                    child: SizedBox(width: 32, height: 32, child: avatar),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _search(IosDashboardPalette p) => Material(
    color: p.search,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: p.border, width: .7),
    ),
    child: InkWell(
      onTap: onSearch,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.search, size: 21, color: p.muted),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Search cuts, brands or suppliers',
                style: TextStyle(fontSize: 12.5, height: 1.25, color: p.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _categories(IosDashboardPalette p) => Row(
    children: [
      for (final name in ['Beef', 'Lamb', 'Chicken', 'More'])
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: name == 'More' ? 0 : 8),
            child: AspectRatio(
              aspectRatio: .94,
              child: Material(
                key: ValueKey('category-$name'),
                color: p.search,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: BorderSide(color: p.border, width: .7),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onAnimal(name),
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                          child: name == 'More'
                              ? Center(
                                  child: Icon(
                                    Icons.more_horiz,
                                    size: 29,
                                    color: p.ink,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/cutlink-category-${name.toLowerCase()}.png',
                                  key: ValueKey('category-art-$name'),
                                  fit: BoxFit.contain,
                                  cacheWidth: 384,
                                  filterQuality: FilterQuality.high,
                                  excludeFromSemantics: true,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 3, bottom: 9),
                        child: Text(
                          name,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
  Widget _metrics(IosDashboardPalette p) => LayoutBuilder(
    builder: (context, constraints) {
      final large = MediaQuery.textScalerOf(context).scale(1) > 1.35;
      final columns = large ? 1 : metrics.length;
      if (columns == 0) {
        return const SizedBox.shrink();
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < metrics.length; i++)
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 8) / columns,
              child: Material(
                key: ValueKey('dashboard-stat-$i'),
                color: p.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                  side: BorderSide(color: p.border, width: .8),
                ),
                child: InkWell(
                  onTap: metrics[i].onTap,
                  borderRadius: BorderRadius.circular(11),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: supplier ? 106 : 66),
                    child: Padding(
                      padding: EdgeInsets.all(supplier ? 12 : 10),
                      child: supplier
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      metrics[i].icon,
                                      size: 21,
                                      color: p.accent,
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 15,
                                      color: p.muted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${metrics[i].value}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    height: 1.05,
                                    color: p.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  metrics[i].label,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.2,
                                    color: p.muted,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Icon(
                                  metrics[i].icon,
                                  size: 24,
                                  color: p.accent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${metrics[i].value}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          height: 1.1,
                                          fontWeight: FontWeight.w800,
                                          color: p.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        metrics[i].label,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.15,
                                          color: p.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (i == 0)
                                  Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: p.muted,
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
  Widget _heading(IosDashboardPalette p, String title, [VoidCallback? more]) =>
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
            ),
            if (more != null)
              Semantics(
                button: true,
                label: 'View all $title',
                child: InkWell(
                  onTap: more,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                    child: Text(
                      'View all',
                      style: TextStyle(fontSize: 12, color: p.accent),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
  Widget _panel(
    IosDashboardPalette p,
    List<DashboardActionRow> rows, {
    required String empty,
    bool delivery = false,
    bool attentionOnly = false,
    bool customers = false,
  }) => Container(
    decoration: BoxDecoration(
      color: p.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: p.border, width: .8),
    ),
    child: rows.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text(empty, style: TextStyle(fontSize: 12, color: p.muted)),
          )
        : Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: .8,
                    indent: 14,
                    endIndent: 14,
                    color: p.border,
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: rows[i].onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          if (customers)
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: p.search,
                              child: Text(
                                _initials(rows[i].title),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 36,
                              height: 36,
                              decoration: delivery
                                  ? BoxDecoration(
                                      color: p.search,
                                      shape: BoxShape.circle,
                                    )
                                  : null,
                              child: Icon(
                                rows[i].icon,
                                size: 24,
                                color: p.accent,
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rows[i].title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: attentionOnly ? 12.5 : 13,
                                    height: 1.25,
                                    fontWeight: attentionOnly
                                        ? FontWeight.w500
                                        : FontWeight.w600,
                                    color: p.ink,
                                  ),
                                ),
                                if (!attentionOnly &&
                                    rows[i].subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    rows[i].subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      height: 1.2,
                                      color: p.muted,
                                    ),
                                  ),
                                ],
                                if (delivery &&
                                    rows[i].detail?.isNotEmpty == true) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    rows[i].detail!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      height: 1.2,
                                      color: p.ink,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right, size: 17, color: p.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
  );
  Widget _buyAgain(IosDashboardPalette p) => Container(
    decoration: BoxDecoration(
      color: p.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: p.border, width: .8),
    ),
    child: buyAgain.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Products from your recent orders will appear here.',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          )
        : Column(
            children: [
              for (var i = 0; i < buyAgain.length && i < 2; i++) ...[
                if (i > 0) Divider(height: .8, indent: 70, color: p.border),
                _BuyAgainTile(row: buyAgain[i], palette: p),
              ],
            ],
          ),
  );
  static String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0].toUpperCase())
      .join();
}

class _BuyAgainTile extends StatefulWidget {
  const _BuyAgainTile({required this.row, required this.palette});
  final DashboardActionRow row;
  final IosDashboardPalette palette;
  @override
  State<_BuyAgainTile> createState() => _BuyAgainTileState();
}

class _BuyAgainTileState extends State<_BuyAgainTile> {
  bool _opening = false;
  Future<void> _order() async {
    if (_opening) {
      return;
    }
    if (widget.row.onOrder == null) {
      widget.row.onTap();
      return;
    }
    setState(() => _opening = true);
    try {
      await widget.row.onOrder!();
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final p = widget.palette;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final price = row.product != null
        ? CustomerPriceDisplay(
            product: row.product!,
            fontSize: 11.5,
            alignment: CrossAxisAlignment.end,
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Last paid', style: TextStyle(fontSize: 9, color: p.muted)),
              if (row.historicalPrice != null)
                Text(
                  row.historicalPrice!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
            ],
          );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: row.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: CatalogueProductImage(
                    product: row.product ?? const {},
                    thumbnail: true,
                    imageWidth: 54,
                    imageHeight: 54,
                    fit: BoxFit.cover,
                    allowGenericPreview: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.15,
                        color: p.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      row.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: p.muted,
                      ),
                    ),
                    if (large) ...[
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerLeft, child: price),
                    ],
                  ],
                ),
              ),
              if (!large) ...[
                const SizedBox(width: 5),
                SizedBox(width: 85, child: price),
              ],
              const SizedBox(width: 3),
              Semantics(
                label: 'Order ${row.title}',
                button: true,
                child: InkResponse(
                  onTap: _order,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 36,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: IosDashboardPalette.burgundy,
                          shape: BoxShape.circle,
                        ),
                        child: _opening
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
