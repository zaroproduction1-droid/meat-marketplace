import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../orders/presentation/account_statement_page.dart';
import '../../orders/presentation/supplier_invoice_page.dart';

class SupplierCustomerAccountPage extends StatefulWidget {
  const SupplierCustomerAccountPage({
    super.key,
    required this.supplierCustomerAccountId,
  });

  final String supplierCustomerAccountId;

  @override
  State<SupplierCustomerAccountPage> createState() =>
      _SupplierCustomerAccountPageState();
}

class _SupplierCustomerAccountPageState
    extends State<SupplierCustomerAccountPage> {
  static const _darkRed = Color(0xFF741C1C);

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  Map<String, dynamic>? _account;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _allocations = [];
  List<Map<String, dynamic>> _credits = [];
  List<Map<String, dynamic>> _creditAllocations = [];
  List<Map<String, dynamic>> _pendingPaymentSubmissions = [];

  String? _selectedInvoiceId;
  String? _selectedPaymentId;

  String _invoiceFilter = 'open';

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      final account = Map<String, dynamic>.from(
        await client
            .from('supplier_customer_accounts')
            .select('''
              id,
              supplier_business_id,
              linked_butcher_business_id,
              supplier_customer_relationship_id,
              account_source,
              customer_name,
              legal_name,
              abn,
              contact_name,
              email,
              phone,
              billing_address_line_1,
              billing_address_line_2,
              billing_suburb,
              billing_state,
              billing_postcode,
              account_reference,
              payment_method,
              payment_terms_days,
              credit_limit,
              active
            ''')
            .eq('id', widget.supplierCustomerAccountId)
            .single(),
      );

      final supplierId = account['supplier_business_id']?.toString();
      final butcherId = account['linked_butcher_business_id']?.toString();

      if (butcherId != null && butcherId.isNotEmpty) {
        final businessResponse = await client
            .from('businesses')
            .select('''
              id,
              trading_name,
              legal_name,
              abn,
              business_email,
              business_phone
            ''')
            .eq('id', butcherId)
            .maybeSingle();

        if (businessResponse != null) {
          account['businesses'] =
              Map<String, dynamic>.from(businessResponse);
        }
      }

      if (supplierId == null) {
        throw Exception('Customer account has no supplier.');
      }

      var invoiceQuery = client
          .from('invoices')
          .select('''
            id,
            invoice_number,
            order_id,
            supplier_customer_account_id,
            butcher_business_id,
            status,
            total_amount,
            amount_paid,
            credit_applied,
            outstanding_amount,
            invoice_date,
            due_date,
            issued_at,
            sent_to_butcher_at,
            supplier_trading_name_snapshot,
            orders(order_number)
          ''')
          .eq('supplier_business_id', supplierId);

      if (butcherId != null && butcherId.isNotEmpty) {
        invoiceQuery = invoiceQuery.or(
          'supplier_customer_account_id.eq.${widget.supplierCustomerAccountId},'
          'butcher_business_id.eq.$butcherId',
        );
      } else {
        invoiceQuery = invoiceQuery.eq(
          'supplier_customer_account_id',
          widget.supplierCustomerAccountId,
        );
      }

      final invoicesResponse = await invoiceQuery
          .order('invoice_date', ascending: false);

      var paymentQuery = client
          .from('account_payments')
          .select('''
            id,
            supplier_business_id,
            butcher_business_id,
            supplier_customer_account_id,
            payment_date,
            amount,
            payment_method,
            reference,
            notes,
            status,
            source_type,
            source_invoice_id,
            created_at,
            reversed_at,
            reversal_note
          ''')
          .eq('supplier_business_id', supplierId);

      if (butcherId != null && butcherId.isNotEmpty) {
        paymentQuery = paymentQuery.or(
          'supplier_customer_account_id.eq.${widget.supplierCustomerAccountId},'
          'butcher_business_id.eq.$butcherId',
        );
      } else {
        paymentQuery = paymentQuery.eq(
          'supplier_customer_account_id',
          widget.supplierCustomerAccountId,
        );
      }

      final paymentsResponse = await paymentQuery
          .order('payment_date', ascending: false)
          .order('created_at', ascending: false);

      final paymentIds = List<Map<String, dynamic>>.from(paymentsResponse)
          .map((e) => e['id']?.toString())
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

      var creditQuery = client
          .from('account_credits')
          .select('''
            id,
            supplier_business_id,
            butcher_business_id,
            supplier_customer_account_id,
            credit_date,
            amount,
            credit_type,
            reference,
            reason,
            source_invoice_id,
            status,
            created_at,
            reversed_at,
            reversal_note
          ''')
          .eq('supplier_business_id', supplierId);

      if (butcherId != null && butcherId.isNotEmpty) {
        creditQuery = creditQuery.or(
          'supplier_customer_account_id.eq.${widget.supplierCustomerAccountId},'
          'butcher_business_id.eq.$butcherId',
        );
      } else {
        creditQuery = creditQuery.eq(
          'supplier_customer_account_id',
          widget.supplierCustomerAccountId,
        );
      }

      final creditsResponse = await creditQuery
          .order('credit_date', ascending: false)
          .order('created_at', ascending: false);

      final creditIds = List<Map<String, dynamic>>.from(creditsResponse)
          .map((e) => e['id']?.toString())
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

      List<Map<String, dynamic>> pendingPaymentSubmissions = [];

      if (butcherId != null && butcherId.isNotEmpty) {
        pendingPaymentSubmissions = List<Map<String, dynamic>>.from(
          await client
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
              .eq('supplier_business_id', supplierId)
              .eq('butcher_business_id', butcherId)
              .eq('status', 'pending')
              .order('submitted_at', ascending: false),
        );
      }

      if (!mounted) return;

      setState(() {
        _account = account;
        _invoices = List<Map<String, dynamic>>.from(invoicesResponse);
        _payments = List<Map<String, dynamic>>.from(paymentsResponse);
        _allocations = allocations;
        _credits = List<Map<String, dynamic>>.from(creditsResponse);
        _creditAllocations = creditAllocations;
        _pendingPaymentSubmissions = pendingPaymentSubmissions;

        if (_selectedInvoiceId != null &&
            !_invoices.any(
              (invoice) =>
                  invoice['id']?.toString() == _selectedInvoiceId,
            )) {
          _selectedInvoiceId = null;
        }

        if (_selectedPaymentId != null &&
            !_payments.any(
              (payment) =>
                  payment['id']?.toString() == _selectedPaymentId,
            )) {
          _selectedPaymentId = null;
        }

        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) =>
      '\$${_asDouble(value).toStringAsFixed(2)}';

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _formatDate(dynamic value) {
    final d = _date(value);
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String _supplierName() {
    final invoices = _invoices;
    if (invoices.isNotEmpty) {
      final snapshot =
          invoices.first['supplier_trading_name_snapshot']
              ?.toString()
              .trim();
      if (snapshot != null && snapshot.isNotEmpty) {
        return snapshot;
      }
    }

    return 'Supplier';
  }

  Future<void> _openStatement() async {
    final account = _account;
    if (account == null) return;

    final supplierId = account['supplier_business_id']?.toString();
    if (supplierId == null || supplierId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AccountStatementPage(
          supplierBusinessId: supplierId,
          supplierName: _supplierName(),
          customerName: _customerName(),
          supplierCustomerAccountId:
              widget.supplierCustomerAccountId,
          butcherBusinessId:
              account['linked_butcher_business_id']?.toString(),
          supplierView: true,
        ),
      ),
    );
  }

  String _customerName() {
    final account = _account;
    if (account == null) return 'Customer';

    final business = account['businesses'];
    if (business is Map) {
      final trading = business['trading_name']?.toString().trim() ?? '';
      if (trading.isNotEmpty) return trading;
    }

    final name = account['customer_name']?.toString().trim() ?? '';
    return name.isEmpty ? 'Customer' : name;
  }

  String _paymentTerms() {
    final method = _account?['payment_method']?.toString();
    final days = (_account?['payment_terms_days'] as num?)?.toInt() ?? 0;

    switch (method) {
      case 'prepaid':
        return 'Prepaid';
      case 'cod':
        return 'COD';
      case 'account':
        return days > 0 ? '$days days' : 'Account';
      default:
        return days > 0 ? '$days days' : 'Not set';
    }
  }

  String _paymentTermsPlainEnglish() {
    final method = _account?['payment_method']?.toString();
    final days = (_account?['payment_terms_days'] as num?)?.toInt() ?? 0;

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

  double get _outstanding => _invoices
      .where((i) => i['status']?.toString() != 'void')
      .fold(0.0, (sum, i) => sum + _asDouble(i['outstanding_amount']));

  double get _overdue {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);

    return _invoices.fold(0.0, (sum, invoice) {
      final due = _date(invoice['due_date']);
      final outstanding = _asDouble(invoice['outstanding_amount']);
      if (due == null || outstanding <= 0) return sum;
      final dueOnly = DateTime(due.year, due.month, due.day);
      return dueOnly.isBefore(dateOnly) ? sum + outstanding : sum;
    });
  }

  double get _dueSoon {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(const Duration(days: 7));

    return _invoices.fold(0.0, (sum, invoice) {
      final due = _date(invoice['due_date']);
      final outstanding = _asDouble(invoice['outstanding_amount']);
      if (due == null || outstanding <= 0) return sum;
      final dueOnly = DateTime(due.year, due.month, due.day);

      if (!dueOnly.isBefore(today) && !dueOnly.isAfter(limit)) {
        return sum + outstanding;
      }

      return sum;
    });
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

  double get _unallocatedPayments => _payments
      .where((p) => p['status']?.toString() == 'active')
      .fold(0.0, (sum, p) {
        final id = p['id']?.toString();
        if (id == null) return sum;
        return sum +
            (_asDouble(p['amount']) - _allocatedForPayment(id))
                .clamp(0, double.infinity)
                .toDouble();
      });

  double get _creditAvailable => _credits
      .where((c) => c['status']?.toString() == 'active')
      .fold(0.0, (sum, c) {
        final id = c['id']?.toString();
        if (id == null) return sum;
        return sum +
            (_asDouble(c['amount']) - _allocatedForCredit(id))
                .clamp(0, double.infinity)
                .toDouble();
      });

  String _invoiceStatus(Map<String, dynamic> invoice) {
    final status = invoice['status']?.toString();

    if (status == 'void') return 'Cancelled / Reversed';

    final outstanding = _asDouble(invoice['outstanding_amount']);
    final paid = _asDouble(invoice['amount_paid']);
    final credit = _asDouble(invoice['credit_applied']);

    if (outstanding <= 0) return 'Paid';

    final due = _date(invoice['due_date']);
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
      case 'Cancelled / Reversed':
        return const Color(0xFF777777);
      default:
        return const Color(0xFF555555);
    }
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    return _invoices.where((invoice) {
      final status = _invoiceStatus(invoice);

      switch (_invoiceFilter) {
        case 'all':
          return true;
        case 'due_soon':
          return status == 'Due Soon';
        case 'overdue':
          return status == 'Overdue';
        case 'part_paid':
          return status == 'Partially Paid';
        case 'paid':
          return status == 'Paid';
        case 'open':
        default:
          return status != 'Paid' && status != 'Cancelled / Reversed';
      }
    }).toList();
  }

  Map<String, dynamic>? get _selectedInvoice {
    final id = _selectedInvoiceId;
    if (id == null) return null;

    for (final invoice in _invoices) {
      if (invoice['id']?.toString() == id) return invoice;
    }

    return null;
  }

  Map<String, dynamic>? get _selectedPayment {
    final id = _selectedPaymentId;
    if (id == null) return null;

    for (final payment in _payments) {
      if (payment['id']?.toString() == id) return payment;
    }

    return null;
  }

  double _paymentAvailable(Map<String, dynamic> payment) {
    final id = payment['id']?.toString();
    if (id == null || payment['status']?.toString() != 'active') {
      return 0;
    }

    final amount = _asDouble(payment['amount']);
    final allocated = _allocatedForPayment(id);
    return (amount - allocated).clamp(0, double.infinity).toDouble();
  }

  bool get _canAllocateSelectedPayment {
    final payment = _selectedPayment;

    if (payment == null || _isSaving) return false;

    return _paymentAvailable(payment) > 0;
  }

  Future<void> _allocateSelectedPayment() async {
    final invoice = _selectedInvoice;
    final payment = _selectedPayment;

    if (payment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an unallocated payment first.'),
        ),
      );
      return;
    }

    if (invoice == null) {
      await _openAllocationDialog(payment);
      return;
    }

    final outstanding = _asDouble(invoice['outstanding_amount']);
    final available = _paymentAvailable(payment);

    if (outstanding <= 0 || available <= 0) return;

    final suggested = outstanding < available ? outstanding : available;
    final amountController = TextEditingController(
      text: suggested.toStringAsFixed(2),
    );

    final confirmedAmount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4E5E5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: _darkRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allocate Payment',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Apply the selected payment to the selected invoice.',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _allocationSummaryRow(
                          'Payment',
                          payment['reference']?.toString().trim().isNotEmpty ==
                                  true
                              ? payment['reference'].toString()
                              : 'Payment ${_formatDate(payment['payment_date'])}',
                        ),
                        const SizedBox(height: 8),
                        _allocationSummaryRow(
                          'Available',
                          _money(available),
                        ),
                        const Divider(height: 20),
                        _allocationSummaryRow(
                          'Invoice',
                          invoice['invoice_number']?.toString() ?? 'Invoice',
                        ),
                        const SizedBox(height: 8),
                        _allocationSummaryRow(
                          'Outstanding',
                          _money(outstanding),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Amount to allocate',
                      prefixText: '\$',
                      filled: true,
                      fillColor: const Color(0xFFF8F8F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
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
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _darkRed,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () {
                          final amount = double.tryParse(
                            amountController.text.trim(),
                          );

                          if (amount == null ||
                              amount <= 0 ||
                              amount > available ||
                              amount > outstanding) {
                            return;
                          }

                          Navigator.of(dialogContext).pop(amount);
                        },
                        child: const Text('Allocate Payment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    amountController.dispose();

    if (confirmedAmount == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.rpc(
        'allocate_account_payment',
        params: {
          'target_payment_id': payment['id'].toString(),
          'allocations_json': [
            {
              'invoice_id': invoice['id'].toString(),
              'amount': confirmedAmount,
            },
          ],
        },
      );

      _selectedInvoiceId = null;
      _selectedPaymentId = null;

      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment allocated.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _allocationSummaryRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _recordPayment({bool allocateImmediately = false}) async {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();

    var date = DateTime.now();
    var method = 'bank_transfer';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Padding(
                  padding: const EdgeInsets.all(22),
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
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Record Payment',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Record money received from this customer. '
                                  'You can allocate it to invoices afterwards.',
                                  style: TextStyle(
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
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _customerName(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: amountController,
                        autofocus: true,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Amount received',
                          prefixText: '\$',
                          filled: true,
                          fillColor: const Color(0xFFF8F8F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
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
                                  initialDate: date,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );

                                if (picked != null) {
                                  setDialogState(() => date = picked);
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
                                child: Text(_formatDate(date)),
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
                          hintText: 'Bank reference, receipt number, etc.',
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
                              final amount = double.tryParse(
                                amountController.text.trim(),
                              );

                              if (amount == null || amount <= 0) return;

                              Navigator.of(dialogContext).pop({
                                'amount': amount,
                                'method': method,
                                'date':
                                    '${date.year.toString().padLeft(4, '0')}-'
                                    '${date.month.toString().padLeft(2, '0')}-'
                                    '${date.day.toString().padLeft(2, '0')}',
                                'reference':
                                    referenceController.text.trim(),
                                'notes': notesController.text.trim(),
                              });
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Record Payment'),
                          ),
                        ],
                      ),
                    ],
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

    if (result == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final response = await Supabase.instance.client.rpc(
        'record_account_payment',
        params: {
          'target_supplier_customer_account_id':
              widget.supplierCustomerAccountId,
          'payment_amount': result['amount'],
          'payment_date_value': result['date'],
          'payment_method_value': result['method'],
          'payment_reference': result['reference'],
          'payment_notes': result['notes'],
        },
      );

      await _loadPage();

      if (!mounted) return;

      final payment = Map<String, dynamic>.from(response as Map);

      setState(() {
        _selectedPaymentId = payment['id']?.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment recorded. It is selected and ready to allocate.',
          ),
        ),
      );

      if (allocateImmediately) {
        await _openAllocationDialog(payment);
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openAllocationDialog(
    Map<String, dynamic> payment,
  ) async {
    final paymentId = payment['id']?.toString();
    if (paymentId == null) return;

    final alreadyAllocated = _allocatedForPayment(paymentId);
    final paymentAmount = _asDouble(payment['amount']);
    final available = paymentAmount - alreadyAllocated;

    final candidates = _invoices
        .where((i) => _asDouble(i['outstanding_amount']) > 0)
        .where((i) => i['status']?.toString() != 'void')
        .toList()
      ..sort((a, b) {
        final ad = _date(a['due_date']) ?? DateTime(9999);
        final bd = _date(b['due_date']) ?? DateTime(9999);
        return ad.compareTo(bd);
      });

    final controllers = <String, TextEditingController>{
      for (final invoice in candidates)
        invoice['id'].toString(): TextEditingController(),
    };

    try {
      final allocations = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              double enteredTotal() => controllers.values.fold(
                    0.0,
                    (sum, c) =>
                        sum + (double.tryParse(c.text.trim()) ?? 0),
                  );

              return AlertDialog(
                title: const Text('Allocate Payment'),
                content: SizedBox(
                  width: 760,
                  height: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Wrap(
                          spacing: 26,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Payment: ${_money(paymentAmount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Already allocated: '
                              '${_money(alreadyAllocated)}',
                            ),
                            Text(
                              'Available: ${_money(available)}',
                              style: const TextStyle(
                                color: _darkRed,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: candidates.isEmpty
                            ? const Center(
                                child: Text('No open invoices to allocate.'),
                              )
                            : ListView.separated(
                                itemCount: candidates.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final invoice = candidates[index];
                                  final id = invoice['id'].toString();
                                  final outstanding = _asDouble(
                                    invoice['outstanding_amount'],
                                  );

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 9,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
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
                                              const SizedBox(height: 2),
                                              Text(
                                                'Due ${_formatDate(invoice['due_date'])}',
                                                style: const TextStyle(
                                                  color: Color(0xFF777777),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Outstanding '
                                            '${_money(outstanding)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 140,
                                          child: TextField(
                                            controller: controllers[id],
                                            keyboardType:
                                                const TextInputType
                                                    .numberWithOptions(
                                              decimal: true,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .allow(
                                                RegExp(r'^\d*\.?\d{0,2}'),
                                              ),
                                            ],
                                            onChanged: (_) =>
                                                setDialogState(() {}),
                                            decoration: const InputDecoration(
                                              prefixText: '\$',
                                              labelText: 'Apply',
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (_) {
                          final entered = enteredTotal();
                          final remaining = available - entered;
                          final invalid = entered > available ||
                              candidates.any((invoice) {
                                final enteredForInvoice = double.tryParse(
                                      controllers[invoice['id'].toString()]
                                              ?.text
                                              .trim() ??
                                          '',
                                    ) ??
                                    0;
                                return enteredForInvoice >
                                    _asDouble(
                                      invoice['outstanding_amount'],
                                    );
                              });

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Allocated: ${_money(entered)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Text(
                                'Remaining: ${_money(remaining)}',
                                style: TextStyle(
                                  color: invalid
                                      ? const Color(0xFFB3261E)
                                      : _darkRed,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkRed,
                    ),
                    onPressed: () {
                      final result = <Map<String, dynamic>>[];

                      for (final invoice in candidates) {
                        final id = invoice['id'].toString();
                        final amount = double.tryParse(
                              controllers[id]?.text.trim() ?? '',
                            ) ??
                            0;

                        if (amount > 0) {
                          if (amount >
                              _asDouble(
                                invoice['outstanding_amount'],
                              )) {
                            return;
                          }

                          result.add({
                            'invoice_id': id,
                            'amount': amount,
                          });
                        }
                      }

                      final total = result.fold<double>(
                        0,
                        (sum, item) =>
                            sum + _asDouble(item['amount']),
                      );

                      if (total <= 0 || total > available) return;

                      Navigator.of(dialogContext).pop(result);
                    },
                    child: const Text('Apply Allocation'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (allocations == null || allocations.isEmpty) return;

      setState(() => _isSaving = true);

      await Supabase.instance.client.rpc(
        'allocate_account_payment',
        params: {
          'target_payment_id': paymentId,
          'allocations_json': allocations,
        },
      );

      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment allocation saved.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _autoAllocate(Map<String, dynamic> payment) async {
    final paymentId = payment['id']?.toString();
    if (paymentId == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final previewResponse = await Supabase.instance.client.rpc(
        'preview_auto_allocate_payment',
        params: {'target_payment_id': paymentId},
      );

      final preview = List<Map<String, dynamic>>.from(
        previewResponse as List,
      );

      if (!mounted) return;

      if (preview.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No open invoices are available for allocation.'),
          ),
        );
        return;
      }

      final total = preview.fold<double>(
        0,
        (sum, row) => sum + _asDouble(row['proposed_allocation']),
      );

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Auto Allocate Payment'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'CutLink will apply this payment to the oldest outstanding invoices first.',
                ),
                const SizedBox(height: 14),
                for (final row in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row['invoice_number']?.toString() ?? 'Invoice',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          'Due ${_formatDate(row['due_date'])}',
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Text(
                          _money(row['proposed_allocation']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                Text(
                  'Total allocation: ${_money(total)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _darkRed,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _darkRed),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm Allocation'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await Supabase.instance.client.rpc(
        'apply_auto_allocate_payment',
        params: {'target_payment_id': paymentId},
      );

      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment auto allocated.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _recordCreditOrAdjustment() async {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final reasonController = TextEditingController();

    var date = DateTime.now();
    var type = 'credit';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Credit / Adjustment'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: amountController,
                        autofocus: true,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'credit',
                            child: Text('Account Credit'),
                          ),
                          DropdownMenuItem(
                            value: 'credit_note',
                            child: Text('Credit Note'),
                          ),
                          DropdownMenuItem(
                            value: 'adjustment',
                            child: Text('Adjustment'),
                          ),
                          DropdownMenuItem(
                            value: 'write_off',
                            child: Text('Write Off'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => type = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: date,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => date = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_formatDate(date)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: referenceController,
                        decoration: const InputDecoration(
                          labelText: 'Reference',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Reason / Notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  onPressed: () {
                    final amount =
                        double.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) return;

                    Navigator.of(dialogContext).pop({
                      'amount': amount,
                      'type': type,
                      'date':
                          '${date.year.toString().padLeft(4, '0')}-'
                          '${date.month.toString().padLeft(2, '0')}-'
                          '${date.day.toString().padLeft(2, '0')}',
                      'reference': referenceController.text.trim(),
                      'reason': reasonController.text.trim(),
                    });
                  },
                  child: const Text('Record'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    referenceController.dispose();
    reasonController.dispose();

    if (result == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.rpc(
        'record_account_credit',
        params: {
          'target_supplier_customer_account_id':
              widget.supplierCustomerAccountId,
          'credit_amount': result['amount'],
          'credit_date_value': result['date'],
          'credit_type_value': result['type'],
          'credit_reference': result['reference'],
          'credit_reason': result['reason'],
        },
      );

      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credit / adjustment recorded.'),
          ),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openCreditAllocationDialog(
    Map<String, dynamic> credit,
  ) async {
    final creditId = credit['id']?.toString();
    if (creditId == null) return;

    final alreadyAllocated = _allocatedForCredit(creditId);
    final creditAmount = _asDouble(credit['amount']);
    final available = creditAmount - alreadyAllocated;

    final candidates = _invoices
        .where((i) => _asDouble(i['outstanding_amount']) > 0)
        .where((i) => i['status']?.toString() != 'void')
        .toList()
      ..sort((a, b) {
        final ad = _date(a['due_date']) ?? DateTime(9999);
        final bd = _date(b['due_date']) ?? DateTime(9999);
        return ad.compareTo(bd);
      });

    final controllers = <String, TextEditingController>{
      for (final invoice in candidates)
        invoice['id'].toString(): TextEditingController(),
    };

    try {
      final allocations = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              double enteredTotal() => controllers.values.fold(
                    0.0,
                    (sum, c) =>
                        sum + (double.tryParse(c.text.trim()) ?? 0),
                  );

              return AlertDialog(
                title: const Text('Allocate Credit'),
                content: SizedBox(
                  width: 760,
                  height: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Wrap(
                          spacing: 26,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Credit: ${_money(creditAmount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Already allocated: ${_money(alreadyAllocated)}',
                            ),
                            Text(
                              'Available: ${_money(available)}',
                              style: const TextStyle(
                                color: Color(0xFF315A8C),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: candidates.isEmpty
                            ? const Center(
                                child: Text('No open invoices to allocate.'),
                              )
                            : ListView.separated(
                                itemCount: candidates.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final invoice = candidates[index];
                                  final id = invoice['id'].toString();
                                  final outstanding = _asDouble(
                                    invoice['outstanding_amount'],
                                  );

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 9,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
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
                                              const SizedBox(height: 2),
                                              Text(
                                                'Due ${_formatDate(invoice['due_date'])}',
                                                style: const TextStyle(
                                                  color: Color(0xFF777777),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Outstanding '
                                            '${_money(outstanding)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 140,
                                          child: TextField(
                                            controller: controllers[id],
                                            keyboardType:
                                                const TextInputType
                                                    .numberWithOptions(
                                              decimal: true,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*\.?\d{0,2}'),
                                              ),
                                            ],
                                            onChanged: (_) =>
                                                setDialogState(() {}),
                                            decoration: const InputDecoration(
                                              prefixText: '\$',
                                              labelText: 'Apply',
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (_) {
                          final entered = enteredTotal();
                          final remaining = available - entered;
                          final invalid = entered > available ||
                              candidates.any((invoice) {
                                final enteredForInvoice = double.tryParse(
                                      controllers[invoice['id'].toString()]
                                              ?.text
                                              .trim() ??
                                          '',
                                    ) ??
                                    0;
                                return enteredForInvoice >
                                    _asDouble(
                                      invoice['outstanding_amount'],
                                    );
                              });

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Allocated: ${_money(entered)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Text(
                                'Remaining: ${_money(remaining)}',
                                style: TextStyle(
                                  color: invalid
                                      ? const Color(0xFFB3261E)
                                      : const Color(0xFF315A8C),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF315A8C),
                    ),
                    onPressed: () {
                      final result = <Map<String, dynamic>>[];

                      for (final invoice in candidates) {
                        final id = invoice['id'].toString();
                        final amount = double.tryParse(
                              controllers[id]?.text.trim() ?? '',
                            ) ??
                            0;

                        if (amount > 0) {
                          if (amount >
                              _asDouble(invoice['outstanding_amount'])) {
                            return;
                          }

                          result.add({
                            'invoice_id': id,
                            'amount': amount,
                          });
                        }
                      }

                      final total = result.fold<double>(
                        0,
                        (sum, item) =>
                            sum + _asDouble(item['amount']),
                      );

                      if (total <= 0 || total > available) return;

                      Navigator.of(dialogContext).pop(result);
                    },
                    child: const Text('Apply Credit'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (allocations == null || allocations.isEmpty) return;

      setState(() => _isSaving = true);

      await Supabase.instance.client.rpc(
        'allocate_account_credit',
        params: {
          'target_credit_id': creditId,
          'allocations_json': allocations,
        },
      );

      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credit allocation saved.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reversePayment(Map<String, dynamic> payment) async {
    final paymentId = payment['id']?.toString();
    if (paymentId == null || payment['status']?.toString() == 'reversed') {
      return;
    }

    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reverse Payment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will remove the payment from the active account balance '
              'and reopen any invoice balance covered by its allocations.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reverse Payment'),
          ),
        ],
      ),
    );

    final reason = controller.text.trim();
    controller.dispose();

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.rpc(
        'reverse_account_payment',
        params: {
          'target_payment_id': paymentId,
          'reversal_reason': reason,
        },
      );

      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment reversed.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reverseCredit(Map<String, dynamic> credit) async {
    final creditId = credit['id']?.toString();
    if (creditId == null || credit['status']?.toString() == 'reversed') {
      return;
    }

    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reverse Credit / Adjustment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will remove the credit from the active account balance '
              'and reopen any invoice balance covered by its allocations.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );

    final reason = controller.text.trim();
    controller.dispose();

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.rpc(
        'reverse_account_credit',
        params: {
          'target_credit_id': creditId,
          'reversal_reason': reason,
        },
      );

      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credit / adjustment reversed.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reviewPendingPaymentSubmission(
    Map<String, dynamic> submission,
    bool confirm,
  ) async {
    final id = submission['id']?.toString();
    if (id == null || _isSaving) return;

    final noteController = TextEditingController();

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: confirm
                              ? const Color(0xFFE8F3EA)
                              : const Color(0xFFF8EAEA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          confirm
                              ? Icons.verified_outlined
                              : Icons.close_rounded,
                          color: confirm
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFB3261E),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          confirm
                              ? 'Confirm Payment Received'
                              : 'Reject Payment Submission',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    confirm
                        ? 'Confirm only after the funds have arrived. '
                            'CutLink will then create the real payment and apply '
                            'the proposed invoice allocations.'
                        : 'Reject this submission if the funds have not arrived '
                            'or the details are incorrect.',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _allocationSummaryRow(
                          'Amount',
                          _money(submission['amount']),
                        ),
                        const SizedBox(height: 8),
                        _allocationSummaryRow(
                          'Payment date',
                          _formatDate(submission['payment_date']),
                        ),
                        const SizedBox(height: 8),
                        _allocationSummaryRow(
                          'Reference',
                          submission['reference']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? submission['reference'].toString()
                              : '—',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: confirm
                          ? 'Confirmation note (optional)'
                          : 'Reason / note (optional)',
                      filled: true,
                      fillColor: const Color(0xFFF8F8F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: confirm
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFB3261E),
                        ),
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true),
                        child: Text(confirm ? 'Confirm Payment' : 'Reject'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    final note = noteController.text.trim();
    noteController.dispose();

    if (proceed != true) return;

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.rpc(
        confirm
            ? 'confirm_butcher_account_payment'
            : 'reject_butcher_account_payment',
        params: {
          'target_submission_id': id,
          'review_note_value': note,
        },
      );

      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              confirm
                  ? 'Payment confirmed and added to the account ledger.'
                  : 'Payment submission rejected.',
            ),
          ),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _pendingPaymentSubmissionsPanel() {
    if (_pendingPaymentSubmissions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3DF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFF9A5B00),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Payment Submissions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'The customer says these payments were made. '
                        'Confirm only after the funds arrive.',
                        style: TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final submission in _pendingPaymentSubmissions)
            _pendingPaymentSubmissionRow(submission),
        ],
      ),
    );
  }

  Widget _pendingPaymentSubmissionRow(Map<String, dynamic> submission) {
    final allocationsRaw =
        submission['customer_payment_submission_allocations'];

    final allocations = allocationsRaw is List
        ? allocationsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final allocated = allocations.fold<double>(
      0,
      (sum, row) => sum + _asDouble(row['amount']),
    );

    final amount = _asDouble(submission['amount']);
    final unallocated =
        (amount - allocated).clamp(0, double.infinity).toDouble();

    final allocationText = allocations.isEmpty
        ? 'General account / statement payment'
        : allocations.map((row) {
            final invoice = row['invoices'];
            final invoiceNumber = invoice is Map
                ? invoice['invoice_number']?.toString() ?? 'Invoice'
                : 'Invoice';
            return '$invoiceNumber ${_money(row['amount'])}';
          }).join(' • ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEA)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.payments_outlined,
            color: Color(0xFF9A5B00),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submission['reference']?.toString().trim().isNotEmpty ==
                          true
                      ? submission['reference'].toString()
                      : 'Customer Payment Submission',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDate(submission['payment_date'])} • '
                  '${_paymentMethodLabel(submission['payment_method']?.toString())}',
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  allocationText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          _ledgerAmountColumn('PAYMENT', _money(amount)),
          const SizedBox(width: 14),
          _ledgerAmountColumn('PROPOSED', _money(allocated)),
          if (unallocated > 0) ...[
            const SizedBox(width: 14),
            _ledgerAmountColumn('UNALLOCATED', _money(unallocated)),
          ],
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _isSaving
                ? null
                : () => _reviewPendingPaymentSubmission(
                      submission,
                      false,
                    ),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSaving
                ? null
                : () => _reviewPendingPaymentSubmission(
                      submission,
                      true,
                    ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text('Confirm Received'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInvoice(Map<String, dynamic> invoice) async {
    final id = invoice['id']?.toString();
    if (id == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierInvoicePage(invoiceId: id),
      ),
    );

    if (mounted) await _loadPage();
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

  String _paymentAllocationStatus(Map<String, dynamic> payment) {
    final id = payment['id']?.toString();
    if (payment['status']?.toString() == 'reversed') return 'Reversed';
    if (id == null) return 'Unallocated';

    final allocated = _allocatedForPayment(id);
    final amount = _asDouble(payment['amount']);

    if (allocated <= 0) return 'Unallocated';
    if (allocated + 0.005 < amount) return 'Partially Allocated';
    return 'Fully Allocated';
  }

  Color _paymentStatusColor(String value) {
    switch (value) {
      case 'Fully Allocated':
        return const Color(0xFF2E7D32);
      case 'Partially Allocated':
        return const Color(0xFF315A8C);
      case 'Reversed':
        return const Color(0xFF777777);
      default:
        return const Color(0xFF315A8C);
    }
  }

  Widget _summaryCard(
    String label,
    String value, {
    Color? valueColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0DD)),
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
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF222222),
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label) {
    final color = _statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _selectionAllocationBanner() {
    final invoice = _selectedInvoice;
    final payment = _selectedPayment;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE1E1DD)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.touch_app_outlined,
            size: 18,
            color: _darkRed,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              invoice == null && payment == null
                  ? 'Select a payment to allocate it across open invoices. '
                      'Optionally select one invoice for a direct allocation.'
                  : payment == null
                      ? 'Invoice selected: '
                          '${invoice?['invoice_number']?.toString() ?? 'None'}'
                          '    •    Select a payment before allocating.'
                      : 'Selected invoice: '
                          '${invoice?['invoice_number']?.toString() ?? 'Any open invoice'}'
                          '    •    Selected payment: '
                          '${payment['reference']?.toString().trim().isNotEmpty == true ? payment['reference'].toString() : _money(payment['amount'])}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (invoice != null || payment != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedInvoiceId = null;
                  _selectedPaymentId = null;
                });
              },
              child: const Text('Clear Selection'),
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
        border: Border.all(color: const Color(0xFFE0E0DD)),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _invoiceFilterMenu(),
              ],
            ),
          ),
          const Divider(height: 1),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
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
                  DataColumn(label: Text('Original Total'), numeric: true),
                  DataColumn(label: Text('Paid'), numeric: true),
                  DataColumn(label: Text('Outstanding'), numeric: true),
                  DataColumn(label: Text('Status')),
                ],
                rows: rows.map((invoice) {
                  final order = invoice['orders'];
                  final orderNumber = order is Map
                      ? order['order_number']?.toString() ?? '—'
                      : '—';
                  final status = _invoiceStatus(invoice);

                  final invoiceId = invoice['id']?.toString();
                  final selectable =
                      _asDouble(invoice['outstanding_amount']) > 0 &&
                      invoice['status']?.toString() != 'void';
                  final selected =
                      invoiceId != null && _selectedInvoiceId == invoiceId;

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
                                    _selectedInvoiceId =
                                        value == true ? invoiceId : null;
                                  });
                                },
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => _openInvoice(invoice),
                          child: Text(
                            invoice['invoice_number']?.toString() ??
                                'Invoice',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _darkRed,
                              decoration: TextDecoration.underline,
                              decorationColor: _darkRed,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(orderNumber)),
                      DataCell(Text(_formatDate(invoice['invoice_date']))),
                      DataCell(Text(_formatDate(invoice['due_date']))),
                      DataCell(Text(_money(invoice['total_amount']))),
                      DataCell(Text(_money(invoice['amount_paid']))),
                      DataCell(
                        Text(
                          _money(invoice['outstanding_amount']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      DataCell(_statusChip(status)),
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
            (entry) => PopupMenuItem(
              value: entry.key,
              child: Text(entry.value),
            ),
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
            _paymentAvailable(payment) > 0)
          {
            'type': 'payment',
            'date': payment['payment_date'],
            'data': payment,
          },
      for (final credit in _credits)
        if (credit['status']?.toString() == 'active' &&
            ((_asDouble(credit['amount']) -
                        _allocatedForCredit(credit['id']?.toString() ?? ''))
                    .clamp(0, double.infinity) >
                0))
          {
            'type': 'credit',
            'date': credit['credit_date'],
            'data': credit,
          },
    ];

    entries.sort((a, b) {
      final ad = _date(a['date']) ?? DateTime(1900);
      final bd = _date(b['date']) ?? DateTime(1900);
      return bd.compareTo(ad);
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              'Unallocated Payments & Credits',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: Text(
                  'No unallocated payments or credits requiring action.',
                  style: TextStyle(color: Color(0xFF777777)),
                ),
              ),
            )
          else
            for (final entry in entries)
              _ledgerRow(entry),
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
      final available = (amount - allocated).clamp(0, double.infinity).toDouble();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFEEEEEA)),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_card_outlined, color: Color(0xFF315A8C)),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['reference']?.toString().trim().isNotEmpty == true
                        ? data['reference'].toString()
                        : 'Account Credit',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${_formatDate(data['credit_date'])} • Credit',
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            _ledgerAmountColumn('AMOUNT', _money(amount)),
            const SizedBox(width: 18),
            _ledgerAmountColumn('ALLOCATED', _money(allocated)),
            const SizedBox(width: 18),
            _ledgerAmountColumn('AVAILABLE', _money(available)),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (data['status']?.toString() == 'reversed'
                        ? const Color(0xFF777777)
                        : const Color(0xFF315A8C))
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                data['status']?.toString() == 'reversed'
                    ? 'Reversed'
                    : (available > 0 ? 'Available' : 'Fully Allocated'),
                style: TextStyle(
                  color: data['status']?.toString() == 'reversed'
                      ? const Color(0xFF777777)
                      : const Color(0xFF315A8C),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (data['status']?.toString() == 'active') ...[
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'allocate') {
                    _openCreditAllocationDialog(data);
                  } else if (value == 'reverse') {
                    _reverseCredit(data);
                  }
                },
                itemBuilder: (_) => [
                  if (available > 0)
                    const PopupMenuItem(
                      value: 'allocate',
                      child: Text('Allocate to Invoices'),
                    ),
                  const PopupMenuItem(
                    value: 'reverse',
                    child: Text('Reverse Credit / Adjustment'),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    final id = data['id']?.toString() ?? '';
    final allocated = _allocatedForPayment(id);
    final amount = _asDouble(data['amount']);
    final unallocated = (amount - allocated).clamp(0, double.infinity).toDouble();
    final status = _paymentAllocationStatus(data);

    final selectablePayment =
        data['status']?.toString() == 'active' && unallocated > 0;
    final selectedPayment =
        id.isNotEmpty && _selectedPaymentId == id;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: selectedPayment
            ? const Color(0xFFF4E5E5).withValues(alpha: 0.45)
            : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEEEEEA)),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selectedPayment,
            onChanged: !selectablePayment
                ? null
                : (value) {
                    setState(() {
                      _selectedPaymentId =
                          value == true ? id : null;
                    });
                  },
          ),
          const SizedBox(width: 2),
          const Icon(Icons.payments_outlined, color: _darkRed),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['reference']?.toString().trim().isNotEmpty == true
                      ? data['reference'].toString()
                      : 'Payment',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${_formatDate(data['payment_date'])} • '
                  '${_paymentMethodLabel(data['payment_method']?.toString())}',
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _ledgerAmountColumn('AMOUNT', _money(amount)),
          const SizedBox(width: 18),
          _ledgerAmountColumn('ALLOCATED', _money(allocated)),
          const SizedBox(width: 18),
          _ledgerAmountColumn('UNALLOCATED', _money(unallocated)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _paymentStatusColor(status).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: _paymentStatusColor(status),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (data['status']?.toString() == 'active') ...[
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'allocate') {
                  _openAllocationDialog(data);
                } else if (value == 'auto') {
                  _autoAllocate(data);
                } else if (value == 'reverse') {
                  _reversePayment(data);
                }
              },
              itemBuilder: (_) => [
                if (unallocated > 0)
                  const PopupMenuItem(
                    value: 'allocate',
                    child: Text('Allocate to Invoices'),
                  ),
                if (unallocated > 0)
                  const PopupMenuItem(
                    value: 'auto',
                    child: Text('Auto Allocate'),
                  ),
                if (unallocated > 0)
                  const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'reverse',
                  child: Text('Reverse Payment'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _ledgerAmountColumn(String label, String value) {
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
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
              const Icon(Icons.error_outline, size: 58, color: _darkRed),
              const SizedBox(height: 14),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loadPage,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 950;

        final summary = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 190,
              child: _summaryCard(
                'Outstanding',
                _money(_outstanding),
                valueColor: _outstanding > 0 ? _darkRed : null,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            SizedBox(
              width: 190,
              child: _summaryCard(
                'Overdue',
                _money(_overdue),
                valueColor:
                    _overdue > 0 ? const Color(0xFFB3261E) : null,
                icon: Icons.warning_amber_rounded,
              ),
            ),
            SizedBox(
              width: 190,
              child: _summaryCard(
                'Due Soon',
                _money(_dueSoon),
                valueColor:
                    _dueSoon > 0 ? const Color(0xFF9A5B00) : null,
                icon: Icons.schedule_outlined,
              ),
            ),
            SizedBox(
              width: 190,
              child: _summaryCard(
                'Unallocated Payments',
                _money(_unallocatedPayments),
                valueColor: _unallocatedPayments > 0
                    ? const Color(0xFF315A8C)
                    : null,
                icon: Icons.payments_outlined,
              ),
            ),
            SizedBox(
              width: 190,
              child: _summaryCard(
                'Credit Available',
                _money(_creditAvailable),
                valueColor:
                    _creditAvailable > 0 ? const Color(0xFF315A8C) : null,
                icon: Icons.add_card_outlined,
              ),
            ),
          ],
        );

        final termsPanel = Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0DD)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: _darkRed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Terms',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF777777),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _paymentTerms(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _paymentTermsPlainEnglish(),
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
        );

        return RefreshIndicator(
          onRefresh: _loadPage,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 10),
                      termsPanel,
                      const SizedBox(height: 12),
                      if (_pendingPaymentSubmissions.isNotEmpty) ...[
                        _pendingPaymentSubmissionsPanel(),
                        const SizedBox(height: 12),
                      ],
                      _selectionAllocationBanner(),
                      const SizedBox(height: 12),
                      _invoiceTable(),
                      const SizedBox(height: 12),
                      _paymentsAndCredits(),
                      if (!desktop) const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _customerName(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            if (!_isLoading)
              const Text(
                'Customer Account',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF777777),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _openStatement,
            icon: const Icon(Icons.description_outlined),
            label: const Text('View Statement'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _isLoading || _isSaving
                ? null
                : _recordCreditOrAdjustment,
            icon: const Icon(Icons.add_card_outlined),
            label: const Text('Credit / Adjustment'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _isLoading || _isSaving
                ? null
                : () => _recordPayment(),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Record Payment'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _canAllocateSelectedPayment
                ? _allocateSelectedPayment
                : null,
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            icon: const Icon(Icons.link_outlined),
            label: const Text('Allocate Payment'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadPage,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }
}
