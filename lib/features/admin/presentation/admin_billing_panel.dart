import '../../../shared/widgets/ios_density.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../memberships/services/membership_service.dart';
import '../services/admin_billing_labels.dart';
import '../services/platform_admin_service.dart';
import 'admin_business_page.dart';
import 'admin_membership_actions.dart';
import 'admin_memberships_panel.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';
import 'platform_invoice_page.dart';

class AdminBillingPanel extends StatefulWidget {
  const AdminBillingPanel({
    super.key,
    this.initialView = 'accounts',
    this.initialFilter,
    this.onViewChanged,
  });
  final String initialView;
  final String? initialFilter;
  final ValueChanged<String>? onViewChanged;
  @override
  State<AdminBillingPanel> createState() => _AdminBillingPanelState();
}

class _AdminBillingPanelState extends State<AdminBillingPanel> {
  late String _view;
  String? _filter;
  String _search = '';
  int _page = 0, _request = 0;
  bool _loading = true;
  String? _error;
  List<AdminRow> _rows = [];
  AdminRow _details = {};
  Timer? _debounce;
  final _searchController = TextEditingController();
  static const _views = {
    'accounts': 'Accounts',
    'invoices': 'Invoices',
    'pricing': 'Pricing',
    'settings': 'Invoice details',
  };
  @override
  void initState() {
    super.initState();
    _view = _views.containsKey(widget.initialView)
        ? widget.initialView
        : 'accounts';
    _filter = widget.initialFilter;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (_view == 'pricing') {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await PlatformAdminService.query(
        _view,
        search: _search,
        filter: _filter,
        offset: _page * 50,
      );
      if (mounted && request == _request) {
        setState(() {
          _rows = PlatformAdminService.rows(data);
          _details = PlatformAdminService.map(data);
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = PlatformAdminService.error(error);
          _loading = false;
        });
      }
    }
  }

