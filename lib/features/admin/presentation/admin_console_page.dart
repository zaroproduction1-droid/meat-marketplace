import 'admin_analytics_panel.dart';
import 'admin_theme.dart';
import '../../../shared/navigation/page_location.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';
import '../../../shared/widgets/phone_layout.dart';
import '../../../shared/widgets/workspace_back_button.dart';
import '../../support/presentation/support_center_page.dart';
import '../services/platform_admin_service.dart';
import 'admin_widgets.dart';
import 'admin_business_page.dart';
import 'admin_announcement_page.dart';
import 'platform_invoice_page.dart';

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({super.key, this.initialTab = 'overview'});
  final String initialTab;
  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  String _tab = 'overview', _search = '';
  String? _filter;
  bool _loading = true;
  String? _error;
  int _page = 0, _request = 0;
  Timer? _debounce;
  AdminRow _data = {};
  List<AdminRow> _rows = [];
  static const _tabs = {
    'overview': 'Overview',
    'analytics': 'Analytics',
    'businesses': 'Businesses',
    'accounts': 'Subscription accounts',
    'invoices': 'Invoices',
    'announcements': 'Announcements',
    'audit': 'Audit history',
    'settings': 'Billing settings',
    'support': 'Support inbox',
  };
  @override
  void initState() {
    super.initState();
    _tab = _tabs.containsKey(widget.initialTab)
        ? widget.initialTab
        : 'overview';
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (_tab == 'analytics') {
      setState(() => _loading = false);
      return;
    }
    try {
      final value = await PlatformAdminService.query(
        _tab,
        search: _search,
        filter: _filter,
        offset: _page * 50,
      );
      if (mounted && request == _request) {
        setState(() {
          _data = PlatformAdminService.map(value);
          _rows = PlatformAdminService.rows(value);
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

  void _change(String tab) {
    if (tab == 'support') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              const SupportCenterPage(businessId: '', adminMode: true),
        ),
      );
      return;
    }
    _debounce?.cancel();
    setState(() {
      _tab = tab;
      _page = 0;
      _search = '';
      _filter = null;
    });
    _load();
  }

  Future<void> _business(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminBusinessPage(businessId: id),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _editAccount(AdminRow account) async {
    if (await editSubscriptionAccount(context, {
          'id': account['business_id'],
        }, account) &&
        mounted) {
      await _load();
    }
  }

  Future<void> _invoice(AdminRow row) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlatformInvoicePage(invoiceId: '${row['id']}'),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _announcement() async {
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(builder: (_) => const AdminAnnouncementPage()),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _archive(AdminRow row) async {
    final saved = await adminForm(
      context,
      title: 'Archive announcement',
      explanation:
          'The banner will be removed. Notifications already delivered remain in their inboxes.',
      fields: const [AdminField('reason', 'Reason', required: true)],
      submitLabel: 'Archive',
      submit: (d) async {
        await PlatformAdminService.action('archive_announcement', {
          ...d,
          'id': row['id'],
        });
      },
    );
    if (saved && mounted) {
      await _load();
    }
  }

  Future<void> _settings() async {
    final initial = {
      ..._data,
      'gst_registered': '${_data['gst_registered'] ?? false}',
    };
    final saved = await adminForm(
      context,
      title: 'CutLink billing details',
      explanation:
          'These details are saved on each new invoice. Changes do not rewrite previously issued invoices.',
      initial: initial,
      fields: const [
        AdminField(
          'legal_name',
          'CutLink legal / trading entity',
          required: true,
        ),
        AdminField('abn', 'ABN'),
        AdminField('email', 'Billing email', required: true),
        AdminField('phone', 'Phone'),
        AdminField('address', 'Business address', lines: 2),
        AdminField(
          'gst_registered',
          'Registered for GST',
          required: true,
          options: ['false', 'true'],
        ),
        AdminField('bank_name', 'Bank'),
        AdminField('account_name', 'Bank account name'),
        AdminField('bsb', 'BSB'),
        AdminField('account_number', 'Bank account number'),
        AdminField('payment_instructions', 'Payment instructions', lines: 3),
      ],
      submit: (d) async {
        await PlatformAdminService.action('save_settings', {
          'details': {...d, 'gst_registered': d['gst_registered'] == 'true'},
        });
      },
    );
    if (saved && mounted) {
      await _load();
    }
  }

  Widget _metric(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) => AdminStatTile(label: label, value: value, icon: icon, onTap: onTap);
  Widget _overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const CutLinkSectionHeading(
        title: 'CutLink control centre',
        subtitle:
            'Business access, platform billing and customer communications.',
        icon: Icons.admin_panel_settings_outlined,
      ),
      const SizedBox(height: 20),
      AdminTileGrid(
        children: [
          _metric(
            'Businesses',
            '${_data['businesses'] ?? 0}',
            Icons.business_outlined,
            onTap: () => _change('businesses'),
          ),
          _metric(
            'Awaiting approval',
            '${_data['pending'] ?? 0}',
            Icons.how_to_reg_outlined,
            onTap: () => _change('businesses'),
          ),
          _metric(
            'Subscription balance',
            PlatformAdminService.money(_data['outstanding']),
            Icons.account_balance_wallet_outlined,
            onTap: () => _change('accounts'),
          ),
          _metric(
            'Overdue subscriptions',
            PlatformAdminService.money(_data['overdue']),
            Icons.schedule_outlined,
            onTap: () => _change('invoices'),
          ),
          _metric(
            'Payments received',
            PlatformAdminService.money(_data['paid']),
            Icons.payments_outlined,
            onTap: () => _change('invoices'),
          ),
          _metric(
            'Accounts due to bill',
            '${_data['due_accounts'] ?? 0}',
            Icons.receipt_long_outlined,
            onTap: () => _change('accounts'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_data['suppliers'] ?? 0} suppliers · ${_data['butchers'] ?? 0} butchers',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Open a business to manage access, review its trading activity and configure its monthly subscription. Subscription payments and supplier trade invoices are accounted for separately.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _change('businesses'),
                  icon: const Icon(Icons.business),
                  label: const Text('Manage businesses'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _change('settings'),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Billing setup'),
                ),
                OutlinedButton.icon(
                  onPressed: _announcement,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('New announcement'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
  Widget _settingsView() => AdminCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CutLinkSectionHeading(
          title: 'CutLink billing profile',
          subtitle:
              'Issuer identity and payment instructions for subscription invoices.',
          icon: Icons.business_outlined,
        ),
        const SizedBox(height: 16),
        if (_data.isEmpty)
          const Text(
            'Set up your billing identity before generating the first subscription invoice.',
          ),
        for (final field in {
          'legal_name': 'Legal entity',
          'abn': 'ABN',
          'email': 'Email',
          'phone': 'Phone',
          'address': 'Address',
          'bank_name': 'Bank',
          'account_name': 'Account name',
          'bsb': 'BSB',
          'account_number': 'Account number',
          'payment_instructions': 'Payment instructions',
        }.entries)
          if ('${_data[field.key] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SelectableText('${field.value}: ${_data[field.key]}'),
            ),
        Text(
          'GST: ${_data['gst_registered'] == true ? 'Registered' : 'Not enabled'}',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _settings,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit billing details'),
        ),
      ],
    ),
  );
  Widget _row(AdminRow row) {
    if (_tab == 'businesses') {
      return AdminCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            PlatformAdminService.name(row),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${row['business_type']} · ${row['business_email'] ?? ''}'),
              const SizedBox(height: 8),
              AdminStatus('${row['verification_status']}'),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _business('${row['id']}'),
        ),
      );
    }
    if (_tab == 'accounts') {
      return AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['billing_name']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'CL-${row['account_number']} · ${row['plan_name']} · ${PlatformAdminService.money(row['monthly_fee'])} / month, excl. GST',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                AdminStatus('${row['status']}'),
                Text(
                  'Outstanding ${PlatformAdminService.money(row['outstanding'])}',
                ),
                Text('Overdue ${PlatformAdminService.money(row['overdue'])}'),
                Text(
                  'Next bill ${PlatformAdminService.date(row['next_billing_date'])}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    await createSubscriptionInvoice(context, row);
                    if (mounted) {
                      await _load();
                    }
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Generate invoice'),
                ),
                OutlinedButton(
                  onPressed: () => _editAccount(row),
                  child: const Text('Edit subscription'),
                ),
                TextButton(
                  onPressed: () => _business('${row['business_id']}'),
                  child: const Text('Open business'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (_tab == 'invoices') {
      return AdminCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${row['invoice_number']} · ${row['billing_name']}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total ${PlatformAdminService.money(row['total_amount'])} · Paid ${PlatformAdminService.money(row['amount_paid'])}\nBalance ${PlatformAdminService.money(row['outstanding'])} · Due ${PlatformAdminService.date(row['due_date'])}',
              ),
              const SizedBox(height: 8),
              AdminStatus('${row['status']}'),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _invoice(row),
        ),
      );
    }
    if (_tab == 'announcements') {
      final expired =
          DateTime.tryParse('${row['expires_at']}')?.isBefore(DateTime.now()) ??
          false;
      return AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['title']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('${row['body']}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                AdminStatus(
                  row['archived_at'] != null
                      ? 'archived'
                      : expired
                      ? 'expired'
                      : 'published',
                ),
                Text(
                  '${row['audience']} · ${row['channel']} · ${PlatformAdminService.date(row['created_at'])}',
                ),
              ],
            ),
            if (row['archived_at'] == null)
              TextButton.icon(
                onPressed: () => _archive(row),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive'),
              ),
          ],
        ),
      );
    }
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${row['action']}'.replaceAll('_', ' '),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${row['actor']} · ${PlatformAdminService.date(row['created_at'])}',
          ),
          if (row['business'] != null) Text('${row['business']}'),
          if (PlatformAdminService.map(row['details'])['reason'] != null)
            Text('${PlatformAdminService.map(row['details'])['reason']}'),
        ],
      ),
    );
  }

  static const _subtitles = {
    'overview': 'Your platform at a glance.',
    'analytics':
        'Subscription performance, business growth and support activity.',
    'businesses': 'Manage suppliers, butchers and account access.',
    'accounts': 'Monthly plans, billing contacts and account balances.',
    'invoices': 'Review subscription invoices and record received payments.',
    'announcements': 'Keep the right businesses informed.',
    'audit': 'A traceable history of administrative actions and trade access.',
    'settings': 'Your billing identity and payment instructions.',
  };
  Widget _filters() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: Column(
      children: [
        TextField(
          key: ValueKey(_tab),
          decoration: InputDecoration(
            labelText: _tab == 'invoices'
                ? 'Search invoice number or business'
                : 'Search business or billing email',
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: (v) {
            _search = v;
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () {
              _page = 0;
              _load();
            });
          },
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in <String?>[
                null,
                ...(_tab == 'businesses'
                    ? [
                        'supplier',
                        'butcher',
                        'pending',
                        'approved',
                        'suspended',
                        'rejected',
                      ]
                    : _tab == 'accounts'
                    ? [
                        'active',
                        'trial',
                        'paused',
                        'cancelled',
                        'unpaid',
                        'overdue',
                      ]
                    : ['unpaid', 'part_paid', 'paid', 'overdue', 'void']),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(
                      option == null ? 'All' : option.replaceAll('_', ' '),
                    ),
                    selected: _filter == option,
                    onSelected: (_) {
                      setState(() {
                        _filter = option;
                        _page = 0;
                      });
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _records() => _loading
      ? const AdminLoading()
      : _error != null
      ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 34,
                  color: AdminTheme.muted,
                ),
                const SizedBox(height: 14),
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        )
      : ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (_tab == 'overview')
              _overview()
            else if (_tab == 'settings')
              _settingsView()
            else ...[
              if (_rows.isEmpty)
                AdminCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(
                          AdminNavigation.icon(_tab),
                          size: 38,
                          color: AdminTheme.muted,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Nothing to show yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _search.isNotEmpty || _filter != null
                              ? 'Try changing your search or filter.'
                              : 'New records will appear here.',
                          style: const TextStyle(color: AdminTheme.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final row in _rows.take(50)) _row(row),
              if (_rows.isNotEmpty || _page > 0)
                AdminPager(
                  page: _page,
                  more: _rows.length > 50,
                  onPage: (v) {
                    _page = v;
                    _load();
                  },
                ),
            ],
          ],
        );
  @override
  Widget build(BuildContext context) {
    if (ModalRoute.of(context)?.isCurrent == true) {
      PageLocation.workspace({'page': 'admin', 'tab': _tab});
    }
    return AdminTheme(
      child: Scaffold(
        appBar: phoneAppBar(
          context,
          AppBar(
            leading: const WorkspaceBackButton(),
            title: const Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, size: 22),
                SizedBox(width: 10),
                Text('CutLink Admin'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Support inbox',
                onPressed: () => _change('support'),
                icon: const Icon(Icons.support_agent),
              ),
              if (_tab != 'analytics')
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
        ),
        body: AdminNavigation(
          items: _tabs,
          value: _tab,
          onChanged: _change,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tabs[_tab] ?? 'Admin',
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _subtitles[_tab] ?? '',
                              style: const TextStyle(
                                color: AdminTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (_tab == 'announcements')
                          FilledButton.icon(
                            onPressed: _announcement,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New announcement'),
                          ),
                        if (_tab == 'accounts')
                          FilledButton.icon(
                            onPressed: () => _change('businesses'),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Set up account'),
                          ),
                      ],
                    ),
                  ),
                  if (['businesses', 'accounts', 'invoices'].contains(_tab))
                    _filters(),
                  Expanded(
                    child: _tab == 'analytics'
                        ? AdminAnalyticsPanel(
                            onNavigate: _change,
                            onBusiness: _business,
                          )
                        : _records(),
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
