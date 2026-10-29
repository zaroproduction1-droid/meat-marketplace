import 'package:flutter/material.dart';

import 'cutlink_logo.dart';

class DashboardActionRow {
  const DashboardActionRow(this.title, this.subtitle, this.icon, this.onTap);
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class DashboardMetric {
  const DashboardMetric(this.value, this.label, this.icon, this.onTap);
  final int value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// One clear buying/selling overview; every secondary tool stays in My CutLink.
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
    this.onCart,
    this.cartCount = 0,
  });
  final bool supplier;
  final String businessName, greeting;
  final Widget avatar;
  final int unread, cartCount;
  final VoidCallback onNotifications, onAccount, onSearch, onOrders, onSaved;
  final VoidCallback? onCart;
  final ValueChanged<String> onAnimal;
  final Future<void> Function() onRefresh;
  final List<DashboardMetric> metrics;
  final List<DashboardActionRow> attention, recent, buyAgain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget section(String label, VoidCallback more) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: more, child: const Text('View all')),
        ],
      ),
    );
    Widget rows(List<DashboardActionRow> items, String empty) => Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: items.isEmpty
          ? Padding(padding: const EdgeInsets.all(18), child: Text(empty))
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 52,
                      color: scheme.outlineVariant.withValues(alpha: .5),
                    ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    minLeadingWidth: 26,
                    leading: Icon(
                      items[i].icon,
                      color: scheme.primary,
                      size: 24,
                    ),
                    title: Text(
                      items[i].title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: items[i].subtitle.isEmpty
                        ? null
                        : Text(
                            items[i].subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: items[i].onTap,
                  ),
                ],
              ],
            ),
    );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey('ios-dashboard-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          Row(
            children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CutLinkLogo(width: 116, height: 38),
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: onNotifications,
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
              if (onCart != null)
                IconButton(
                  tooltip: 'My cart',
                  onPressed: onCart,
                  icon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                ),
              Semantics(
                label: 'My CutLink account',
                button: true,
                child: InkWell(
                  onTap: onAccount,
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(width: 40, height: 40, child: avatar),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            supplier ? businessName : greeting,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            supplier ? 'Your business today' : 'What do you need today?',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (!supplier) ...[
            const SizedBox(height: 14),
            Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search cuts, brands or suppliers',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final name in ['Beef', 'Lamb', 'Chicken', 'More'])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: name == 'More' ? 0 : 6),
                      child: OutlinedButton(
                        onPressed: () => onAnimal(name),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          minimumSize: const Size(44, 48),
                        ),
                        child: Text(
                          name,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = MediaQuery.textScalerOf(context).scale(1) > 1.4
                  ? 1
                  : metrics.length;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 8) / columns,
                      child: Material(
                        color: scheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: .5),
                          ),
                        ),
                        child: InkWell(
                          onTap: metric.onTap,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  metric.icon,
                                  size: 21,
                                  color: scheme.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${metric.value}',
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  metric.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (supplier) ...[
            section('Needs your attention', onOrders),
            rows(attention, 'You are all caught up.'),
            section('Recent orders', onOrders),
            rows(recent, 'Your new orders will appear here.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onOrders,
              child: const Text('View orders & work orders'),
            ),
          ] else ...[
            section('Your next order', onOrders),
            rows(recent.take(1).toList(), 'Your next order will appear here.'),
            section('Buy again', onSaved),
            rows(
              buyAgain,
              'Products from your recent orders will appear here.',
            ),
          ],
        ],
      ),
    );
  }
}
