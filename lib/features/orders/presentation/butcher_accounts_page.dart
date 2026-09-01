import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';

import '../services/invoice_pdf_service.dart';
import 'account_statement_page.dart';

class ButcherAccountsPage extends StatefulWidget {
  const ButcherAccountsPage({super.key});

  @override
  State<ButcherAccountsPage> createState() => _ButcherAccountsPageState();
}

class _ButcherAccountsPageState extends State<ButcherAccountsPage> {
  static const Color _darkRed = Color(0xFF8B1E1E);

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _supplierAccounts = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) => '\$${_asDouble(value).toStringAsFixed(2)}';

  String _terms(Map<String, dynamic> account) {
    final method = account['payment_method']?.toString();
    final days = (account['payment_terms_days'] as num?)?.toInt() ?? 0;

    if (method == 'prepaid') return 'Prepaid';
    if (method == 'cod') return 'COD';
    if (days > 0) return '$days days';
    return 'Not set';
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'overdue':
        return 'Overdue';
      case 'due_soon':
        return 'Due Soon';
      case 'open':
        return 'Open';
      case 'credit_available':
        return 'Credit Available';
      case 'clear':
        return 'Clear';
      default:
        return 'Open';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'overdue':
        return const Color(0xFFB3261E);
      case 'due_soon':
        return const Color(0xFF9A5B00);
      case 'credit_available':
        return const Color(0xFF315A8C);
      case 'clear':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF666A70);
    }
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'list_butcher_supplier_account_summaries',
        params: {'due_soon_days': 7},
      );

      if (!mounted) return;

      setState(() {
        _supplierAccounts = List<Map<String, dynamic>>.from(response as List);
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAccounts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _supplierAccounts;

    return _supplierAccounts.where((account) {
      return (account['supplier_name']?.toString() ?? '')
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  double get _totalOutstanding => _supplierAccounts.fold(
    0,
    (sum, a) => sum + _asDouble(a['outstanding_balance']),
  );

  double get _totalOverdue => _supplierAccounts.fold(
    0,
    (sum, a) => sum + _asDouble(a['overdue_amount']),
  );

  double get _totalDueSoon => _supplierAccounts.fold(
    0,
    (sum, a) => sum + _asDouble(a['due_soon_amount']),
  );

  Future<void> _openSupplierAccount(Map<String, dynamic> account) async {
    final supplierId = account['supplier_business_id']?.toString();
    if (supplierId == null || supplierId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ButcherSupplierAccountPage(
          supplierBusinessId: supplierId,
          supplierName: account['supplier_name']?.toString() ?? 'Supplier',
        ),
      ),
    );

    if (mounted) await _loadAccounts();
  }

  Widget _summaryCard({
    required String label,
    required String value,
    IconData? icon,
    Color? valueColor,
    String? subtitle,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E5E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: valueColor ?? _darkRed),
            const SizedBox(height: 8),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF222222),
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _supplierAccountRow(Map<String, dynamic> account) {
    final status = account['account_status']?.toString();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openSupplierAccount(account),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3E5E8)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4E5E5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: _darkRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                account['supplier_name']?.toString() ?? 'Supplier',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _fact(
              'OUTSTANDING',
              _money(account['outstanding_balance']),
              valueColor: _asDouble(account['outstanding_balance']) > 0
                  ? _darkRed
                  : null,
            ),
            const SizedBox(width: 20),
            _fact(
              'OVERDUE',
              _money(account['overdue_amount']),
              valueColor: _asDouble(account['overdue_amount']) > 0
                  ? const Color(0xFFB3261E)
                  : null,
            ),
            const SizedBox(width: 20),
            _fact('TERMS', _terms(account)),
            const SizedBox(width: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                  color: _statusColor(status),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: _darkRed),
          ],
        ),
      ),
    );
  }

  Widget _fact(
    String label,
    String value, {
    String? subtitle,
    Color? valueColor,
  }) {
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF222222),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 9.5),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accounts & Invoices')),
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
            Icon(
              Icons.account_balance_wallet_outlined,
              color: _darkRed,
              size: 22,
            ),
            SizedBox(width: 10),
            Text(
              'Accounts & Invoices',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAccounts,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE3E5E8)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAccounts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 38),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _summaryCard(
                          label: 'Total Outstanding',
                          value: _money(_totalOutstanding),
                          icon: Icons.account_balance_wallet_outlined,
                          valueColor: _totalOutstanding > 0 ? _darkRed : null,
                        ),
                        _summaryCard(
                          label: 'Due Soon',
                          value: _money(_totalDueSoon),
                          icon: Icons.schedule_outlined,
                          valueColor: _totalDueSoon > 0
                              ? const Color(0xFF9A5B00)
                              : null,
                        ),
                        _summaryCard(
                          label: 'Overdue',
                          value: _money(_totalOverdue),
                          icon: Icons.warning_amber_rounded,
                          valueColor: _totalOverdue > 0
                              ? const Color(0xFFB3261E)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search supplier accounts',
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Supplier Accounts',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    if (_filteredAccounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE3E5E8)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 9,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'No supplier accounts found.',
                            style: TextStyle(color: Color(0xFF777777)),
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < _filteredAccounts.length; i++) ...[
                        _supplierAccountRow(_filteredAccounts[i]),
                        if (i != _filteredAccounts.length - 1)
                          const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ButcherSupplierAccountPage extends StatefulWidget {
  const ButcherSupplierAccountPage({
    super.key,
    required this.supplierBusinessId,
    required this.supplierName,
  });

  final String supplierBusinessId;
  final String supplierName;

  @override
  State<ButcherSupplierAccountPage> createState() =>
      _ButcherSupplierAccountPageState();
}

class _ButcherSupplierAccountPageState
    extends State<ButcherSupplierAccountPage> {
  static const Color _darkRed = Color(0xFF8B1E1E);

  bool _loading = true;
  String? _error;
  String? _butcherBusinessId;
  String _butcherName = 'Your Business';
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _allocations = [];
  List<Map<String, dynamic>> _credits = [];
  List<Map<String, dynamic>> _creditAllocations = [];
  List<Map<String, dynamic>> _paymentSubmissions = [];

  final Set<String> _selectedInvoiceIds = <String>{};

  String _invoiceFilter = 'open';

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) => '\$${_asDouble(value).toStringAsFixed(2)}';

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _date(dynamic value) {
    final d = _parseDate(value);
    if (d == null) return '—';

    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Future<String> _resolveButcherBusinessId() async {
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

    final ids = (memberships as List)
        .whereType<Map>()
        .map((m) => m['business_id']?.toString())
        .whereType<String>()
        .toList();

    if (ids.isEmpty) {
      throw Exception('No active business membership was found.');
    }

    final businesses = await client
        .from('businesses')
        .select('id, business_type, active')
        .inFilter('id', ids);

    for (final raw in (businesses as List).whereType<Map>()) {
      if (raw['business_type']?.toString() == 'butcher' &&
          raw['active'] != false) {
        return raw['id'].toString();
      }
    }

    throw Exception('No active butcher business was found.');
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final butcherId = await _resolveButcherBusinessId();

      final butcherBusiness = await client
          .from('businesses')
          .select('trading_name, legal_name')
          .eq('id', butcherId)
          .maybeSingle();

      final butcherTradingName =
          butcherBusiness?['trading_name']?.toString().trim() ?? '';
      final butcherLegalName =
          butcherBusiness?['legal_name']?.toString().trim() ?? '';
      final butcherName = butcherTradingName.isNotEmpty
          ? butcherTradingName
          : (butcherLegalName.isNotEmpty ? butcherLegalName : 'Your Business');

      final summaryResponse = await client.rpc(
        'list_butcher_supplier_account_summaries',
        params: {'due_soon_days': 7},
      );

      Map<String, dynamic>? summary;
      for (final raw in (summaryResponse as List).whereType<Map>()) {
        if (raw['supplier_business_id']?.toString() ==
            widget.supplierBusinessId) {
          summary = Map<String, dynamic>.from(raw);
          break;
        }
      }

      final invoicesResponse = await client
          .from('invoices')
          .select('''
            *,
            orders(order_number),
            payment_allocations(
              id,
              payment_id,
              invoice_id,
              amount,
              status,
              allocated_at,
              account_payments(
                id,
                payment_date,
                reference,
                payment_method,
                amount,
                status
              )
            ),
            credit_allocations(
              id,
              credit_id,
              invoice_id,
              amount,
              status,
              allocated_at,
              account_credits(
                id,
                credit_date,
                reference,
                credit_type,
                amount,
                status
              )
            ),
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
          .eq('supplier_business_id', widget.supplierBusinessId)
          .eq('butcher_business_id', butcherId)
          .not('sent_to_butcher_at', 'is', null)
          .order('invoice_date', ascending: false)
          .order('created_at', ascending: false);

      final paymentSubmissionsResponse = await client
          .from('customer_payment_submissions')
          .select('''
            id,
            supplier_business_id,
            butcher_business_id,
            amount,
            payment_date,
            payment_method,
            reference,
            notes,
            status,
            submitted_at,
            reviewed_at,
            review_note,
            customer_payment_submission_allocations(
              id,
              invoice_id,
              amount,
              invoices(invoice_number)
            )
          ''')
          .eq('supplier_business_id', widget.supplierBusinessId)
          .eq('butcher_business_id', butcherId)
          .eq('status', 'pending')
          .order('submitted_at', ascending: false);

      final paymentsResponse = await client
          .from('account_payments')
          .select('''
            id,
            payment_date,
            amount,
            payment_method,
            reference,
            notes,
            status,
            source_type,
            created_at
          ''')
          .eq('supplier_business_id', widget.supplierBusinessId)
          .eq('butcher_business_id', butcherId)
          .order('payment_date', ascending: false)
          .order('created_at', ascending: false);

      final paymentIds = (paymentsResponse as List)
          .whereType<Map>()
          .map((p) => p['id']?.toString())
          .whereType<String>()
          .toList();

      List<Map<String, dynamic>> allocations = [];
      if (paymentIds.isNotEmpty) {
        allocations = List<Map<String, dynamic>>.from(
          await client
              .from('payment_allocations')
              .select('''
                id,
                payment_id,
                invoice_id,
                amount,
                status,
                allocated_at,
                invoices(invoice_number)
              ''')
              .inFilter('payment_id', paymentIds)
              .order('allocated_at', ascending: false),
        );
      }

      final creditsResponse = await client
          .from('account_credits')
          .select('''
            id,
            credit_date,
            amount,
            credit_type,
            reference,
            reason,
            status,
            created_at
          ''')
          .eq('supplier_business_id', widget.supplierBusinessId)
          .eq('butcher_business_id', butcherId)
          .order('credit_date', ascending: false)
          .order('created_at', ascending: false);

      final creditIds = (creditsResponse as List)
          .whereType<Map>()
          .map((c) => c['id']?.toString())
          .whereType<String>()
          .toList();

      List<Map<String, dynamic>> creditAllocations = [];
      if (creditIds.isNotEmpty) {
        creditAllocations = List<Map<String, dynamic>>.from(
          await client
              .from('credit_allocations')
              .select('''
                id,
                credit_id,
                invoice_id,
                amount,
                status,
                allocated_at,
                invoices(invoice_number)
              ''')
              .inFilter('credit_id', creditIds)
              .order('allocated_at', ascending: false),
        );
      }

      if (!mounted) return;

      setState(() {
        _butcherBusinessId = butcherId;
        _butcherName = butcherName;
        _summary = summary;
        _invoices = List<Map<String, dynamic>>.from(invoicesResponse);
        _payments = List<Map<String, dynamic>>.from(paymentsResponse);
        _allocations = allocations;
        _credits = List<Map<String, dynamic>>.from(creditsResponse);
        _creditAllocations = creditAllocations;
        _paymentSubmissions = List<Map<String, dynamic>>.from(
          paymentSubmissionsResponse,
        );

        _selectedInvoiceIds.removeWhere(
          (id) => !_invoices.any((invoice) => invoice['id']?.toString() == id),
        );

        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String _terms() {
    final method = _summary?['payment_method']?.toString();
    final days = (_summary?['payment_terms_days'] as num?)?.toInt() ?? 0;

    if (method == 'prepaid') return 'Prepaid';
    if (method == 'cod') return 'COD';
    if (days > 0) return '$days days';
    return 'Not set';
  }

  String _termsExplanation() {
    final method = _summary?['payment_method']?.toString();
    final days = (_summary?['payment_terms_days'] as num?)?.toInt() ?? 0;

    if (method == 'prepaid') {
      return 'Payment is required before fulfilment.';
    }
    if (method == 'cod') {
      return 'Payment is due on delivery or collection.';
    }
    if (days > 0) {
      return 'Invoices are due $days days after the invoice date.';
    }
    return 'No account payment terms have been set.';
  }

  double _allocatedForPayment(String paymentId) {
    return _allocations
        .where(
          (a) =>
              a['payment_id']?.toString() == paymentId &&
              a['status']?.toString() == 'active',
        )
        .fold(0.0, (sum, a) => sum + _asDouble(a['amount']));
  }

  double _allocatedForCredit(String creditId) {
    return _creditAllocations
        .where(
          (a) =>
              a['credit_id']?.toString() == creditId &&
              a['status']?.toString() == 'active',
        )
        .fold(0.0, (sum, a) => sum + _asDouble(a['amount']));
  }

  String _invoiceStatus(Map<String, dynamic> invoice) {
    if (invoice['status']?.toString() == 'void') {
      return 'Cancelled / Reversed';
    }

    final outstanding = _asDouble(invoice['outstanding_amount']);
    final paid = _asDouble(invoice['amount_paid']);
    final credit = _asDouble(invoice['credit_applied']);

    if (outstanding <= 0) return 'Paid';

    final due = _parseDate(invoice['due_date']);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (due != null) {
      final dueOnly = DateTime(due.year, due.month, due.day);

      if (dueOnly.isBefore(today)) return 'Overdue';

      if (!dueOnly.isAfter(today.add(const Duration(days: 7)))) {
        return 'Due Soon';
      }
    }

    if (paid > 0 || credit > 0) return 'Partially Paid';

    return 'Open';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return const Color(0xFF2E7D32);
      case 'Overdue':
        return const Color(0xFFB3261E);
      case 'Due Soon':
        return const Color(0xFF9A5B00);
      case 'Partially Paid':
        return const Color(0xFF315A8C);
      default:
        return const Color(0xFF555555);
    }
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    return _invoices.where((invoice) {
      final status = _invoiceStatus(invoice);

      switch (_invoiceFilter) {
        case 'due_soon':
          return status == 'Due Soon';
        case 'overdue':
          return status == 'Overdue';
        case 'part_paid':
          return status == 'Partially Paid';
        case 'open':
        default:
          return status != 'Paid' && status != 'Cancelled / Reversed';
      }
    }).toList();
  }

  List<Map<String, dynamic>> get _selectedInvoices {
    return _invoices
        .where(
          (invoice) =>
              _selectedInvoiceIds.contains(invoice['id']?.toString()) &&
              _asDouble(invoice['outstanding_amount']) > 0 &&
              invoice['status']?.toString() != 'void',
        )
        .toList();
  }

  Future<void> _submitAccountPayment() async {
    if (_loading) return;

    final selected = _selectedInvoices;

    final amountController = TextEditingController(
      text: selected.isEmpty
          ? ''
          : selected
                .fold<double>(
                  0,
                  (sum, invoice) =>
                      sum + _asDouble(invoice['outstanding_amount']),
                )
                .toStringAsFixed(2),
    );
    final referenceController = TextEditingController();
    final notesController = TextEditingController();

    final allocationControllers = <String, TextEditingController>{
      for (final invoice in selected)
        invoice['id'].toString(): TextEditingController(
          text: _asDouble(invoice['outstanding_amount']).toStringAsFixed(2),
        ),
    };

    var method = 'bank_transfer';
    var paymentDate = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double proposedTotal() {
              return allocationControllers.values.fold(
                0,
                (sum, controller) =>
                    sum + (double.tryParse(controller.text.trim()) ?? 0),
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4E5E5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.payments_outlined,
                                color: _darkRed,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Submit Payment',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selected.isEmpty
                                        ? 'Submit a general account / statement payment. '
                                              'The supplier must confirm receipt before it '
                                              'appears in the ledger.'
                                        : 'Submit the payment and proposed invoice '
                                              'allocations. Nothing clears until the supplier '
                                              'confirms the funds were received.',
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: amountController,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Payment amount',
                            prefixText: '\$',
                            filled: true,
                            fillColor: const Color(0xFFF8F8F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: method,
                                decoration: InputDecoration(
                                  labelText: 'Payment method',
                                  filled: true,
                                  fillColor: const Color(0xFFF8F8F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'bank_transfer',
                                    child: Text('Bank Transfer'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'cash',
                                    child: Text('Cash'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'card',
                                    child: Text('Card'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'cheque',
                                    child: Text('Cheque'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'other',
                                    child: Text('Other'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setDialogState(() => method = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(11),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: paymentDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                  );

                                  if (picked != null) {
                                    setDialogState(() => paymentDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Payment date',
                                    filled: true,
                                    fillColor: const Color(0xFFF8F8F6),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                  ),
                                  child: Text(_date(paymentDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: referenceController,
                          decoration: InputDecoration(
                            labelText: 'Reference',
                            hintText: 'Bank transfer reference, receipt, etc.',
                            filled: true,
                            fillColor: const Color(0xFFF8F8F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notes',
                            filled: true,
                            fillColor: const Color(0xFFF8F8F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                        ),
                        if (selected.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Proposed Invoice Allocations',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'You can change how much of the payment you '
                                  'want applied to each selected invoice.',
                                  style: TextStyle(
                                    color: Color(0xFF777777),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                for (final invoice in selected) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              invoice['invoice_number']
                                                      ?.toString() ??
                                                  'Invoice',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              'Outstanding '
                                              '${_money(invoice['outstanding_amount'])}',
                                              style: const TextStyle(
                                                color: Color(0xFF777777),
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 150,
                                        child: TextField(
                                          controller:
                                              allocationControllers[invoice['id']
                                                  .toString()],
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          onChanged: (_) =>
                                              setDialogState(() {}),
                                          decoration: const InputDecoration(
                                            labelText: 'Apply',
                                            prefixText: '\$',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (invoice != selected.last)
                                    const Divider(height: 18),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Proposed: '
                                      '${_money(proposedTotal())}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _darkRed,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () {
                                final paymentAmount = double.tryParse(
                                  amountController.text.trim(),
                                );

                                if (paymentAmount == null ||
                                    paymentAmount <= 0) {
                                  return;
                                }

                                final allocations = <Map<String, dynamic>>[];

                                for (final invoice in selected) {
                                  final invoiceId = invoice['id'].toString();
                                  final amount =
                                      double.tryParse(
                                        allocationControllers[invoiceId]?.text
                                                .trim() ??
                                            '',
                                      ) ??
                                      0;

                                  if (amount < 0 ||
                                      amount >
                                          _asDouble(
                                            invoice['outstanding_amount'],
                                          )) {
                                    return;
                                  }

                                  if (amount > 0) {
                                    allocations.add({
                                      'invoice_id': invoiceId,
                                      'amount': amount,
                                    });
                                  }
                                }

                                final allocatedTotal = allocations.fold<double>(
                                  0,
                                  (sum, item) =>
                                      sum + _asDouble(item['amount']),
                                );

                                if (allocatedTotal > paymentAmount) {
                                  return;
                                }

                                Navigator.of(dialogContext).pop({
                                  'amount': paymentAmount,
                                  'method': method,
                                  'date':
                                      '${paymentDate.year.toString().padLeft(4, '0')}-'
                                      '${paymentDate.month.toString().padLeft(2, '0')}-'
                                      '${paymentDate.day.toString().padLeft(2, '0')}',
                                  'reference': referenceController.text.trim(),
                                  'notes': notesController.text.trim(),
                                  'allocations': allocations,
                                });
                              },
                              icon: const Icon(Icons.send_outlined, size: 18),
                              label: const Text('Submit for Confirmation'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    referenceController.dispose();
    notesController.dispose();
    for (final controller in allocationControllers.values) {
      controller.dispose();
    }

    if (result == null || !mounted) return;

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.rpc(
        'submit_butcher_account_payment',
        params: {
          'target_supplier_business_id': widget.supplierBusinessId,
          'payment_amount': result['amount'],
          'payment_date_value': result['date'],
          'payment_method_value': result['method'],
          'payment_reference': result['reference'],
          'payment_notes': result['notes'],
          'allocations_json': result['allocations'],
        },
      );

      _selectedInvoiceIds.clear();

      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment submitted. It will not clear until the supplier '
              'confirms the funds were received.',
            ),
          ),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Widget _pendingPaymentSubmissions() {
    if (_paymentSubmissions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E5E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: Color(0xFF9A5B00),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Awaiting Supplier Confirmation',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final submission in _paymentSubmissions)
            _pendingSubmissionRow(submission),
        ],
      ),
    );
  }

  Widget _pendingSubmissionRow(Map<String, dynamic> submission) {
    final raw = submission['customer_payment_submission_allocations'];
    final allocations = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    final allocationText = allocations.isEmpty
        ? 'General account / statement payment'
        : allocations
              .map((row) {
                final invoice = row['invoices'];
                final invoiceNo = invoice is Map
                    ? invoice['invoice_number']?.toString() ?? 'Invoice'
                    : 'Invoice';

                return '$invoiceNo ${_money(row['amount'])}';
              })
              .join(' • ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEA))),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Color(0xFF9A5B00)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submission['reference']?.toString().trim().isNotEmpty == true
                      ? submission['reference'].toString()
                      : 'Payment Submitted',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_date(submission['payment_date'])} • $allocationText',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _money(submission['amount']),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3DF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Pending',
              style: TextStyle(
                color: Color(0xFF9A5B00),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInvoice(Map<String, dynamic> invoice) async {
    final id = invoice['id']?.toString();
    if (id == null || id.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ButcherInvoiceDetailPage(
          invoiceId: id,
          initialInvoice: invoice,
          supplierName: widget.supplierName,
          onChanged: _loadPage,
        ),
      ),
    );

    if (mounted) await _loadPage();
  }

  Widget _metric(String label, dynamic value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3E5E8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _money(value),
              style: TextStyle(
                color: color ?? const Color(0xFF222222),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentSelectionBanner() {
    final selected = _selectedInvoices;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE1E1DD)),
      ),
      child: Row(
        children: [
          const Icon(Icons.checklist_rounded, color: _darkRed, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              selected.isEmpty
                  ? 'Submit a payment with no invoice selected for a general '
                        'account / statement payment, or tick invoices to propose '
                        'where the payment should be applied.'
                  : '${selected.length} invoice'
                        '${selected.length == 1 ? '' : 's'} selected for proposed allocation.',
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (selected.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _selectedInvoiceIds.clear());
              },
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Widget _invoiceTable() {
    final rows = _filteredInvoices;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E5E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Invoices Requiring Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                _invoiceFilterMenu(),
              ],
            ),
          ),
          const Divider(height: 1),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No invoices in this view.',
                  style: TextStyle(color: Color(0xFF777777)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 54,
                columns: const [
                  DataColumn(label: SizedBox(width: 34)),
                  DataColumn(label: Text('Invoice')),
                  DataColumn(label: Text('Order')),
                  DataColumn(label: Text('Invoice Date')),
                  DataColumn(label: Text('Due Date')),
                  DataColumn(label: Text('Total'), numeric: true),
                  DataColumn(label: Text('Paid'), numeric: true),
                  DataColumn(label: Text('Outstanding'), numeric: true),
                  DataColumn(label: Text('Status')),
                ],
                rows: rows.map((invoice) {
                  final order = invoice['orders'];
                  final orderNo = order is Map
                      ? order['order_number']?.toString() ?? '—'
                      : '—';
                  final status = _invoiceStatus(invoice);

                  final invoiceId = invoice['id']?.toString();
                  final selectable =
                      _asDouble(invoice['outstanding_amount']) > 0 &&
                      invoice['status']?.toString() != 'void';
                  final selected =
                      invoiceId != null &&
                      _selectedInvoiceIds.contains(invoiceId);

                  return DataRow(
                    selected: selected,
                    cells: [
                      DataCell(
                        Checkbox(
                          value: selected,
                          onChanged: !selectable || invoiceId == null
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedInvoiceIds.add(invoiceId);
                                    } else {
                                      _selectedInvoiceIds.remove(invoiceId);
                                    }
                                  });
                                },
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => _openInvoice(invoice),
                          child: Text(
                            invoice['invoice_number']?.toString() ?? 'Invoice',
                            style: const TextStyle(
                              color: _darkRed,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.underline,
                              decorationColor: _darkRed,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(orderNo)),
                      DataCell(Text(_date(invoice['invoice_date']))),
                      DataCell(Text(_date(invoice['due_date']))),
                      DataCell(Text(_money(invoice['total_amount']))),
                      DataCell(Text(_money(invoice['amount_paid']))),
                      DataCell(
                        Text(
                          _money(invoice['outstanding_amount']),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _invoiceFilterMenu() {
    final labels = <String, String>{
      'open': 'Open',
      'due_soon': 'Due Soon',
      'overdue': 'Overdue',
      'part_paid': 'Partially Paid',
    };

    return PopupMenuButton<String>(
      initialValue: _invoiceFilter,
      tooltip: 'Filter invoices',
      onSelected: (value) => setState(() => _invoiceFilter = value),
      itemBuilder: (_) => labels.entries
          .map(
            (entry) =>
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD9D9D5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 17),
            const SizedBox(width: 6),
            Text(
              labels[_invoiceFilter] ?? 'Open',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentsAndCredits() {
    final entries = <Map<String, dynamic>>[
      for (final payment in _payments)
        if (payment['status']?.toString() == 'active' &&
            ((_asDouble(payment['amount']) -
                        _allocatedForPayment(payment['id']?.toString() ?? ''))
                    .clamp(0, double.infinity) >
                0))
          {'type': 'payment', 'date': payment['payment_date'], 'data': payment},
      for (final credit in _credits)
        if (credit['status']?.toString() == 'active' &&
            ((_asDouble(credit['amount']) -
                        _allocatedForCredit(credit['id']?.toString() ?? ''))
                    .clamp(0, double.infinity) >
                0))
          {'type': 'credit', 'date': credit['credit_date'], 'data': credit},
    ];

    entries.sort((a, b) {
      final ad = _parseDate(a['date']) ?? DateTime(1900);
      final bd = _parseDate(b['date']) ?? DateTime(1900);
      return bd.compareTo(ad);
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E5E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              'Unallocated Payments & Credits',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          const Divider(height: 1),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No unallocated payments or credits requiring action.',
                  style: TextStyle(color: Color(0xFF777777)),
                ),
              ),
            )
          else
            for (final entry in entries) _ledgerRow(entry),
        ],
      ),
    );
  }

  Widget _ledgerRow(Map<String, dynamic> entry) {
    final type = entry['type']?.toString();
    final data = Map<String, dynamic>.from(entry['data'] as Map);

    if (type == 'credit') {
      final id = data['id']?.toString() ?? '';
      final allocated = _allocatedForCredit(id);
      final amount = _asDouble(data['amount']);
      final available = (amount - allocated)
          .clamp(0, double.infinity)
          .toDouble();

      return _ledgerBaseRow(
        icon: Icons.add_card_outlined,
        iconColor: const Color(0xFF315A8C),
        title: data['reference']?.toString().trim().isNotEmpty == true
            ? data['reference'].toString()
            : 'Account Credit',
        subtitle: '${_date(data['credit_date'])} • Credit',
        amount: amount,
        allocated: allocated,
        remainingLabel: 'AVAILABLE',
        remaining: available,
        status: data['status']?.toString() == 'reversed'
            ? 'Reversed'
            : 'Credit',
      );
    }

    final id = data['id']?.toString() ?? '';
    final allocated = _allocatedForPayment(id);
    final amount = _asDouble(data['amount']);
    final unallocated = (amount - allocated)
        .clamp(0, double.infinity)
        .toDouble();

    String status;
    if (data['status']?.toString() == 'reversed') {
      status = 'Reversed';
    } else if (allocated <= 0) {
      status = 'Unallocated';
    } else if (allocated + 0.005 < amount) {
      status = 'Partially Allocated';
    } else {
      status = 'Fully Allocated';
    }

    return _ledgerBaseRow(
      icon: Icons.payments_outlined,
      iconColor: _darkRed,
      title: data['reference']?.toString().trim().isNotEmpty == true
          ? data['reference'].toString()
          : 'Payment',
      subtitle:
          '${_date(data['payment_date'])} • '
          '${_paymentMethodLabel(data['payment_method']?.toString())}',
      amount: amount,
      allocated: allocated,
      remainingLabel: 'UNALLOCATED',
      remaining: unallocated,
      status: status,
    );
  }

  Widget _ledgerBaseRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required double amount,
    required double allocated,
    required String remainingLabel,
    required double remaining,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEA))),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _ledgerAmount('AMOUNT', amount),
          const SizedBox(width: 18),
          _ledgerAmount('ALLOCATED', allocated),
          const SizedBox(width: 18),
          _ledgerAmount(remainingLabel, remaining),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF315A8C).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: Color(0xFF315A8C),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerAmount(String label, double amount) {
    return SizedBox(
      width: 105,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _money(amount),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String? value) {
    switch (value) {
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'cheque':
        return 'Cheque';
      default:
        return 'Other';
    }
  }

  Future<void> _openStatement() async {
    if (_butcherBusinessId == null || _butcherBusinessId!.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AccountStatementPage(
          supplierBusinessId: widget.supplierBusinessId,
          supplierName: widget.supplierName,
          customerName: _butcherName,
          butcherBusinessId: _butcherBusinessId,
          supplierView: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.supplierName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.supplierName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadPage,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            const Icon(
              Icons.account_balance_outlined,
              color: _darkRed,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.supplierName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Text(
                    'Supplier Account',
                    style: TextStyle(
                      color: Color(0xFF666A70),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: _loading ? null : _submitAccountPayment,
            style: FilledButton.styleFrom(
              backgroundColor: _darkRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text(
              'Submit Payment',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _openStatement,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF34383D),
              side: const BorderSide(color: Color(0xFFD9DDE1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text(
              'Statement',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPage,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE3E5E8)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPage,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 38),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _metric(
                          'Outstanding',
                          _summary?['outstanding_balance'],
                          color: _asDouble(_summary?['outstanding_balance']) > 0
                              ? _darkRed
                              : null,
                        ),
                        const SizedBox(width: 10),
                        _metric(
                          'Overdue',
                          _summary?['overdue_amount'],
                          color: _asDouble(_summary?['overdue_amount']) > 0
                              ? const Color(0xFFB3261E)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        _metric(
                          'Due Soon',
                          _summary?['due_soon_amount'],
                          color: _asDouble(_summary?['due_soon_amount']) > 0
                              ? const Color(0xFF9A5B00)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        _metric(
                          'Credit Available',
                          _summary?['credit_available'],
                          color: _asDouble(_summary?['credit_available']) > 0
                              ? const Color(0xFF315A8C)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE3E5E8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: _darkRed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Terms',
                                  style: TextStyle(
                                    color: Color(0xFF777777),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _terms(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _termsExplanation(),
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_paymentSubmissions.isNotEmpty) ...[
                      _pendingPaymentSubmissions(),
                      const SizedBox(height: 12),
                    ],
                    _paymentSelectionBanner(),
                    const SizedBox(height: 12),
                    _invoiceTable(),
                    const SizedBox(height: 12),
                    _paymentsAndCredits(),
                  ],
                ),
              ),
            ),
          ],
        ),
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
  Map<String, dynamic>? _pendingPaymentSubmission;

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
    if (_invoice['outstanding_amount'] != null) {
      return _asDouble(_invoice['outstanding_amount']);
    }

    final value = _total - _paid;
    return value < 0 ? 0 : value;
  }

  bool get _paymentSubmissionPending => _pendingPaymentSubmission != null;

  bool get _canClaimPaid =>
      !_busy &&
      _outstanding > 0 &&
      (_invoice['status']?.toString() == 'issued' ||
          _invoice['status']?.toString() == 'part_paid') &&
      !_paymentSubmissionPending;

  Future<void> _reloadInvoice() async {
    final data = await Supabase.instance.client
        .from('invoices')
        .select('''
          *,
          payment_allocations(
            id,
            amount,
            status,
            allocated_at,
            account_payments(
              id,
              payment_date,
              reference,
              payment_method,
              amount,
              status
            )
          ),
          credit_allocations(
            id,
            amount,
            status,
            allocated_at,
            account_credits(
              id,
              credit_date,
              reference,
              credit_type,
              amount,
              status
            )
          ),
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

    Map<String, dynamic>? pendingSubmission;

    final pendingRows = await Supabase.instance.client
        .from('customer_payment_submission_allocations')
        .select('''
          id,
          amount,
          created_at,
          customer_payment_submissions!inner(
            id,
            amount,
            payment_date,
            payment_method,
            reference,
            notes,
            status,
            submitted_at
          )
        ''')
        .eq('invoice_id', widget.invoiceId)
        .eq('customer_payment_submissions.status', 'pending')
        .order('created_at', ascending: false)
        .limit(1);

    if ((pendingRows as List).isNotEmpty) {
      final row = Map<String, dynamic>.from((pendingRows as List).first as Map);
      final rawSubmission = row['customer_payment_submissions'];

      if (rawSubmission is Map) {
        pendingSubmission = Map<String, dynamic>.from(rawSubmission);
        pendingSubmission['proposed_invoice_amount'] = row['amount'];
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _invoice = Map<String, dynamic>.from(data);
      _pendingPaymentSubmission = pendingSubmission;
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
            child: const Text('Submit Payment'),
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
      final supplierBusinessId = _invoice['supplier_business_id']?.toString();

      if (supplierBusinessId == null || supplierBusinessId.isEmpty) {
        throw Exception('Supplier account could not be resolved.');
      }

      final invoiceNumber = _invoice['invoice_number']?.toString() ?? 'Invoice';

      await Supabase.instance.client.rpc(
        'submit_butcher_account_payment',
        params: {
          'target_supplier_business_id': supplierBusinessId,
          'payment_amount': result['amount'],
          'payment_date_value': DateTime.now()
              .toIso8601String()
              .split('T')
              .first,
          'payment_method_value': 'other',
          'payment_reference': 'Invoice payment • $invoiceNumber',
          'payment_notes': result['note'],
          'allocations_json': [
            {'invoice_id': widget.invoiceId, 'amount': result['amount']},
          ],
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment submitted and linked to this invoice. It will clear only after the supplier confirms receipt.',
          ),
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
          border: Border.all(color: const Color(0xFFE3E5E8)),
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
          border: Border.all(color: const Color(0xFFE3E5E8)),
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
            _amountRow('Paid / Allocated', _paid),
            _amountRow(
              'Credits Applied',
              _asDouble(_invoice['credit_applied']),
            ),
            _amountRow('Outstanding', _outstanding, strong: true),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'Payment Allocations',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ..._buildAllocationRows(),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _canClaimPaid ? _markAsPaid : null,
              style: FilledButton.styleFrom(backgroundColor: _darkRed),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                _paymentSubmissionPending
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
            if (_paymentSubmissionPending) ...[
              const SizedBox(height: 10),
              Text(
                'Payment submitted for '
                '${_money(_asDouble(_pendingPaymentSubmission?['proposed_invoice_amount']))} '
                'against this invoice. Awaiting supplier confirmation.',
                style: const TextStyle(
                  color: Color(0xFF9A6700),
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
      backgroundColor: const Color(0xFFF7F8FA),
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

  List<Widget> _buildAllocationRows() {
    final rows = <Widget>[];

    final paymentAllocations = _invoice['payment_allocations'];
    if (paymentAllocations is List) {
      for (final raw in paymentAllocations.whereType<Map>()) {
        final allocation = Map<String, dynamic>.from(raw);
        if (allocation['status']?.toString() != 'active') continue;

        final paymentRaw = allocation['account_payments'];
        final payment = paymentRaw is Map
            ? Map<String, dynamic>.from(paymentRaw)
            : <String, dynamic>{};

        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    payment['reference']?.toString().trim().isNotEmpty == true
                        ? payment['reference'].toString()
                        : 'Payment ${_date(payment['payment_date'])}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _money(_asDouble(allocation['amount'])),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    final creditAllocations = _invoice['credit_allocations'];
    if (creditAllocations is List) {
      for (final raw in creditAllocations.whereType<Map>()) {
        final allocation = Map<String, dynamic>.from(raw);
        if (allocation['status']?.toString() != 'active') continue;

        final creditRaw = allocation['account_credits'];
        final credit = creditRaw is Map
            ? Map<String, dynamic>.from(creditRaw)
            : <String, dynamic>{};

        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    credit['reference']?.toString().trim().isNotEmpty == true
                        ? credit['reference'].toString()
                        : 'Credit ${_date(credit['credit_date'])}',
                    style: const TextStyle(
                      color: Color(0xFF315A8C),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _money(_asDouble(allocation['amount'])),
                  style: const TextStyle(
                    color: Color(0xFF315A8C),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (rows.isEmpty) {
      rows.add(
        const Text(
          'No payment allocations recorded yet.',
          style: TextStyle(color: Color(0xFF777777), fontSize: 11.5),
        ),
      );
    }

    return rows;
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
