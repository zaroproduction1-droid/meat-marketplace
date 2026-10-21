import 'product_photo_moderation_controls.dart';
import 'admin_billing_panel.dart';
import 'admin_theme.dart';
import '../../../shared/navigation/page_location.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/phone_layout.dart';
import '../services/platform_admin_service.dart';
import 'admin_widgets.dart';

class AdminBusinessPage extends StatefulWidget {
  const AdminBusinessPage({
    super.key,
    required this.businessId,
    this.initialTab = 'business',
    this.initialAccessReason,
  });
  final String businessId;
  final String initialTab;
  final String? initialAccessReason;
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
    final reason = widget.initialAccessReason?.trim();
    if (reason != null && reason.length >= 8 && reason.length <= 1000) {
      _tradeReason = reason;
    }
    _tab = ['billing', 'accounts', 'invoices'].contains(widget.initialTab)
        ? 'billing'
        : widget.initialTab == 'products' && _tradeReason != null
        ? 'products'
        : 'business';
    _load();
    // Direct links without report context must use the existing audited access flow.
    if (widget.initialTab == 'products' && _tradeReason == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectTab('products');
        }
      });
    }
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
      final business = await PlatformAdminService.query(
        'business',
        businessId: widget.businessId,
      );
      if (!mounted || request != _request) {
        return;
      }
      setState(() => _business = PlatformAdminService.map(business));
      final records = _tab != 'business' && _tab != 'billing'
          ? await PlatformAdminService.query(
              _tab,
              businessId: widget.businessId,
              search: _search,
              offset: _page * 50,
              accessReason: _tradeReason,
            )
          : null;
      if (mounted && request == _request) {
        setState(() {
          _rows = PlatformAdminService.rows(records);
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
          ? 'Approve access only, or start a membership after checking this is a real business. Founding starts the free offer; standard starts regular pricing. Restoring access never restarts an existing offer.'
          : 'This disables business access for active members. Their records and balances remain intact.',
      initial: const {'membership_review': 'review_later'},
      fields: [
        if (status == 'approved')
          const AdminField(
            'membership_review',
            'Membership review',
            required: true,
            optionLabels: {
              'review_later': 'Approve access — decide membership later',
              'genuine_founding': 'Approve & start founding membership',
              'genuine_standard': 'Approve & start standard membership',
              'development_business': 'Test business — no founding place',
            },
            options: [
              'review_later',
              'genuine_founding',
              'genuine_standard',
              'development_business',
            ],
          ),
        const AdminField(
          'reason',
          'Reason shown to the business (8–1000 characters for membership activation)',
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
            ProductPhotoModerationControls(
              key: ValueKey(r['id']),
              productId: r['id'].toString(),
              onChanged: _load,
            ),
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
                    'billing': 'Billing',
                    'orders': 'Orders',
                    'trade_invoices': 'Trade invoices',
                    if (_business['business_type'] == 'supplier')
                      'products': 'Inventory',
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
            if (_tab != 'business' && _tab != 'billing' && _tab != 'audit')
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
                  ? BillingError(message: _error!, onRetry: _load)
                  : _tab == 'billing'
                  ? AdminBusinessBilling(
                      key: ValueKey(_request),
                      business: _business,
                      onReviewAccess: () => _status('approved'),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_tab == 'business')
                          _profile()
                        else ...[
                          if (_rows.isEmpty)
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