  void _select(String view, {String? filter}) {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _view = view;
      _filter = filter;
      _search = '';
      _page = 0;
    });
    widget.onViewChanged?.call(view);
    _load();
  }

  Future<void> _openBusiness(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AdminBusinessPage(businessId: id, initialTab: 'billing'),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _chooseBusiness() async {
    final id = await showDialog<String>(
      context: context,
      builder: (_) => const _BillingBusinessPicker(),
    );
    if (id != null && mounted) {
      await _openBusiness(id);
    }
  }

  Future<void> _invoice(AdminRow invoice) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlatformInvoicePage(invoiceId: '${invoice['id']}'),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Widget _settings() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your CutLink invoice details',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const IosGap(height: 8),
            const Text(
              'Set this up once. These details appear on invoices you send to businesses.',
            ),
            const IosGap(height: 16),
            if ('${_details['legal_name'] ?? ''}'.isEmpty ||
                '${_details['email'] ?? ''}'.isEmpty)
              const Text(
                'Business name and billing email still need to be added.',
                style: TextStyle(
                  color: AdminTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            for (final field in {
              'legal_name': 'Business name',
              'abn': 'ABN',
              'email': 'Billing email',
              'address': 'Address',
            }.entries)
              if ('${_details[field.key] ?? ''}'.isNotEmpty)
                IosPadding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(
                    '${field.value}: ${_details[field.key]}',
                  ),
                ),
            IosPadding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _details['gst_registered'] == true
                    ? 'GST registered'
                    : 'Not GST registered',
              ),
            ),
            ExpansionTile(
              title: const Text('Bank & payment instructions'),
              tilePadding: EdgeInsets.zero,
              children: [
                for (final field in {
                  'bank_name': 'Bank',
                  'account_name': 'Account name',
                  'bsb': 'BSB',
                  'account_number': 'Account number',
                  'payment_instructions': 'Instructions',
                }.entries)
                  ListTile(
                    title: Text(field.value),
                    subtitle: SelectableText(
                      '${_details[field.key] ?? 'Not added'}',
                    ),
                  ),
              ],
            ),
            const IosGap(height: 12),
            FilledButton.icon(
              onPressed: () async {
                if (await editCutLinkInvoiceDetails(
                      context,
                      current: _details,
                    ) &&
                    mounted) {
                  await _load();
                }
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit invoice details'),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * .55),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IosPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final view in _views.entries)
                        ChoiceChip(
                          label: Text(view.value),
                          selected: _view == view.key,
                          onSelected: (_) => _select(view.key),
                        ),
                    ],
                  ),
                ),
                if (['accounts', 'invoices'].contains(_view)) ...[
                  IosPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (_view == 'accounts')
                          FilledButton.icon(
                            onPressed: _chooseBusiness,
                            icon: const Icon(Icons.add),
                            label: const Text('Set up business billing'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _select('accounts', filter: 'needs_invoice'),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Ready to invoice'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _select('invoices', filter: 'overdue'),
                          icon: const Icon(Icons.schedule),
                          label: const Text('Overdue payments'),
                        ),
                      ],
                    ),
                  ),
                  IosPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: _view == 'accounts'
                            ? 'Find a billing account'
                            : 'Find an invoice or business',
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        _search = value;
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 350),
                          () {
                            _page = 0;
                            _load();
                          },
                        );
                      },
                    ),
                  ),
                  IosPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final filter
                            in (_view == 'accounts'
                                    ? <String?, String>{
                                        null: 'All',
                                        'needs_invoice': 'Ready to invoice',
                                        'unpaid': 'Unpaid balance',
                                        'overdue': 'Overdue',
                                        'paused': 'Paused',
                                        'on_hold': 'Access on hold',
                                      }
                                    : <String?, String>{
                                        null: 'All',
                                        'unpaid': 'Unpaid',
                                        'paid': 'Paid',
                                        'overdue': 'Overdue',
                                        'part_paid': 'Part paid',
                                        'void': 'Voided',
                                      })
                                .entries)
                          ChoiceChip(
                            label: Text(filter.value),
                            selected: _filter == filter.key,
                            onSelected: (_) {
                              setState(() {
                                _filter = filter.key;
                                _page = 0;
                              });
                              _load();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: _view == 'pricing'
              ? AdminMembershipsPanel(key: ValueKey(_request))
              : _loading
              ? const AdminLoading()
              : _error != null
              ? BillingError(message: _error!, onRetry: _load)
              : _view == 'settings'
              ? _settings()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (_rows.isEmpty)
                      AdminCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _view == 'accounts'
                                  ? 'No matching billing accounts'
                                  : 'No matching invoices',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const IosGap(height: 8),
                            Text(
                              _view == 'accounts'
                                  ? 'Choose a business to start membership or review its billing.'
                                  : 'Invoices appear here after you create them from an account.',
                            ),
                            if (_view == 'accounts')
                              TextButton(
                                onPressed: _chooseBusiness,
                                child: const Text('Choose a business'),
                              ),
                          ],
                        ),
                      ),
                    for (final row in _rows.take(50))
                      if (_view == 'accounts')
                        BillingAccountCard(
                          account: row,
                          onOpen: () => _openBusiness('${row['business_id']}'),
                          onInvoice: () async {
                            await createSubscriptionInvoice(context, row);
                            if (mounted) {
                              await _load();
                            }
                          },
                        )
                      else
                        BillingInvoiceTile(
                          invoice: row,
                          onTap: () => _invoice(row),
                        ),
                    if (_rows.isNotEmpty || _page > 0)
                      AdminPager(
                        page: _page,
                        more: _rows.length > 50,
                        onPage: (page) {
                          _page = page;
                          _load();
                        },
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}

