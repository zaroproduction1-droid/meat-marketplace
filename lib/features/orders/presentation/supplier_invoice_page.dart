import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/invoice_pdf_service.dart';

class SupplierInvoicePage extends StatefulWidget {
  const SupplierInvoicePage({super.key, required this.orderId});

  final String orderId;

  @override
  State<SupplierInvoicePage> createState() => _SupplierInvoicePageState();
}

class _SupplierInvoicePageState extends State<SupplierInvoicePage> {
  static const _darkRed = Color(0xFF741C1C);

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _items = [];

  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      final created = await client.rpc(
        'create_or_get_invoice_from_order',
        params: {'target_order_id': widget.orderId},
      );

      final invoice = Map<String, dynamic>.from(created as Map);

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
            notes,
            issued_at,
            paid_at,
            voided_at,
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
            updated_at,
            invoice_items(
              id,
              order_item_id,
              product_id,
              product_name_snapshot,
              sku_snapshot,
              ordered_quantity,
              ordered_quantity_unit,
              supplied_quantity,
              supplied_quantity_unit,
              catch_weight_snapshot,
              actual_weight,
              actual_weight_unit,
              locked_unit_price,
              price_basis,
              line_amount,
              notes_snapshot
            )
          ''')
          .eq('id', invoice['id'])
          .single();

      if (!mounted) {
        return;
      }

      final loaded = Map<String, dynamic>.from(response);
      final rawItems = loaded['invoice_items'];

      _notesController.text = loaded['notes']?.toString() ?? '';

      setState(() {
        _invoice = loaded;
        _items = rawItems is List
            ? rawItems
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
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
    final number = _asDouble(value);
    final fixed = number.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final decimal = parts.last;

    final buffer = StringBuffer();

    for (var index = 0; index < whole.length; index++) {
      final remaining = whole.length - index;
      buffer.write(whole[index]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return '\$${buffer.toString()}.$decimal';
  }

  String _formatNumber(dynamic value) {
    final number = _asDouble(value);

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _unitLabel(String? value) {
    return switch (value) {
      'carton' => 'cartons',
      'kilogram' => 'kg',
      'unit' => 'units',
      _ => value ?? '',
    };
  }

  String _basisLabel(String? value) {
    return switch (value) {
      'carton' => 'carton',
      'kilogram' => 'kg',
      'unit' => 'unit',
      _ => value ?? '',
    };
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

  String _paymentText() {
    final method = _invoice?['payment_method_snapshot']?.toString();

    switch (method) {
      case 'account':
        final days = _invoice?['payment_terms_days_snapshot'];
        return '${_formatNumber(days)} day account';
      case 'prepaid':
        return 'Prepaid';
      case 'cod':
        return 'COD';
      default:
        return 'Not recorded';
    }
  }

  bool get _taxConfigured =>
      _invoice?['tax_status']?.toString() == 'configured';

  double get _incGstTotal => _asDouble(_invoice?['total_amount']);

  double get _gstIncluded => _asDouble(_invoice?['tax_amount']);

  double get _exGstTotal => _incGstTotal - _gstIncluded;

  bool get _canIssue =>
      _invoice?['status']?.toString() == 'ready' &&
      _taxConfigured &&
      _invoice?['total_amount'] != null;

  double get _amountPaid => _asDouble(_invoice?['amount_paid']);

  double get _amountOutstanding {
    final outstanding = _incGstTotal - _amountPaid;
    return outstanding < 0 ? 0 : outstanding;
  }

  bool get _sentToButcher => _invoice?['sent_to_butcher_at'] != null;

  bool get _hasButcherAccount =>
      (_invoice?['butcher_business_id']?.toString().trim() ?? '').isNotEmpty;

  bool get _canSendToButcher {
    final status = _invoice?['status']?.toString();
    return _hasButcherAccount &&
        !_sentToButcher &&
        (status == 'issued' || status == 'part_paid' || status == 'paid');
  }

  bool get _canRecordPayment {
    final status = _invoice?['status']?.toString();
    return (status == 'issued' || status == 'part_paid') &&
        _amountOutstanding > 0;
  }

  Future<void> _sendInvoiceToButcher() async {
    final invoiceId = _invoice?['id']?.toString();

    if (invoiceId == null || !_canSendToButcher || _isSaving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send Invoice to Customer?'),
        content: Text(
          'Send ${_invoice?['invoice_number'] ?? 'this invoice'} to '
          '${_invoice?['customer_name_snapshot'] ?? 'the customer'} inside CutLink?\n\n'
          'It will appear in their Accounts section and remain linked to this supplier invoice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send Invoice'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.rpc(
        'send_invoice_to_butcher',
        params: {'target_invoice_id': invoiceId},
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice sent to the butcher’s CutLink account.'),
        ),
      );

      await _loadPage();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _recordPayment() async {
    final invoiceId = _invoice?['id']?.toString();

    if (invoiceId == null || !_canRecordPayment || _isSaving) {
      return;
    }

    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding: ${_money(_amountOutstanding)}'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Payment received',
                prefixText: r'$',
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
              final parsed = double.tryParse(
                controller.text.replaceAll(',', '').trim(),
              );

              if (parsed == null || parsed <= 0) {
                return;
              }

              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (amount == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.rpc(
        'record_invoice_payment',
        params: {'target_invoice_id': invoiceId, 'payment_amount': amount},
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment recorded.')));

      await _loadPage();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool get _hasPendingCustomerPaymentClaim =>
      _invoice?['customer_payment_claim_status']?.toString() == 'pending';

  Future<void> _reviewCustomerPaymentClaim(bool confirm) async {
    final invoiceId = _invoice?['id']?.toString();

    if (invoiceId == null || !_hasPendingCustomerPaymentClaim || _isSaving) {
      return;
    }

    final noteController = TextEditingController();
    final claimedAmount = _asDouble(
      _invoice?['customer_payment_claimed_amount'],
    );

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(confirm ? 'Confirm Payment?' : 'Reject Payment Claim?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              confirm
                  ? 'The customer says they paid ${_money(claimedAmount)}. Confirm only after checking that the payment has arrived.'
                  : 'Reject this payment claim if the funds have not arrived or the details are incorrect.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: confirm
                    ? 'Confirmation note (optional)'
                    : 'Reason / note (optional)',
                border: const OutlineInputBorder(),
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
              backgroundColor: confirm ? const Color(0xFF2E7D32) : _darkRed,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirm ? 'Confirm Payment' : 'Reject Claim'),
          ),
        ],
      ),
    );

    final note = noteController.text.trim();
    noteController.dispose();

    if (proceed != true) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.rpc(
        confirm
            ? 'confirm_customer_payment_claim'
            : 'reject_customer_payment_claim',
        params: {'target_invoice_id': invoiceId, 'review_note': note},
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirm
                ? 'Payment confirmed. The invoice balance has been updated.'
                : 'Payment claim rejected.',
          ),
        ),
      );

      await _loadPage();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveNotes() async {
    final id = _invoice?['id']?.toString();

    if (id == null || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await Supabase.instance.client
          .from('invoices')
          .update({
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          })
          .eq('id', id)
          .select()
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _invoice = Map<String, dynamic>.from(updated);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invoice notes saved.')));
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _issueInvoice() async {
    final invoiceId = _invoice?['id']?.toString();

    if (invoiceId == null || !_canIssue || _isSaving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Issue Invoice?'),
        content: Text(
          'Issue ${_invoice?['invoice_number'] ?? 'this invoice'} to '
          '${_invoice?['customer_name_snapshot'] ?? 'the customer'}?\n\n'
          'After issuing, the tax and final invoice total are locked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            child: const Text('Issue Invoice'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await Supabase.instance.client.rpc(
        'issue_invoice',
        params: {'target_invoice_id': invoiceId},
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _invoice = Map<String, dynamic>.from(updated as Map);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invoice issued.')));

      await _loadPage();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _refreshInvoicePartySnapshots() async {
    final invoiceId = _invoice?['id']?.toString();

    if (invoiceId == null || invoiceId.isEmpty) {
      return;
    }

    final result = await Supabase.instance.client.rpc(
      'snapshot_invoice_party_details',
      params: {'target_invoice_id': invoiceId},
    );

    if (result is Map) {
      _invoice = Map<String, dynamic>.from(result);
    }
  }

  Future<void> _printInvoice() async {
    if (_invoice == null || _isSaving) {
      return;
    }

    try {
      setState(() => _isSaving = true);
      await _refreshInvoicePartySnapshots();

      if (mounted) {
        setState(() {});
      }

      await Printing.layoutPdf(
        name: '${_invoice?['invoice_number'] ?? 'CutLink-Invoice'}.pdf',
        onLayout: (_) =>
            CutLinkInvoicePdf.build(invoice: _invoice!, items: _items),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create invoice PDF: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          _invoice?['invoice_number']?.toString() ?? 'Supplier Invoice',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _isLoading || _invoice == null ? null : _printInvoice,
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print Invoice'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoading ? null : _loadPage,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
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
                onPressed: _loadPage,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final status = _invoice?['status']?.toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _invoice?['invoice_number']?.toString() ?? 'Invoice',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.receipt_long_outlined, size: 17),
                  label: Text(_statusLabel(status)),
                ),
                const Chip(
                  avatar: Icon(Icons.receipt_outlined, size: 17),
                  label: Text('GST inclusive'),
                ),
                if (_sentToButcher)
                  const Chip(
                    avatar: Icon(Icons.mark_email_read_outlined, size: 17),
                    label: Text('Sent to customer'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _invoice?['customer_name_snapshot']?.toString() ?? 'Customer',
              style: const TextStyle(
                color: _darkRed,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 32,
                  runSpacing: 14,
                  children: [
                    _InfoValue(
                      label: 'Invoice date',
                      value: _invoice?['invoice_date']?.toString() ?? '',
                    ),
                    _InfoValue(
                      label: 'Due date',
                      value: _invoice?['due_date']?.toString() ?? '',
                    ),
                    _InfoValue(label: 'Payment', value: _paymentText()),
                    if ((_invoice?['customer_reference_snapshot']
                                ?.toString()
                                .trim() ??
                            '')
                        .isNotEmpty)
                      _InfoValue(
                        label: 'Customer reference',
                        value: _invoice!['customer_reference_snapshot']
                            .toString(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Invoice Items',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final item in _items) _buildItemCard(item),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _TotalRow(
                          label: 'Products inc GST',
                          value: _money(_invoice?['products_subtotal']),
                        ),
                        _TotalRow(
                          label: 'Delivery inc GST',
                          value: _asDouble(_invoice?['delivery_fee']) == 0
                              ? 'Free'
                              : _money(_invoice?['delivery_fee']),
                        ),
                        _TotalRow(
                          label: 'GST included',
                          value: _money(_gstIncluded),
                        ),
                        _TotalRow(
                          label: 'Total ex GST',
                          value: _money(_exGstTotal),
                        ),
                        const Divider(),
                        _TotalRow(
                          label: 'Total inc GST',
                          value: _money(_incGstTotal),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_hasPendingCustomerPaymentClaim) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFFE0C26C)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.notification_important_outlined,
                            color: Color(0xFF9A6700),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Customer Marked This Invoice as Paid',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Claimed amount: ${_money(_asDouble(_invoice?['customer_payment_claimed_amount']))}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((_invoice?['customer_payment_claimed_note']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Customer note: ${_invoice?['customer_payment_claimed_note']}',
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Check your bank/account before confirming. Confirming updates the paid balance on both the supplier and butcher sides.',
                        style: TextStyle(color: Color(0xFF666666), height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _reviewCustomerPaymentClaim(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Confirm Payment'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _reviewCustomerPaymentClaim(false),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject Claim'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 28,
                      runSpacing: 14,
                      children: [
                        _InfoValue(
                          label: 'Invoice total',
                          value: _money(_incGstTotal),
                        ),
                        _InfoValue(
                          label: 'Amount paid',
                          value: _money(_amountPaid),
                        ),
                        _InfoValue(
                          label: 'Outstanding',
                          value: _money(_amountOutstanding),
                        ),
                        _InfoValue(
                          label: 'Customer access',
                          value: !_hasButcherAccount
                              ? 'External customer'
                              : _sentToButcher
                              ? 'Invoice sent'
                              : 'Not sent yet',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: _canSendToButcher && !_isSaving
                              ? _sendInvoiceToButcher
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _darkRed,
                          ),
                          icon: Icon(
                            _sentToButcher
                                ? Icons.mark_email_read_outlined
                                : Icons.send_outlined,
                          ),
                          label: Text(
                            !_hasButcherAccount
                                ? 'No CutLink Account'
                                : _sentToButcher
                                ? 'Sent to Customer'
                                : 'Send Invoice to Customer',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _canRecordPayment && !_isSaving
                              ? _recordPayment
                              : null,
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(
                            _amountOutstanding <= 0
                                ? 'Paid in Full'
                                : 'Record Payment',
                          ),
                        ),
                      ],
                    ),
                    if (!_hasButcherAccount) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'This invoice belongs to an external customer, so it cannot be sent into a CutLink butcher account.',
                        style: TextStyle(color: Color(0xFF666666), height: 1.4),
                      ),
                    ] else if (!_sentToButcher && status == 'ready') ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Issue the invoice first, then send it to the customer’s Accounts section.',
                        style: TextStyle(color: Color(0xFF666666), height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invoice Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 6,
                      enabled: status != 'void' && !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: status != 'void' && !_isSaving
                          ? _saveNotes
                          : null,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Notes'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _canIssue && !_isSaving ? _issueInvoice : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _darkRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.send_outlined),
                label: Text(
                  status == 'issued'
                      ? 'Invoice Issued'
                      : _canIssue
                      ? 'Issue Invoice'
                      : 'Invoice Not Ready',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final catchWeight = item['catch_weight_snapshot'] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 650;

            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name_snapshot']?.toString() ?? 'Product',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((item['sku_snapshot']?.toString().trim() ?? '').isNotEmpty)
                  Text(
                    'SKU: ${item['sku_snapshot']}',
                    style: const TextStyle(color: Color(0xFF666666)),
                  ),
                const SizedBox(height: 7),
                Text(
                  'Supplied: ${_formatNumber(item['supplied_quantity'])} '
                  '${_unitLabel(item['supplied_quantity_unit']?.toString())}',
                ),
                if (catchWeight) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Actual weight: ${_formatNumber(item['actual_weight'])} kg',
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Locked rate: ${_money(item['locked_unit_price'])}'
                  '${_basisLabel(item['price_basis']?.toString()).isEmpty ? '' : ' / ${_basisLabel(item['price_basis']?.toString())}'}',
                  style: const TextStyle(color: Color(0xFF555555)),
                ),
              ],
            );

            final right = Text(
              _money(item['line_amount']),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [left, const SizedBox(height: 12), right],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                right,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoValue extends StatelessWidget {
  const _InfoValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 14,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          const SizedBox(width: 20),
          Text(value, style: style),
        ],
      ),
    );
  }
}
