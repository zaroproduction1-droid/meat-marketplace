import 'admin_theme.dart';
import '../../../shared/navigation/page_location.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/phone_layout.dart';
import '../services/platform_admin_service.dart';
import 'admin_widgets.dart';
import 'platform_invoice_page.dart';

class AdminBusinessPage extends StatefulWidget {
  const AdminBusinessPage({
    super.key,
    required this.businessId,
    this.initialTab = 'business',
  });
  final String businessId;
  final String initialTab;
  @override
  State<AdminBusinessPage> createState() => _AdminBusinessPageState();
}

class _AdminBusinessPageState extends State<AdminBusinessPage> {
  AdminRow _business = {};
  List<AdminRow> _rows = [];
  String _tab = 'business', _search = '';
  String? _error;
  String? _tradeReason;
  bool _loading = true;
  int _page = 0, _request = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _tab = ['accounts', 'invoices'].contains(widget.initialTab)
        ? widget.initialTab
        : 'business';
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
    try {
      final results = await Future.wait([
        PlatformAdminService.query('business', businessId: widget.businessId),
        if (_tab != 'business')
          PlatformAdminService.query(
            _tab,
            businessId: widget.businessId,
            search: _search,
            offset: _page * 50,
            accessReason: _tradeReason,
          ),
      ]);
      if (mounted && request == _request) {
        setState(() {
          _business = PlatformAdminService.map(results.first);
          _rows = results.length > 1
              ? PlatformAdminService.rows(results.last)
              : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = PlatformAdminService.error(e);
        });
      }
    }
  }

  Future<void> _selectTab(String tab) async {
    if (['orders', 'trade_invoices', 'products'].contains(tab) &&
        _tradeReason == null) {
      final entered = await adminForm(
        context,
        title: 'Access business trade records',
        explanation:
            'Use these records only for authorised support, security or platform operations. Access is read-only and recorded in the admin audit history.',
        fields: const [
          AdminField(
            'reason',
            'Reason or support ticket reference',
            required: true,
            lines: 3,
          ),
        ],
        submitLabel: 'Open records',
        submit: (data) async {
          final reason = data['reason'].toString().trim();
          if (reason.length < 8 || reason.length > 1000) {
            throw ArgumentError('Enter a specific reason (8–1000 characters).');
          }
          _tradeReason = reason;
        },
      );
      if (!entered || !mounted) {
        return;
      }
    }
    _debounce?.cancel();
    setState(() {
      _tab = tab;
      _page = 0;
      _search = '';
    });
    await _load();
  }

  Future<void> _status(String status) async {
    final changed = await adminForm(
      context,
      title:
          '${status == 'approved'
              ? 'Approve / restore'
              : status == 'suspended'
              ? 'Suspend'
              : 'Reject'} business',
      explanation: status == 'approved'
          ? 'Previously suspended memberships will be restored. This does not alter the subscription balance.'
          : 'This disables business access for active members. Their records and balances remain intact.',
      fields: const [
        AdminField(
          'reason',
          'Reason shown to the business',
          required: true,
          lines: 3,
        ),
      ],
      submitLabel: 'Confirm',
      submit: (d) async {
        await PlatformAdminService.action('business_status', {
          ...d,
          'business_id': widget.businessId,
          'status': status,
        });
      },
    );
    if (changed && mounted) {
      await _load();
    }
  }

  Future<void> _edit() async {
    final changed = await adminForm(
      context,
      title: 'Edit business profile',
      initial: _business,
      explanation:
          'Updates the business directory profile. Existing invoice snapshots remain unchanged.',
      fields: const [
        AdminField('legal_name', 'Legal business name', required: true),
        AdminField('trading_name', 'Trading name'),
        AdminField('business_email', 'Business email'),
        AdminField('business_phone', 'Business phone'),
      ],
      submit: (d) async {
        await PlatformAdminService.action('save_business', {
          ...d,
          'business_id': widget.businessId,
        });
      },
    );
    if (changed && mounted) {
      await _load();
    }
  }

  Future<void> _member(AdminRow member) async {
    final changed = await adminForm(
      context,
      title: 'Member access',
      initial: member,
      fields: const [
        AdminField(
          'role',
          'Role',
          required: true,
          options: ['owner', 'manager', 'staff', 'viewer'],
        ),
        AdminField(
          'status',
          'Access',
          required: true,
          options: ['active', 'suspended'],
        ),
        AdminField(
          'reason',
          'Reason shown to this member',
          required: true,
          lines: 2,
        ),
      ],
      submit: (d) async {
        await PlatformAdminService.action('member_access', {
          ...d,
          'id': member['id'],
          'business_id': widget.businessId,
        });
      },
    );
    if (changed && mounted) {
      await _load();
    }
  }

  Future<void> _account(AdminRow account) async {
    if (await editSubscriptionAccount(context, _business, account) && mounted) {
      await _load();
    }
  }

  Future<void> _tradeInvoice(AdminRow row) async {
    try {
      final invoice = PlatformAdminService.map(
        await PlatformAdminService.query(
          'trade_invoice',
          businessId: widget.businessId,
          id: '${row['id']}',
          accessReason: _tradeReason,
        ),
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${invoice['invoice_number']}'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${invoice['customer_name_snapshot'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total ${PlatformAdminService.money(invoice['total_amount'])} · Outstanding ${PlatformAdminService.money(invoice['outstanding_amount'])}',
                  ),
                  Text(
                    'Paid ${PlatformAdminService.money(invoice['amount_paid'])} · Credit applied ${PlatformAdminService.money(invoice['credit_applied'])}',
                  ),
                  const Divider(),
                  for (final item in PlatformAdminService.rows(
                    invoice['items'],
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${item['product_name_snapshot'] ?? item['product_name'] ?? item['description'] ?? item['sku_snapshot'] ?? 'Invoice item'}\n${item['public_comment'] ?? ''}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(PlatformAdminService.error(e))));
      }
    }
  }

  Widget _profile() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                AdminStatus('${_business['verification_status']}'),
                AdminStatus(
                  _business['active'] == true ? 'active' : 'inactive',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_business['legal_name'] ?? ''}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            if ('${_business['business_email'] ?? ''}'.isNotEmpty)
              SelectableText('${_business['business_email']}'),
            if ('${_business['business_phone'] ?? ''}'.isNotEmpty)
              SelectableText('${_business['business_phone']}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _edit,
                  child: const Text('Edit profile'),
                ),
                if (_business['verification_status'] != 'approved' ||
                    _business['active'] != true)
                  FilledButton(
                    onPressed: () => _status('approved'),
                    child: const Text('Approve / restore'),
                  ),
                if (_business['active'] == true)
                  OutlinedButton(
                    onPressed: () => _status('suspended'),
                    child: const Text('Suspend access'),
                  ),
                if (_business['verification_status'] == 'pending')
                  TextButton(
                    onPressed: () => _status('rejected'),
                    child: const Text('Reject application'),
                  ),
              ],
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'Business members',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      for (final member in PlatformAdminService.rows(_business['members']))
        AdminCard(
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${member['name']}'.trim().isEmpty
                    ? 'Business member'
                    : '${member['name']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('${member['role']}'),
              AdminStatus('${member['status']}'),
              if (member['is_admin'] != true)
                TextButton(
                  onPressed: () => _member(member),
                  child: const Text('Manage access'),
                )
              else
                const Text('CutLink administrator'),
            ],
          ),
        ),
    ],
  );
  Widget _row(AdminRow r) {
    if (_tab == 'accounts') {
      return AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r['plan_name']} · ${PlatformAdminService.money(r['monthly_fee'])} / month',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Account CL-${r['account_number']} · ${r['status']}\nOutstanding ${PlatformAdminService.money(r['outstanding'])} · Overdue ${PlatformAdminService.money(r['overdue'])}\nNext billing ${PlatformAdminService.date(r['next_billing_date'])}',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _account(r),
                  child: const Text('Edit account'),
                ),
                FilledButton(
                  onPressed: () async {
                    await createSubscriptionInvoice(context, r);
                    if (mounted) {
                      await _load();
                    }
                  },
                  child: const Text('Generate invoice'),
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
            '${r['invoice_number']} · ${PlatformAdminService.money(r['total_amount'])}',
          ),
          subtitle: Text(
            '${r['status']} · Due ${PlatformAdminService.date(r['due_date'])}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PlatformInvoicePage(invoiceId: '${r['id']}'),
              ),
            );
            if (mounted) {
              await _load();
            }
          },
        ),
      );
    }
    if (_tab == 'trade_invoices') {
      return AdminCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${r['invoice_number']} · ${PlatformAdminService.money(r['total_amount'])}',
          ),
          subtitle: Text(
            '${r['customer_name_snapshot'] ?? ''}\n${r['status']} · Outstanding ${PlatformAdminService.money(r['outstanding_amount'])}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _tradeInvoice(r),
        ),
      );
    }
    if (_tab == 'products') {
      return AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r['product_name']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'SKU ${r['sku'] ?? ''} · ${r['available_quantity']} ${r['quantity_unit']}',
            ),
            AdminStatus(r['active'] == true ? 'active' : 'inactive'),
          ],
        ),
      );
    }
    if (_tab == 'audit') {
      return AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r['action']}'.replaceAll('_', ' '),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${r['actor']} · ${PlatformAdminService.date(r['created_at'])}',
            ),
            if (PlatformAdminService.map(r['details'])['reason'] != null)
              Text('${PlatformAdminService.map(r['details'])['reason']}'),
          ],
        ),
      );
    }
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r['order_number']}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(PlatformAdminService.date(r['created_at'])),
          AdminStatus('${r['status']}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PageLocation.track(context, {
      'page': 'admin_business',
      'id': widget.businessId,
    });
    return AdminTheme(
      child: Scaffold(
        appBar: phoneAppBar(
          context,
          AppBar(
            title: Text(
              _business.isEmpty
                  ? 'Business workspace'
                  : PlatformAdminService.name(_business),
            ),
            actions: [
              IconButton(
                onPressed: _load,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                runSpacing: 6,
                children: [
                  for (final entry in {
                    'business': 'Profile & access',
                    'orders': 'Orders',
                    'trade_invoices': 'Trade invoices',
                    if (_business['business_type'] == 'supplier')
                      'products': 'Inventory',
                    'accounts': 'Subscription account',
                    'invoices': 'Subscription invoices',
                    'audit': 'Audit',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _tab == entry.key,
                        onSelected: (_) => _selectTab(entry.key),
                      ),
                    ),
                ],
              ),
            ),
            if (_tab != 'business' && _tab != 'accounts' && _tab != 'audit')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: ValueKey(_tab),
                  decoration: const InputDecoration(
                    labelText: 'Search this business',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _search = v;
                    _debounce = Timer(const Duration(milliseconds: 350), () {
                      _page = 0;
                      _load();
                    });
                  },
                ),
              ),
            Expanded(
              child: _loading
                  ? const AdminLoading()
                  : _error != null
                  ? Center(child: Text(_error!))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_tab == 'business')
                          _profile()
                        else ...[
                          if (_tab == 'accounts' && _rows.isEmpty)
                            AdminCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'No subscription account configured.',
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () => _account({}),
                                    child: const Text(
                                      'Set up subscription account',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_rows.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('No records found.'),
                            ),
                          for (final row in _rows.take(50)) _row(row),
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
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
