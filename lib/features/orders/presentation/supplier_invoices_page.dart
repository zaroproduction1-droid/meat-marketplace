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
            border: Border.all(color: const Color(0xFFE0E0DD)),
            borderRadius: BorderRadius.circular(12),
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
        constraints: const BoxConstraints(maxWidth: 1150),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoices',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage supplier invoices, tax status and payment status.',
                          style: TextStyle(color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadInvoices,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
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
                  fillColor: Colors.white,
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
            Material(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: _darkRed,
                indicatorColor: _darkRed,
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
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Supplier Invoices',
          style: TextStyle(fontWeight: FontWeight.w700),
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
