import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_invoice_page.dart';

class SupplierInvoicesPage extends StatefulWidget {
  const SupplierInvoicesPage({super.key});

  @override
  State<SupplierInvoicesPage> createState() => _SupplierInvoicesPageState();
}

class _SupplierInvoicesPageState extends State<SupplierInvoicesPage>
    with SingleTickerProviderStateMixin {
  static const _darkRed = Color(0xFF741C1C);

  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _invoices = [];
  final Set<String> _busyInvoiceIds = <String>{};

  final _searchController = TextEditingController();

  static const _tabs = <String>[
    'all',
    'draft',
    'ready',
    'issued',
    'part_paid',
    'paid',
    'void',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('You must be signed in.');
      }

      final membership = await client
          .from('business_memberships')
          .select('business_id, businesses(id, business_type)')
          .eq('user_id', userId)
          .limit(50);

      String? supplierBusinessId;

      for (final raw in membership as List) {
        if (raw is! Map) {
          continue;
        }

        final row = Map<String, dynamic>.from(raw);
        final businessRaw = row['businesses'];

        if (businessRaw is Map) {
          final business = Map<String, dynamic>.from(businessRaw);
          final type = business['business_type']?.toString();

          if (type == 'supplier') {
            supplierBusinessId = row['business_id']?.toString();
            break;
          }
        }
      }

      if (supplierBusinessId == null || supplierBusinessId.isEmpty) {
        throw Exception('No supplier business membership was found.');
      }

      final response = await client
          .from('invoices')
          .select('''
            id,
            invoice_number,
            order_id,
            supplier_business_id,
            butcher_business_id,
            supplier_customer_account_id,
            status,
            customer_name_snapshot,
            customer_reference_snapshot,
            payment_method_snapshot,
            payment_terms_days_snapshot,
            products_subtotal,
            delivery_fee,
            tax_status,
            tax_category_snapshot,
            tax_rate_snapshot,
            tax_amount,
            total_amount,
            invoice_date,
            due_date,
            issued_at,
            sent_to_butcher_at,
            amount_paid,
            credit_applied,
            outstanding_amount,
            paid_at,
            voided_at,
            created_at,
            updated_at,
            orders(
              id,
              order_number,
              order_source
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .order('created_at', ascending: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _invoices = (response as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value') ?? 0;
  }

  String _money(dynamic value) {
    final amount = _asDouble(value);
    final formatted = amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final whole = parts.first;
    final decimal = parts.last;

    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return '\$${buffer.toString()}.$decimal';
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'draft' => 'Draft',
      'ready' => 'Ready',
      'issued' => 'Issued',
      'part_paid' => 'Part Paid',
      'paid' => 'Paid',
      'void' => 'Void',
      _ => status ?? 'Unknown',
    };
  }

  String _paymentText(Map<String, dynamic> invoice) {
    final method = invoice['payment_method_snapshot']?.toString();

    switch (method) {
      case 'account':
        final days = invoice['payment_terms_days_snapshot'];
        final number = days is num ? days.toInt() : int.tryParse('$days') ?? 0;
        return '$number day account';
      case 'prepaid':
        return 'Prepaid';
      case 'cod':
        return 'COD';
      default:
        return 'Not recorded';
    }
  }

  String _orderNumber(Map<String, dynamic> invoice) {
    final raw = invoice['orders'];

    if (raw is Map) {
      return raw['order_number']?.toString() ?? '';
    }

    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return (raw.first as Map)['order_number']?.toString() ?? '';
    }

    return '';
  }

  String _orderSource(Map<String, dynamic> invoice) {
    final raw = invoice['orders'];

    String? source;

    if (raw is Map) {
      source = raw['order_source']?.toString();
    } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
      source = (raw.first as Map)['order_source']?.toString();
    }

    return switch (source) {
      'marketplace' => 'Marketplace',
      'phone' => 'Phone',
      'email' => 'Email',
      'sales_rep' => 'Sales Rep',
      'manual' => 'Manual',
      _ => source ?? '',
    };
  }

  int _countForStatus(String status) {
    if (status == 'all') {
      return _invoices.length;
    }

    return _invoices
        .where((invoice) => invoice['status']?.toString() == status)
        .length;
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    final selectedStatus = _tabs[_tabController.index];
    final query = _searchController.text.trim().toLowerCase();

    return _invoices.where((invoice) {
      if (selectedStatus != 'all' &&
          invoice['status']?.toString() != selectedStatus) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchText =
          [
                invoice['invoice_number'],
                invoice['customer_name_snapshot'],
                invoice['customer_reference_snapshot'],
                _orderNumber(invoice),
                _orderSource(invoice),
              ]
              .whereType<Object>()
              .map((value) => value.toString().toLowerCase())
              .join(' ');

      return searchText.contains(query);
    }).toList();
  }

  Future<void> _openInvoice(Map<String, dynamic> invoice) async {
    final invoiceId = invoice['id']?.toString();

    if (invoiceId == null || invoiceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This invoice could not be identified.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierInvoicePage(invoiceId: invoiceId),
      ),
    );

    if (mounted) {
      await _loadInvoices();
    }
  }

  bool _isIssuedStatus(String status) {
    return status == 'issued' || status == 'part_paid' || status == 'paid';
  }

  bool _hasButcherAccount(Map<String, dynamic> invoice) {
    return (invoice['butcher_business_id']?.toString().trim() ?? '').isNotEmpty;
  }

  bool _sentToButcher(Map<String, dynamic> invoice) {
    return invoice['sent_to_butcher_at'] != null;
  }

  Future<void> _showIssueInfo() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: _darkRed),
            SizedBox(width: 8),
            Expanded(child: Text('What does Issue Invoice mean?')),
          ],
        ),
        content: const Text(
          'Issuing an invoice finalises it as an official accounts receivable. '
          'The final total and GST become the customer balance CutLink tracks as outstanding.\n\n'
          'If the customer is a linked CutLink Member, the invoice can then be sent to their CutLink account so they can view it, submit payment and track the balance.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmCreditLimitForInvoice(
    Map<String, dynamic> invoice,
  ) async {
    if (invoice['payment_method_snapshot']?.toString() != 'account') {
      return true;
    }

    final accountId = invoice['supplier_customer_account_id']?.toString();

    if (accountId == null || accountId.isEmpty) {
      return true;
    }

    final proposedAmount = _asDouble(invoice['total_amount']);

    final raw = await Supabase.instance.client.rpc(
      'check_supplier_customer_credit_limit',
      params: {
        'target_supplier_customer_account_id': accountId,
        'proposed_amount': proposedAmount,
      },
    );

    final rows = raw is List ? raw : const [];
    if (rows.isEmpty || rows.first is! Map) return true;

    final check = Map<String, dynamic>.from(rows.first as Map);
    if (check['over_limit'] != true) return true;
    if (!mounted) return false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Credit Limit Warning'),
        content: Text(
          'Credit limit: ${_money(check['credit_limit'])}\n'
          'Current exposure: ${_money(check['current_credit_exposure'])}\n'
          'This invoice: ${_money(proposedAmount)}\n'
          'Projected exposure: ${_money(check['projected_credit_exposure'])}\n'
          'Over limit by: ${_money(check['over_limit_by'])}\n\n'
          'Would you like to issue the invoice anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Issue Anyway'),
          ),
        ],
      ),
    );

    return proceed == true;
  }

  Future<void> _issueInvoiceFromList(Map<String, dynamic> invoice) async {
    final id = invoice['id']?.toString();
    if (id == null || id.isEmpty || _busyInvoiceIds.contains(id)) {
      return;
    }

    final status = invoice['status']?.toString() ?? 'draft';

    if (status != 'ready') {
      await _openInvoice(invoice);
      return;
    }

    if (invoice['tax_status']?.toString() != 'configured' ||
        invoice['total_amount'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open the invoice and complete the final invoice details before issuing.',
          ),
        ),
      );
      return;
    }

    try {
      final creditApproved = await _confirmCreditLimitForInvoice(invoice);

      if (!creditApproved || !mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Issue Invoice?'),
          content: Text(
            'Issue ${invoice['invoice_number'] ?? 'this invoice'}?\n\n'
            'It will become an official outstanding receivable.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _darkRed),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Issue Invoice'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() => _busyInvoiceIds.add(id));

      await Supabase.instance.client.rpc(
        'issue_invoice',
        params: {'target_invoice_id': id},
      );

      await _loadInvoices();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invoice issued.')));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busyInvoiceIds.remove(id));
      }
    }
  }

  Future<void> _sendInvoiceFromList(Map<String, dynamic> invoice) async {
    final id = invoice['id']?.toString();
    if (id == null || id.isEmpty || _busyInvoiceIds.contains(id)) {
      return;
    }

    if (!_hasButcherAccount(invoice)) {
      return;
    }

    try {
      setState(() => _busyInvoiceIds.add(id));

      await Supabase.instance.client.rpc(
        'send_invoice_to_butcher',
        params: {'target_invoice_id': id},
      );

      await _loadInvoices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice sent to the butcher’s CutLink account.'),
          ),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busyInvoiceIds.remove(id));
      }
    }
  }

  Widget _invoiceLifecycleAction(Map<String, dynamic> invoice) {
    final id = invoice['id']?.toString() ?? '';
    final status = invoice['status']?.toString() ?? 'draft';
    final busy = _busyInvoiceIds.contains(id);
    final issued = _isIssuedStatus(status);
    final sent = _sentToButcher(invoice);
    final hasButcher = _hasButcherAccount(invoice);

    if (!issued) {
      return FilledButton.icon(
        onPressed: busy ? null : () => _issueInvoiceFromList(invoice),
        style: FilledButton.styleFrom(
          backgroundColor: _darkRed,
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.verified_outlined, size: 17),
        label: Text(status == 'ready' ? 'Issue Invoice' : 'Open & Issue'),
      );
    }

    if (hasButcher && !sent) {
      return FilledButton.icon(
        onPressed: busy ? null : () => _sendInvoiceFromList(invoice),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF315A8C),
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.send_outlined, size: 17),
        label: const Text('Send to Butcher'),
      );
    }

    if (hasButcher && sent) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 17,
            color: Color(0xFF2E7D32),
          ),
          SizedBox(width: 5),
          Text(
            'Sent',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      );
    }

    return const Text(
      'External Customer',
      style: TextStyle(
        color: Color(0xFF777777),
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _statusChip(String status) {
    Color background;
    Color foreground;

    switch (status) {
      case 'draft':
        background = const Color(0xFFF0F0F0);
        foreground = const Color(0xFF555555);
        break;
      case 'ready':
        background = const Color(0xFFFFF1D8);
        foreground = const Color(0xFF8A5B00);
        break;
      case 'issued':
        background = const Color(0xFFE4EEF9);
        foreground = const Color(0xFF275A89);
        break;
      case 'part_paid':
        background = const Color(0xFFF3E9FA);
        foreground = const Color(0xFF6D378C);
        break;
      case 'paid':
        background = const Color(0xFFE5F4E9);
        foreground = const Color(0xFF25663A);
        break;
      case 'void':
        background = const Color(0xFFFCE8E8);
        foreground = const Color(0xFF8C2A2A);
        break;
      default:
        background = const Color(0xFFF0F0F0);
        foreground = const Color(0xFF555555);
    }

    return Chip(
      backgroundColor: background,
      side: BorderSide.none,
      label: Text(
        _statusLabel(status),
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final status = invoice['status']?.toString() ?? 'draft';
    final taxConfigured = invoice['tax_status']?.toString() == 'configured';
    final total = invoice['total_amount'];
    final orderNumber = _orderNumber(invoice);
    final orderSource = _orderSource(invoice);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await _openInvoice(invoice);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE3E5E8)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x07000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 850;

              final identity = Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EAEA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: _darkRed,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                invoice['invoice_number']?.toString() ??
                                    'Invoice',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _statusChip(status),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: 'What does Issue Invoice mean?',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: _showIssueInfo,
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 17,
                                    color: Color(0xFF777777),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice['customer_name_snapshot']?.toString() ??
                              'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _darkRed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final facts = Wrap(
                spacing: 18,
                runSpacing: 7,
                children: [
                  if (orderNumber.isNotEmpty)
                    _MiniInfo(label: 'Order', value: orderNumber),
                  if (orderSource.isNotEmpty)
                    _MiniInfo(label: 'Source', value: orderSource),
                  _MiniInfo(
                    label: 'Invoice date',
                    value: invoice['invoice_date']?.toString() ?? '',
                  ),
                  _MiniInfo(label: 'Payment', value: _paymentText(invoice)),
                  if (!taxConfigured)
                    const _MiniInfo(label: 'GST', value: 'Pending'),
                ],
              );

              final trailing = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _invoiceLifecycleAction(invoice),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        total == null ? 'Pending' : _money(total),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, color: _darkRed),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: 10),
                    facts,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: trailing),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(width: 330, child: identity),
                  const SizedBox(width: 18),
                  Expanded(child: facts),
                  const SizedBox(width: 14),
                  trailing,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: _darkRed),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loadInvoices,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredInvoices;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3E5E8)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x07000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: _darkRed,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice Management',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Prepare, issue, send and track customer invoices and receivables.',
                            style: TextStyle(
                              color: Color(0xFF666A70),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      'Search invoice number, customer, reference or sales order',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE3E5E8)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x07000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: _darkRed,
                  unselectedLabelColor: const Color(0xFF666A70),
                  indicatorColor: _darkRed,
                  indicatorWeight: 3,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  tabs: [
                    Tab(text: 'All (${_countForStatus('all')})'),
                    Tab(text: 'Draft (${_countForStatus('draft')})'),
                    Tab(text: 'Ready (${_countForStatus('ready')})'),
                    Tab(text: 'Issued (${_countForStatus('issued')})'),
                    Tab(text: 'Part Paid (${_countForStatus('part_paid')})'),
                    Tab(text: 'Paid (${_countForStatus('paid')})'),
                    Tab(text: 'Void (${_countForStatus('void')})'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Color(0xFFAAAAAA),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchController.text.trim().isEmpty
                                  ? 'No invoices in this section.'
                                  : 'No invoices match your search.',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadInvoices,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _buildInvoiceCard(filtered[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.request_quote_outlined, color: _darkRed, size: 22),
            SizedBox(width: 10),
            Text(
              'Invoices',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadInvoices,
            tooltip: 'Refresh invoices',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE4E6E8)),
        ),
      ),
      body: _buildBody(),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
