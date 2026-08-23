import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import '../services/invoice_pdf_service.dart';

class ButcherAccountsPage extends StatefulWidget {
  const ButcherAccountsPage({super.key});

  @override
  State<ButcherAccountsPage> createState() => _ButcherAccountsPageState();
}

class _ButcherAccountsPageState extends State<ButcherAccountsPage>
    with SingleTickerProviderStateMixin {
  static const Color _darkRed = Color(0xFF8B1E1E);

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _invoices = [];
  Map<String, String> _supplierNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_refresh);
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final chars = parts[0].split('').reversed.toList();
    final grouped = <String>[];

    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        grouped.add(',');
      }
      grouped.add(chars[i]);
    }

    return '\$${grouped.reversed.join()}.${parts[1]}';
  }

  String _date(dynamic value) {
    if (value == null) {
      return '—';
    }

    final parsed = DateTime.tryParse(value.toString())?.toLocal();

    if (parsed == null) {
      return value.toString();
    }

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');

    return '$day/$month/${parsed.year}';
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('You are not signed in.');
      }

      final memberships = await client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', userId)
          .eq('status', 'active');

      final businessIds = <String>[
        for (final raw in _maps(memberships))
          if (raw['business_id'] != null) raw['business_id'].toString(),
      ];

      if (businessIds.isEmpty) {
        throw Exception('No active business membership was found.');
      }

      final businesses = await client
          .from('businesses')
          .select('id, business_type, active')
          .inFilter('id', businessIds);

      String? butcherBusinessId;

      for (final business in _maps(businesses)) {
        if (business['business_type']?.toString() == 'butcher' &&
            business['active'] != false) {
          butcherBusinessId = business['id']?.toString();
          break;
        }
      }

      if (butcherBusinessId == null || butcherBusinessId.isEmpty) {
        throw Exception(
          'No active butcher business was found for this account.',
        );
      }

      final response = await client
          .from('invoices')
          .select('''
            id,
            invoice_number,
            order_id,
            supplier_business_id,
            butcher_business_id,
            status,
            customer_name_snapshot,
            customer_reference_snapshot,
            payment_method_snapshot,
            payment_terms_days_snapshot,
            products_subtotal,
            delivery_fee,
            tax_amount,
            total_amount,
            invoice_date,
            due_date,
            notes,
            issued_at,
            paid_at,
            sent_to_butcher_at,
            amount_paid,
            last_payment_at,
            customer_payment_claim_status,
            customer_payment_claimed_at,
            customer_payment_claimed_amount,
            customer_payment_claimed_note,
            payment_claim_reviewed_at,
            payment_claim_review_note,
            supplier_trading_name_snapshot,
            supplier_legal_name_snapshot,
            supplier_abn_snapshot,
            supplier_licence_number_snapshot,
            supplier_email_snapshot,
            supplier_phone_snapshot,
            supplier_address_line_1_snapshot,
            supplier_address_line_2_snapshot,
            supplier_suburb_snapshot,
            supplier_state_snapshot,
            supplier_postcode_snapshot,
            bank_name_snapshot,
            bank_account_name_snapshot,
            bank_bsb_snapshot,
            bank_account_number_snapshot,
            payment_instructions_snapshot,
            customer_legal_name_snapshot,
            customer_abn_snapshot,
            customer_email_snapshot,
            customer_phone_snapshot,
            customer_billing_address_line_1_snapshot,
            customer_billing_address_line_2_snapshot,
            customer_billing_suburb_snapshot,
            customer_billing_state_snapshot,
            customer_billing_postcode_snapshot,
            created_at,
            invoice_items(
              id,
              product_name_snapshot,
              sku_snapshot,
              ordered_quantity,
              ordered_quantity_unit,
              supplied_quantity,
              supplied_quantity_unit,
              actual_weight,
              actual_weight_unit,
              locked_unit_price,
              price_basis,
              line_amount
            )
          ''')
          .eq('butcher_business_id', butcherBusinessId)
          .not('sent_to_butcher_at', 'is', null)
          .order('invoice_date', ascending: false)
          .order('created_at', ascending: false);

      final invoices = _maps(response);
      final supplierIds = invoices
          .map((invoice) => invoice['supplier_business_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final supplierNames = <String, String>{};

      if (supplierIds.isNotEmpty) {
        final businesses = await client
            .from('businesses')
            .select('id, trading_name, legal_name')
            .inFilter('id', supplierIds);

        for (final business in _maps(businesses)) {
          final id = business['id']?.toString();

          if (id == null || id.isEmpty) {
            continue;
          }

          final tradingName = business['trading_name']?.toString().trim();
          final legalName = business['legal_name']?.toString().trim();

          supplierNames[id] = tradingName != null && tradingName.isNotEmpty
              ? tradingName
              : legalName != null && legalName.isNotEmpty
              ? legalName
              : 'Supplier';
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _invoices = invoices;
        _supplierNames = supplierNames;
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  double _total(Map<String, dynamic> invoice) =>
      _asDouble(invoice['total_amount']);

  double _paid(Map<String, dynamic> invoice) =>
      _asDouble(invoice['amount_paid']);

  double _outstanding(Map<String, dynamic> invoice) {
    final value = _total(invoice) - _paid(invoice);
    return value < 0 ? 0 : value;
  }

  String _paymentMethod(Map<String, dynamic> invoice) =>
      invoice['payment_method_snapshot']?.toString().trim().toLowerCase() ?? '';

  bool _isPaid(Map<String, dynamic> invoice) =>
      invoice['status']?.toString() == 'paid' || _outstanding(invoice) <= 0;

  bool _isCod(Map<String, dynamic> invoice) {
    final method = _paymentMethod(invoice);
    return !_isPaid(invoice) &&
        (method == 'cod' ||
            method == 'cash on delivery' ||
            method == 'cash_on_delivery');
  }

  bool _isOutstanding(Map<String, dynamic> invoice) =>
      !_isPaid(invoice) && !_isCod(invoice);

  bool _isOverdue(Map<String, dynamic> invoice) {
    if (_isPaid(invoice) || _isCod(invoice)) {
      return false;
    }

    final due = invoice['due_date'] == null
        ? null
        : DateTime.tryParse(invoice['due_date'].toString())?.toLocal();

    if (due == null) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);

    return dueDay.isBefore(today);
  }

  String _supplierName(Map<String, dynamic> invoice) {
    final supplierId = invoice['supplier_business_id']?.toString();
    return _supplierNames[supplierId] ?? 'Supplier';
  }

  List<Map<String, dynamic>> _filter(
    bool Function(Map<String, dynamic>) predicate,
  ) {
    final search = _searchController.text.trim().toLowerCase();

    return _invoices.where((invoice) {
      if (!predicate(invoice)) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      final items = invoice['invoice_items'] is List
          ? List<dynamic>.from(invoice['invoice_items'] as List)
          : <dynamic>[];

      final text = <String>[
        invoice['invoice_number']?.toString() ?? '',
        invoice['customer_reference_snapshot']?.toString() ?? '',
        _supplierName(invoice),
        invoice['invoice_date']?.toString() ?? '',
        invoice['due_date']?.toString() ?? '',
        invoice['payment_method_snapshot']?.toString() ?? '',
        for (final item in items)
          if (item is Map) item['product_name_snapshot']?.toString() ?? '',
      ].join(' ').toLowerCase();

      return text.contains(search);
    }).toList();
  }

  double get _totalOutstanding => _invoices
      .where((invoice) => !_isPaid(invoice))
      .fold(0, (sum, invoice) => sum + _outstanding(invoice));

  double get _totalOverdue => _invoices
      .where(_isOverdue)
      .fold(0, (sum, invoice) => sum + _outstanding(invoice));

  double get _totalCod => _invoices
      .where(_isCod)
      .fold(0, (sum, invoice) => sum + _outstanding(invoice));

  String _statusLabel(Map<String, dynamic> invoice) {
    if (_isPaid(invoice)) {
      return 'Paid';
    }

    if (_isCod(invoice)) {
      return 'Payment Required';
    }

    if (_isOverdue(invoice)) {
      return 'Overdue';
    }

    if (_paid(invoice) > 0) {
      return 'Partially Paid';
    }

    return 'Outstanding';
  }

  Color _statusColor(Map<String, dynamic> invoice) {
    if (_isPaid(invoice)) {
      return const Color(0xFF2E7D32);
    }

    if (_isOverdue(invoice) || _isCod(invoice)) {
      return _darkRed;
    }

    return const Color(0xFF9A6700);
  }

  Widget _summaryCard({
    required String label,
    required double amount,
    required IconData icon,
  }) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: _darkRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _money(amount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceList(List<Map<String, dynamic>> invoices) {
    if (invoices.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 55),
          Icon(Icons.receipt_long_outlined, size: 46, color: Color(0xFFAAAAAA)),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No invoices in this section.',
              style: TextStyle(
                color: Color(0xFF666666),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      itemCount: invoices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final statusColor = _statusColor(invoice);
        final outstanding = _outstanding(invoice);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ButcherInvoiceDetailPage(
                    invoiceId: invoice['id'].toString(),
                    initialInvoice: invoice,
                    supplierName: _supplierName(invoice),
                    onChanged: _loadAccounts,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE0E0DD)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 780;

                  final identity = Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5EAEA),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: _darkRed,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel(invoice),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _supplierName(invoice),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _darkRed,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final facts = Wrap(
                    spacing: 20,
                    runSpacing: 6,
                    children: [
                      _CompactButcherFact(
                        label: 'DATE',
                        value: _date(invoice['invoice_date']),
                      ),
                      _CompactButcherFact(
                        label: 'DUE',
                        value: _date(invoice['due_date']),
                      ),
                      _CompactButcherFact(
                        label: 'PAYMENT',
                        value:
                            invoice['payment_method_snapshot']?.toString() ??
                            '—',
                      ),
                    ],
                  );

                  final trailing = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'OUTSTANDING',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            _money(outstanding),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: outstanding > 0
                                  ? _darkRed
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.chevron_right, color: _darkRed),
                    ],
                  );

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 9),
                        facts,
                        const SizedBox(height: 7),
                        Align(
                          alignment: Alignment.centerRight,
                          child: trailing,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      SizedBox(width: 300, child: identity),
                      const SizedBox(width: 18),
                      Expanded(child: facts),
                      const SizedBox(width: 12),
                      trailing,
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accounts')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _darkRed),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadAccounts,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cod = _filter(_isCod);
    final outstanding = _filter(_isOutstanding);
    final paid = _filter(_isPaid);
    final all = _filter((_) => true);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAccounts,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'COD / Payment Required (${cod.length})'),
            Tab(text: 'Outstanding (${outstanding.length})'),
            Tab(text: 'Paid (${paid.length})'),
            Tab(text: 'All Invoices (${all.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _summaryCard(
                      label: 'Outstanding',
                      amount: _totalOutstanding,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    _summaryCard(
                      label: 'Overdue',
                      amount: _totalOverdue,
                      icon: Icons.warning_amber_outlined,
                    ),
                    _summaryCard(
                      label: 'COD to Pay',
                      amount: _totalCod,
                      icon: Icons.payments_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search supplier, invoice number, date or product',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAccounts,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _invoiceList(cod),
                  _invoiceList(outstanding),
                  _invoiceList(paid),
                  _invoiceList(all),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactButcherFact extends StatelessWidget {
  const _CompactButcherFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class ButcherInvoiceDetailPage extends StatefulWidget {
  const ButcherInvoiceDetailPage({
    super.key,
    required this.invoiceId,
    required this.initialInvoice,
    required this.supplierName,
    required this.onChanged,
  });

  final String invoiceId;
  final Map<String, dynamic> initialInvoice;
  final String supplierName;
  final Future<void> Function() onChanged;

  @override
  State<ButcherInvoiceDetailPage> createState() =>
      _ButcherInvoiceDetailPageState();
}

class _ButcherInvoiceDetailPageState extends State<ButcherInvoiceDetailPage> {
  static const Color _darkRed = Color(0xFF8B1E1E);

  late Map<String, dynamic> _invoice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _invoice = Map<String, dynamic>.from(widget.initialInvoice);
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  String _date(dynamic value) {
    if (value == null) {
      return '—';
    }

    final parsed = DateTime.tryParse(value.toString())?.toLocal();

    if (parsed == null) {
      return value.toString();
    }

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');

    return '$day/$month/${parsed.year}';
  }

  double get _total => _asDouble(_invoice['total_amount']);
  double get _paid => _asDouble(_invoice['amount_paid']);

  double get _outstanding {
    final value = _total - _paid;
    return value < 0 ? 0 : value;
  }

  String? get _claimStatus =>
      _invoice['customer_payment_claim_status']?.toString();

  bool get _canClaimPaid =>
      !_busy &&
      _outstanding > 0 &&
      (_invoice['status']?.toString() == 'issued' ||
          _invoice['status']?.toString() == 'part_paid') &&
      _claimStatus != 'pending';

  Future<void> _reloadInvoice() async {
    final data = await Supabase.instance.client
        .from('invoices')
        .select('''
          *,
          invoice_items(
            id,
            product_name_snapshot,
            sku_snapshot,
            ordered_quantity,
            ordered_quantity_unit,
            supplied_quantity,
            supplied_quantity_unit,
            actual_weight,
            actual_weight_unit,
            locked_unit_price,
            price_basis,
            line_amount
          )
        ''')
        .eq('id', widget.invoiceId)
        .single();

    if (!mounted) {
      return;
    }

    setState(() {
      _invoice = Map<String, dynamic>.from(data);
    });

    await widget.onChanged();
  }

  Future<void> _markAsPaid() async {
    if (!_canClaimPaid) {
      return;
    }

    final controller = TextEditingController(
      text: _outstanding.toStringAsFixed(2),
    );
    final noteController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark Invoice as Paid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This tells the supplier you have paid. The invoice will not clear until the supplier confirms the payment was received.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount paid',
                prefixText: r'$',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Payment note / reference (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            onPressed: () {
              final amount = double.tryParse(
                controller.text.replaceAll(',', '').trim(),
              );

              if (amount == null || amount <= 0 || amount > _outstanding) {
                return;
              }

              Navigator.of(
                dialogContext,
              ).pop({'amount': amount, 'note': noteController.text.trim()});
            },
            child: const Text('Submit Payment Claim'),
          ),
        ],
      ),
    );

    controller.dispose();
    noteController.dispose();

    if (result == null) {
      return;
    }

    setState(() => _busy = true);

    try {
      await Supabase.instance.client.rpc(
        'claim_invoice_paid',
        params: {
          'target_invoice_id': widget.invoiceId,
          'claimed_amount': result['amount'],
          'claim_note': result['note'],
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment claim sent to the supplier for confirmation.'),
        ),
      );

      await _reloadInvoice();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _downloadPdf() async {
    final items = _invoice['invoice_items'] is List
        ? List<dynamic>.from(_invoice['invoice_items'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    await Printing.layoutPdf(
      name: '${_invoice['invoice_number']?.toString() ?? 'invoice'}.pdf',
      onLayout: (_) => CutLinkInvoicePdf.build(invoice: _invoice, items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _invoice['invoice_items'] is List
        ? List<dynamic>.from(_invoice['invoice_items'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    final gst = _asDouble(_invoice['tax_amount']);

    Widget itemsPanel() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0DD)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 11, 14, 9),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 19, color: _darkRed),
                  SizedBox(width: 8),
                  Text(
                    'Invoice Items',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final item = items[index];
                  final actualWeight = _asDouble(item['actual_weight']);
                  final unitPrice = _asDouble(item['locked_unit_price']);
                  final lineAmount = _asDouble(item['line_amount']);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['product_name_snapshot']?.toString() ??
                                    'Product',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                actualWeight > 0
                                    ? '${actualWeight.toStringAsFixed(2)} kg × ${_money(unitPrice)}/kg'
                                    : '${item['ordered_quantity'] ?? ''} ${item['ordered_quantity_unit'] ?? ''} × ${_money(unitPrice)}',
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _money(lineAmount),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    Widget summaryPanel() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0DD)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListView(
          children: [
            Text(
              widget.supplierName,
              style: const TextStyle(
                color: _darkRed,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _DetailValue(
              label: 'Invoice date',
              value: _date(_invoice['invoice_date']),
            ),
            const SizedBox(height: 8),
            _DetailValue(label: 'Due date', value: _date(_invoice['due_date'])),
            const SizedBox(height: 8),
            _DetailValue(
              label: 'Payment method',
              value: _invoice['payment_method_snapshot']?.toString() ?? '—',
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _amountRow(
              'Products inc GST',
              _asDouble(_invoice['products_subtotal']),
            ),
            _amountRow('Delivery inc GST', _asDouble(_invoice['delivery_fee'])),
            _amountRow('GST included', gst),
            const Divider(height: 18),
            _amountRow('Total inc GST', _total, strong: true),
            _amountRow('Paid', _paid),
            _amountRow('Outstanding', _outstanding, strong: true),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _canClaimPaid ? _markAsPaid : null,
              style: FilledButton.styleFrom(backgroundColor: _darkRed),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                _claimStatus == 'pending'
                    ? 'Awaiting Confirmation'
                    : _outstanding <= 0
                    ? 'Paid'
                    : 'Mark as Paid',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Invoice PDF'),
            ),
            if (_claimStatus == 'pending') ...[
              const SizedBox(height: 10),
              Text(
                'Payment claim sent to the supplier for confirmation.',
                style: const TextStyle(
                  color: Color(0xFF9A6700),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (_claimStatus == 'rejected') ...[
              const SizedBox(height: 10),
              Text(
                'The supplier did not confirm the previous payment claim.${(_invoice['payment_claim_review_note']?.toString().trim() ?? '').isEmpty ? '' : ' ${_invoice['payment_claim_review_note']}'}',
                style: const TextStyle(
                  color: _darkRed,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          _invoice['invoice_number']?.toString() ?? 'Invoice',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Download / Print PDF',
            onPressed: _downloadPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;

          if (!desktop) {
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                SizedBox(height: 430, child: itemsPanel()),
                const SizedBox(height: 12),
                SizedBox(height: 500, child: summaryPanel()),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(child: itemsPanel()),
                    const SizedBox(width: 12),
                    SizedBox(width: 340, child: summaryPanel()),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _amountRow(String label, double value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 185,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
