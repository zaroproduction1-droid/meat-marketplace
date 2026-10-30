/// iPhone layout entries share the existing saved layout, with distinct IDs so
/// editing the phone home never changes the desktop cards.
class IosDashboardSection {
  const IosDashboardSection(this.id, {this.visible = true});
  final String id;
  final bool visible;

  static List<IosDashboardSection> defaults(bool supplier) => [
    if (!supplier) const IosDashboardSection('ios_categories'),
    const IosDashboardSection('ios_metrics'),
    if (supplier) const IosDashboardSection('ios_attention'),
    IosDashboardSection(supplier ? 'ios_recent' : 'ios_delivery'),
    IosDashboardSection(supplier ? 'ios_work_orders' : 'ios_buy_again'),
    const IosDashboardSection('ios_invoices', visible: false),
    const IosDashboardSection('ios_analytics', visible: false),
    const IosDashboardSection('ios_accounts', visible: false),
    const IosDashboardSection('ios_support', visible: false),
  ];

  static List<IosDashboardSection> normalise(
    bool supplier,
    List<IosDashboardSection>? saved,
  ) {
    final defaults = IosDashboardSection.defaults(supplier);
    final allowed = defaults.map((item) => item.id).toSet();
    final seen = <String>{};
    return [
      for (final item in saved ?? <IosDashboardSection>[])
        if (allowed.contains(item.id) && seen.add(item.id)) item,
      for (final item in defaults)
        if (seen.add(item.id)) item,
    ];
  }

  static String title(String id) =>
      const {
        'ios_categories': 'Animal categories',
        'ios_metrics': 'Order summary',
        'ios_attention': 'Needs your attention',
        'ios_recent': 'Recent orders',
        'ios_delivery': 'Next delivery or pickup',
        'ios_work_orders': 'Work orders shortcut',
        'ios_buy_again': 'Buy again',
        'ios_invoices': 'Invoices shortcut',
        'ios_analytics': 'Analytics shortcut',
        'ios_accounts': 'Accounts shortcut',
        'ios_support': 'Support shortcut',
      }[id] ??
      'Dashboard section';
}