class BillingAccountCard extends StatelessWidget {
  const BillingAccountCard({
    super.key,
    required this.account,
    this.onOpen,
    this.onInvoice,
    this.onEdit,
  });
  final AdminRow account;
  final VoidCallback? onOpen, onInvoice, onEdit;
  @override
  Widget build(BuildContext context) {
    final membership = MembershipService.map(account['membership']);
    final active = ['active', 'trial'].contains(account['status']);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${account['billing_name'] ?? 'Business'}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const IosGap(height: 6),
          Text(
            'CL-${account['account_number']} · ${adminOfferLabel(membership)}',
          ),
          const IosGap(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              BillingValue(
                label: active ? 'Monthly price now' : 'Billing',
                value: active
                    ? '${PlatformAdminService.money(membership['effective_total'] ?? account['monthly_fee'])}${account['fee_gst_inclusive'] == true ? '' : ' + GST if registered'}'
                    : '${account['status']}'.replaceAll('_', ' '),
              ),
              BillingValue(
                label: 'Unpaid balance',
                value: PlatformAdminService.money(account['outstanding']),
              ),
              BillingValue(
                label: 'Next invoice starts',
                value: PlatformAdminService.date(account['next_billing_date']),
              ),
            ],
          ),
          if (membership['stage'] == 'free_founding')
            IosPadding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Free until ${PlatformAdminService.date(membership['free_end'])}. Your next invoice uses the price for its billing period.',
              ),
            ),
          if (membership['stage'] == 'founding_half_price')
            IosPadding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Half-price until ${PlatformAdminService.date(membership['discount_end'])}.',
              ),
            ),
          if (PlatformAdminService.amount(account['overdue']) > 0)
            IosPadding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '${PlatformAdminService.money(account['overdue'])} overdue',
                style: const TextStyle(
                  color: AdminTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const IosGap(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (onOpen != null)
                OutlinedButton(
                  onPressed: onOpen,
                  child: const Text('Open billing'),
                ),
              if (onInvoice != null)
                FilledButton.icon(
                  onPressed: active ? onInvoice : null,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Create invoice'),
                ),
              if (onEdit != null)
                OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('Edit billing details'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class BillingValue extends StatelessWidget {
  const BillingValue({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(color: AdminTheme.muted, fontSize: 12),
      ),
      const IosGap(height: 4),
      Text(
        value.isEmpty ? 'Not set' : value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class BillingInvoiceTile extends StatelessWidget {
  const BillingInvoiceTile({
    super.key,
    required this.invoice,
    required this.onTap,
  });
  final AdminRow invoice;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AdminCard(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${invoice['invoice_number']} · ${PlatformAdminService.money(invoice['total_amount'])}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${invoice['billing_name'] ?? ''}\n${invoice['status']} · Unpaid ${PlatformAdminService.money(invoice['outstanding'])} · Due ${PlatformAdminService.date(invoice['due_date'])}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class BillingError extends StatelessWidget {
  const BillingError({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: IosPadding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class AdminBusinessBilling extends StatefulWidget {
  const AdminBusinessBilling({
    super.key,
    required this.business,
    this.onReviewAccess,
  });
  final AdminRow business;
  final Future<void> Function()? onReviewAccess;
  @override
  State<AdminBusinessBilling> createState() => _AdminBusinessBillingState();
}

class _AdminBusinessBillingState extends State<AdminBusinessBilling> {
  AdminRow _account = {}, _membership = {};
  List<AdminRow> _invoices = [];
  bool _loading = true;
  String? _error;
  int _page = 0, _request = 0;
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
      final id = '${widget.business['id']}';
      final results = await Future.wait([
        PlatformAdminService.query('accounts', businessId: id),
        MembershipService.mine(id),
        PlatformAdminService.query(
          'invoices',
          businessId: id,
          offset: _page * 50,
        ),
      ]);
      if (mounted && request == _request) {
        setState(() {
          final accounts = PlatformAdminService.rows(results[0]);
          _account = accounts.isEmpty ? {} : accounts.first;
          _membership = MembershipService.map(results[1]);
          _invoices = PlatformAdminService.rows(results[2]);
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = PlatformAdminService.error(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit() async {
    if (await editSubscriptionAccount(context, widget.business, _account) &&
        mounted) {
      await _load();
    }
  }

  Future<void> _enrol() async {
    if (await confirmCutLinkMembership(context, widget.business) && mounted) {
      await _load();
    }
  }

  Future<void> _offer(bool revoke) async {
    if (await changeCutLinkFoundingOffer(
          context,
          widget.business,
          _membership,
          revoke: revoke,
        ) &&
        mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AdminLoading();
    }
    if (_error != null) {
      return BillingError(message: _error!, onRetry: _load);
    }
    final managed = _membership.isNotEmpty && _membership['legacy'] != true;
    final adminBusiness = PlatformAdminService.rows(
      widget.business['members'],
    ).any((member) => member['is_admin'] == true);
    final eligible =
        widget.business['active'] == true &&
        widget.business['verification_status'] == 'approved' &&
        !adminBusiness;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_account.isNotEmpty)
          BillingAccountCard(
            account: _account,
            onEdit: _edit,
            onInvoice: () async {
              await createSubscriptionInvoice(context, _account);
              if (mounted) {
                await _load();
              }
            },
          ),
        if (!managed)
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _account.isEmpty
                      ? 'Start this business’s billing'
                      : 'Custom billing account',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const IosGap(height: 8),
                Text(
                  eligible
                      ? 'Choose a membership once. The offer, dates and billing account are set up together.'
                      : adminBusiness
                      ? 'Admin businesses use custom billing and cannot take founding places.'
                      : 'Approve and activate this business before starting its membership.',
                ),
                const IosGap(height: 12),
                if (eligible)
                  FilledButton(
                    onPressed: _enrol,
                    child: const Text('Start membership'),
                  ),
                if (!eligible &&
                    !adminBusiness &&
                    widget.onReviewAccess != null)
                  OutlinedButton(
                    onPressed: () async {
                      await widget.onReviewAccess!();
                    },
                    child: const Text('Review business access'),
                  ),
                if (_account.isEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Custom billing instead'),
                    children: [
                      const Text(
                        'Use only when you deliberately need a manual fee rather than a membership offer.',
                      ),
                      TextButton(
                        onPressed: _edit,
                        child: const Text('Create manual account'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        if (managed)
          AdminCard(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(adminOfferLabel(_membership)),
              subtitle: const Text('Offer dates & membership actions'),
              children: [
                ListTile(
                  title: const Text('Membership started'),
                  trailing: Text(
                    PlatformAdminService.date(_membership['started_on']),
                  ),
                ),
                if (_membership['free_end'] != null)
                  ListTile(
                    title: const Text('Free months end'),
                    trailing: Text(
                      PlatformAdminService.date(_membership['free_end']),
                    ),
                  ),
                if (_membership['discount_end'] != null)
                  ListTile(
                    title: const Text('Half-price year ends'),
                    trailing: Text(
                      PlatformAdminService.date(_membership['discount_end']),
                    ),
                  ),
                ListTile(
                  title: const Text('Regular monthly price'),
                  trailing: Text(
                    '${MembershipService.money(_membership['standard_total'])} inc. GST',
                  ),
                ),
                if (_membership['position'] != null &&
                    _membership['revoked_at'] == null)
                  Wrap(
                    spacing: 10,
                    children: [
                      TextButton(
                        onPressed: () => _offer(false),
                        child: const Text('Change founding offer'),
                      ),
                      TextButton(
                        onPressed: () => _offer(true),
                        child: const Text('End founding discount'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        const IosPadding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'CutLink invoices',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        if (_invoices.isEmpty)
          const AdminCard(
            child: Text('No invoices yet. Create one from the account above.'),
          ),
        for (final invoice in _invoices.take(50))
          BillingInvoiceTile(
            invoice: invoice,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PlatformInvoicePage(invoiceId: '${invoice['id']}'),
                ),
              );
              if (mounted) {
                await _load();
              }
            },
          ),
        if (_invoices.isNotEmpty || _page > 0)
          AdminPager(
            page: _page,
            more: _invoices.length > 50,
            onPage: (page) {
              _page = page;
              _load();
            },
          ),
      ],
    );
  }
}

class _BillingBusinessPicker extends StatefulWidget {
  const _BillingBusinessPicker();
  @override
  State<_BillingBusinessPicker> createState() => _BillingBusinessPickerState();
}

class _BillingBusinessPickerState extends State<_BillingBusinessPicker> {
  List<AdminRow> _rows = [];
  String _search = '';
  String? _error;
  bool _loading = true;
  int _page = 0, _request = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
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
      final data = await PlatformAdminService.query(
        'businesses',
        search: _search,
        offset: _page * 50,
      );
      if (mounted && request == _request) {
        setState(() {
          _rows = PlatformAdminService.rows(data);
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = PlatformAdminService.error(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose a business'),
    content: SizedBox(
      width: 620,
      height: MediaQuery.sizeOf(context).height * .55,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search business',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              _search = value;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () {
                _page = 0;
                _load();
              });
            },
          ),
          const IosGap(height: 12),
          Expanded(
            child: _loading
                ? const AdminLoading()
                : _error != null
                ? BillingError(message: _error!, onRetry: _load)
                : ListView(
                    children: [
                      if (_rows.isEmpty)
                        const ListTile(title: Text('No matching businesses')),
                      for (final row in _rows.take(50))
                        ListTile(
                          title: Text(PlatformAdminService.name(row)),
                          subtitle: Text(
                            '${row['business_type']} · ${row['verification_status']}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              Navigator.of(context).pop('${row['id']}'),
                        ),
                    ],
                  ),
          ),
          AdminPager(
            page: _page,
            more: _rows.length > 50,
            onPage: (page) {
              _page = page;
              _load();
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ],
  );
}
