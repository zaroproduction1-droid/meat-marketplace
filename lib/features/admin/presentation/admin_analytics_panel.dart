import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/platform_admin_service.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

class AdminAnalyticsPanel extends StatefulWidget {
  const AdminAnalyticsPanel({
    super.key,
    required this.onNavigate,
    required this.onBusiness,
  });
  final ValueChanged<String> onNavigate, onBusiness;
  @override
  State<AdminAnalyticsPanel> createState() => _AdminAnalyticsPanelState();
}

class _AdminAnalyticsPanelState extends State<AdminAnalyticsPanel> {
  int _months = 6, _request = 0;
  bool _loading = true;
  String? _error;
  AdminRow _data = {};
  static const _green = Color(0xFF287D68), _blue = Color(0xFF547DA3);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await Supabase.instance.client.rpc(
        'platform_admin_analytics',
        params: {'p_months': _months},
      );
      if (mounted && request == _request) {
        setState(() {
          _data = PlatformAdminService.map(value);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = PlatformAdminService.error(e);
          _loading = false;
        });
      }
    }
  }

  String _month(dynamic value) {
    final d = DateTime.tryParse('$value');
    return d == null
        ? ''
        : '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year.toString().substring(2)}';
  }

  Widget _section(String title, String note, List<Widget> children) =>
      AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              note,
              style: const TextStyle(color: AdminTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      );
  Widget _legend(String text, Color colour) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: AdminTheme.muted, fontSize: 11)),
    ],
  );
  Widget _bar(
    double value,
    double maximum,
    Color colour, {
    bool money = true,
  }) => Row(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (_, c) => Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              width:
                  c.maxWidth *
                  (maximum <= 0 ? 0 : (value / maximum).clamp(0, 1)),
              height: 7,
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 96,
        child: Text(
          money ? PlatformAdminService.money(value) : value.toInt().toString(),
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 11, color: AdminTheme.ink),
        ),
      ),
    ],
  );
  Widget _chart(
    String title,
    String note,
    List<AdminRow> rows,
    String first,
    String second,
    String firstLabel,
    String secondLabel, {
    bool money = true,
  }) {
    var maximum = 0.0;
    for (final row in rows) {
      for (final k in [first, second]) {
        final n = PlatformAdminService.amount(row[k]);
        if (n > maximum) {
          maximum = n;
        }
      }
    }
    return _section(title, note, [
      Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [_legend(firstLabel, _blue), _legend(secondLabel, _green)],
      ),
      const SizedBox(height: 14),
      if (maximum == 0)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'No activity in this period.',
            style: TextStyle(color: AdminTheme.muted, fontSize: 12),
          ),
        ),
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            label:
                '${_month(row['month'])}: $firstLabel ${row[first]}, $secondLabel ${row[second]}',
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(
                    _month(row['month']),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminTheme.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _bar(
                        PlatformAdminService.amount(row[first]),
                        maximum,
                        _blue,
                        money: money,
                      ),
                      const SizedBox(height: 7),
                      _bar(
                        PlatformAdminService.amount(row[second]),
                        maximum,
                        _green,
                        money: money,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (_, c) => c.maxWidth < 850
        ? Column(children: [first, second])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 16),
              Expanded(child: second),
            ],
          ),
  );
  Widget _line(String label, dynamic value, {VoidCallback? onTap}) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(
      '$value',
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    ),
    onTap: onTap,
  );
  @override
  Widget build(BuildContext context) {
    final s = PlatformAdminService.map(_data['summary']);
    final businesses = PlatformAdminService.map(_data['businesses']);
    final support = PlatformAdminService.map(_data['support']);
    final subscriptions = PlatformAdminService.map(_data['subscriptions']);
    final ageing = PlatformAdminService.map(_data['ageing']);
    final overdue = PlatformAdminService.rows(_data['overdue_accounts']);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final count in [3, 6, 12])
                ChoiceChip(
                  label: Text('$count months'),
                  selected: _months == count,
                  onSelected: (_) {
                    _months = count;
                    _load();
                  },
                ),
              IconButton(
                onPressed: _load,
                tooltip: 'Refresh analytics',
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (_data.isNotEmpty)
                Text(
                  'Through ${PlatformAdminService.date(_data['through'])} · Sydney time',
                  style: const TextStyle(color: AdminTheme.muted, fontSize: 12),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const AdminLoading(label: 'Preparing platform analytics…')
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    AdminTileGrid(
                      children: [
                        AdminStatTile(
                          label: 'Configured monthly fees',
                          value: PlatformAdminService.money(
                            s['monthly_fees_ex_gst'],
                          ),
                          icon: Icons.autorenew_rounded,
                          note: 'Active plans · excluding GST',
                          onTap: () => widget.onNavigate('accounts'),
                        ),
                        AdminStatTile(
                          label: 'Invoices issued',
                          value: PlatformAdminService.money(
                            s['billed_inc_gst'],
                          ),
                          icon: Icons.receipt_long_outlined,
                          note: 'Selected period · including GST',
                          onTap: () => widget.onNavigate('invoices'),
                        ),
                        AdminStatTile(
                          label: 'Payments received',
                          value: PlatformAdminService.money(
                            s['received_inc_gst'],
                          ),
                          icon: Icons.payments_outlined,
                          note: 'By payment date · including GST',
                          onTap: () => widget.onNavigate('invoices'),
                        ),
                        AdminStatTile(
                          label: 'Outstanding balance',
                          value: PlatformAdminService.money(
                            s['outstanding_inc_gst'],
                          ),
                          icon: Icons.account_balance_wallet_outlined,
                          note: 'All open subscription invoices',
                          onTap: () => widget.onNavigate('accounts'),
                        ),
                        AdminStatTile(
                          label: 'Overdue balance',
                          value: PlatformAdminService.money(
                            s['overdue_inc_gst'],
                          ),
                          icon: Icons.schedule_rounded,
                          note: 'All overdue subscription invoices',
                          onTap: () => widget.onNavigate('invoices'),
                        ),
                        AdminStatTile(
                          label: 'New businesses',
                          value: '${s['new_businesses'] ?? 0}',
                          icon: Icons.add_business_outlined,
                          note: 'Registered during selected period',
                          onTap: () => widget.onNavigate('businesses'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _pair(
                      _chart(
                        'Subscription billing',
                        'Invoiced and received by month, including GST.',
                        PlatformAdminService.rows(_data['billing_trend']),
                        'billed',
                        'received',
                        'Invoiced',
                        'Received',
                      ),
                      _chart(
                        'Business growth',
                        'New supplier and butcher registrations.',
                        PlatformAdminService.rows(_data['growth']),
                        'suppliers',
                        'butchers',
                        'Suppliers',
                        'Butchers',
                        money: false,
                      ),
                    ),
                    _pair(
                      _section(
                        'Receivables ageing',
                        'Current outstanding balances, including GST.',
                        [
                          for (final item in {
                            'not_due': 'Not yet overdue',
                            'days_1_30': '1–30 days overdue',
                            'days_31_60': '31–60 days overdue',
                            'days_61_90': '61–90 days overdue',
                            'days_90_plus': 'Over 90 days',
                          }.entries)
                            _line(
                              item.value,
                              PlatformAdminService.money(ageing[item.key]),
                            ),
                        ],
                      ),
                      _section(
                        'Support workload',
                        'Current queues; period figures use the latest resolution date.',
                        [
                          _line(
                            'Waiting on CutLink',
                            support['waiting_on_admin'] ?? 0,
                            onTap: () => widget.onNavigate('support'),
                          ),
                          _line(
                            'Waiting on customer',
                            support['waiting_on_customer'] ?? 0,
                          ),
                          _line(
                            'Reopen requests',
                            support['reopen_requests'] ?? 0,
                          ),
                          _line(
                            'Created in selected period',
                            support['created_in_period'] ?? 0,
                          ),
                          _line(
                            'Resolved / closed in period',
                            support['resolved_in_period'] ?? 0,
                          ),
                        ],
                      ),
                    ),
                    _pair(
                      _section(
                        'Business overview',
                        'Current platform membership.',
                        [
                          _line('Suppliers', businesses['suppliers'] ?? 0),
                          _line('Butchers', businesses['butchers'] ?? 0),
                          _line(
                            'Awaiting approval',
                            businesses['pending'] ?? 0,
                          ),
                          _line(
                            'Suspended / inactive',
                            businesses['suspended'] ?? 0,
                          ),
                        ],
                      ),
                      _section(
                        'Subscription health',
                        'Current account status; not a historic churn calculation.',
                        [
                          for (final item in {
                            'active': 'Active subscriptions',
                            'trial': 'Trial accounts',
                            'paused': 'Paused accounts',
                            'cancelled': 'Cancelled subscriptions',
                          }.entries)
                            _line(item.value, subscriptions[item.key] ?? 0),
                          _line(
                            'Billing not configured',
                            s['unconfigured_businesses'] ?? 0,
                          ),
                        ],
                      ),
                    ),
                    _section(
                      'Accounts needing attention',
                      'Ten largest overdue subscription balances.',
                      [
                        if (overdue.isEmpty)
                          const Text(
                            'No overdue subscription balances.',
                            style: TextStyle(color: AdminTheme.muted),
                          ),
                        for (final account in overdue)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.business_outlined),
                            title: Text('${account['billing_name']}'),
                            subtitle: Text(
                              'Oldest due ${PlatformAdminService.date(account['oldest_due'])}',
                            ),
                            trailing: Text(
                              PlatformAdminService.money(account['overdue']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onTap: () =>
                                widget.onBusiness('${account['business_id']}'),
                          ),
                      ],
                    ),
                    const Text(
                      'CutLink subscriptions only. Voided invoices and reversed payment records are excluded. Received payments may relate to invoices issued outside the selected period.',
                      style: TextStyle(color: AdminTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
