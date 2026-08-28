import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/invoice_pdf_service.dart';

class SupplierInvoicePage extends StatefulWidget {
  const SupplierInvoicePage({
    super.key,
    this.orderId,
    this.invoiceId,
    this.openPdfOnLoad = false,
  }) : assert(
         (orderId != null && orderId != '') ||
             (invoiceId != null && invoiceId != ''),
         'Either orderId or invoiceId is required.',
       );

  final String? orderId;
  final String? invoiceId;
  final bool openPdfOnLoad;

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
  bool _didAutoOpenPdf = false;

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

      Map<String, dynamic> invoice;

      final directInvoiceId = widget.invoiceId;

      if (directInvoiceId != null && directInvoiceId.isNotEmpty) {
        invoice = {'id': directInvoiceId};
      } else {
        final orderId = widget.orderId;

        if (orderId == null || orderId.isEmpty) {
          throw Exception('Invoice could not be identified.');
        }

        final existingRows = await client
            .from('invoices')
            .select('id')
            .eq('order_id', orderId)
            .order('created_at', ascending: false)
            .limit(1);

        if (existingRows.isEmpty) {
          throw Exception(
            'No invoice exists for this order yet. Finish the Work Order to create the invoice.',
          );
        }

        invoice = Map<String, dynamic>.from(existingRows.first);
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

      final baseItems = rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];

      final enrichedItems = await _enrichInvoiceItems(baseItems);

      if (!mounted) {
        return;
      }

      _notesController.text = loaded['notes']?.toString() ?? '';

      setState(() {
        _invoice = loaded;
        _items = enrichedItems;
        _isLoading = false;
      });

      if (widget.openPdfOnLoad && !_didAutoOpenPdf) {
        _didAutoOpenPdf = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _printInvoice();
          }
        });
      }
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

  Future<List<Map<String, dynamic>>> _enrichInvoiceItems(
    List<Map<String, dynamic>> items,
  ) async {
    final productIds = items
        .map((item) => item['product_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (productIds.isEmpty) {
      return items;
    }

    final client = Supabase.instance.client;

    final productRows = await client
        .from('products')
        .select(
          'id, meat_animal_id, meat_section_id, meat_specification_id, meat_grade_id',
        )
        .inFilter('id', productIds);

    final products = <String, Map<String, dynamic>>{};
    final animalIds = <String>{};
    final sectionIds = <String>{};
    final specificationIds = <String>{};
    final gradeIds = <String>{};

    for (final raw in productRows) {
      final row = Map<String, dynamic>.from(raw);
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;

      products[id] = row;

      final animalId = row['meat_animal_id']?.toString();
      final sectionId = row['meat_section_id']?.toString();
      final specificationId = row['meat_specification_id']?.toString();
      final gradeId = row['meat_grade_id']?.toString();

      if (animalId != null && animalId.isNotEmpty) animalIds.add(animalId);
      if (sectionId != null && sectionId.isNotEmpty) sectionIds.add(sectionId);
      if (specificationId != null && specificationId.isNotEmpty) {
        specificationIds.add(specificationId);
      }
      if (gradeId != null && gradeId.isNotEmpty) gradeIds.add(gradeId);
    }

    Future<Map<String, Map<String, dynamic>>> loadByIds(
      String table,
      Set<String> ids,
      String select,
    ) async {
      if (ids.isEmpty) return <String, Map<String, dynamic>>{};

      final rows = await client
          .from(table)
          .select(select)
          .inFilter('id', ids.toList());

      return {
        for (final raw in rows)
          if (raw['id'] != null)
            raw['id'].toString(): Map<String, dynamic>.from(raw),
      };
    }

    final results = await Future.wait([
      loadByIds('meat_animals', animalIds, 'id, code, name'),
      loadByIds('meat_sections', sectionIds, 'id, code, name'),
      loadByIds('meat_specifications', specificationIds, 'id, name, ham_code'),
      loadByIds('meat_grades', gradeIds, 'id, code, name'),
    ]);

    final animals = results[0];
    final sections = results[1];
    final specifications = results[2];
    final grades = results[3];

    return items.map((item) {
      final enriched = Map<String, dynamic>.from(item);
      final productId = item['product_id']?.toString();
      final product = productId == null ? null : products[productId];

      if (product == null) return enriched;

      final animal = animals[product['meat_animal_id']?.toString()];
      final section = sections[product['meat_section_id']?.toString()];
      final specification =
          specifications[product['meat_specification_id']?.toString()];
      final grade = grades[product['meat_grade_id']?.toString()];

      enriched['animal_name'] = animal?['name'];
      enriched['animal_code'] = animal?['code'];
      enriched['section_name'] = section?['name'];
      enriched['section_code'] = section?['code'];
      enriched['specification_name'] = specification?['name'];
      enriched['ham_code'] = specification?['ham_code'];
      enriched['grade_code'] = grade?['code'];
      enriched['grade_name'] = grade?['name'];

      return enriched;
    }).toList();
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

      final updatedInvoice = Map<String, dynamic>.from(_invoice ?? const {});
      updatedInvoice['sent_to_butcher_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();

      setState(() {
        _invoice = updatedInvoice;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice sent to the butcher’s CutLink account.'),
          ),
        );
      });
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

  Future<Uint8List> _buildInvoicePdf() async {
    final invoice = _invoice;
    if (invoice == null) {
      throw Exception('Invoice is not loaded.');
    }

    return CutLinkInvoicePdf.build(invoice: invoice, items: _items);
  }

  Future<void> _printInvoice() async {
    if (_invoice == null || _isSaving) {
      return;
    }

    try {
      await Printing.layoutPdf(
        name: '${_invoice?['invoice_number'] ?? 'CutLink-Invoice'}.pdf',
        onLayout: (_) => _buildInvoicePdf(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create invoice PDF: $error')),
        );
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

    String clean(dynamic value, {String fallback = '—'}) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }

    String address({
      required dynamic line1,
      dynamic line2,
      dynamic suburb,
      dynamic state,
      dynamic postcode,
    }) {
      return [
        clean(line1, fallback: ''),
        clean(line2, fallback: ''),
        [
          clean(suburb, fallback: ''),
          clean(state, fallback: ''),
          clean(postcode, fallback: ''),
        ].where((part) => part.isNotEmpty).join(' '),
      ].where((part) => part.isNotEmpty).join(', ');
    }

    Widget sectionTitle(String title, {IconData? icon}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: _darkRed),
              const SizedBox(width: 7),
            ],
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    Widget fact(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final customerAddress = address(
      line1: _invoice?['customer_billing_address_line_1_snapshot'],
      line2: _invoice?['customer_billing_address_line_2_snapshot'],
      suburb: _invoice?['customer_billing_suburb_snapshot'],
      state: _invoice?['customer_billing_state_snapshot'],
      postcode: _invoice?['customer_billing_postcode_snapshot'],
    );

    Widget customerSummaryPanel() {
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
            sectionTitle('Customer', icon: Icons.business_outlined),
            fact('Business', clean(_invoice?['customer_name_snapshot'])),
            if (clean(
              _invoice?['customer_abn_snapshot'],
              fallback: '',
            ).isNotEmpty)
              fact('ABN', clean(_invoice?['customer_abn_snapshot'])),
            if (clean(
              _invoice?['customer_email_snapshot'],
              fallback: '',
            ).isNotEmpty)
              fact('Email', clean(_invoice?['customer_email_snapshot'])),
            if (clean(
              _invoice?['customer_phone_snapshot'],
              fallback: '',
            ).isNotEmpty)
              fact('Phone', clean(_invoice?['customer_phone_snapshot'])),
            if (customerAddress.isNotEmpty) fact('Billing', customerAddress),
          ],
        ),
      );
    }

    Widget invoiceSummaryPanel() {
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
            sectionTitle('Invoice Summary', icon: Icons.receipt_long_outlined),
            fact('Invoice', clean(_invoice?['invoice_number'])),
            fact('Invoice date', clean(_invoice?['invoice_date'])),
            fact('Due date', clean(_invoice?['due_date'])),
            fact('Payment', _paymentText()),
            if (clean(
              _invoice?['customer_reference_snapshot'],
              fallback: '',
            ).isNotEmpty)
              fact(
                'Customer ref',
                clean(_invoice?['customer_reference_snapshot']),
              ),
          ],
        ),
      );
    }

    Widget itemsPanel() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 19,
                    color: _darkRed,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Invoice Items',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text(
                    '${_items.length} line${_items.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No invoice items.',
                        style: TextStyle(color: Color(0xFF777777)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        return _buildItemCard(_items[index]);
                      },
                    ),
            ),
          ],
        ),
      );
    }

    Widget totalsActionsPanel() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sectionTitle('Totals', icon: Icons.calculate_outlined),
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
              _TotalRow(label: 'GST included', value: _money(_gstIncluded)),
              _TotalRow(label: 'Total ex GST', value: _money(_exGstTotal)),
              const Divider(height: 16),
              _TotalRow(
                label: 'Total inc GST',
                value: _money(_incGstTotal),
                bold: true,
              ),
              _TotalRow(label: 'Amount paid', value: _money(_amountPaid)),
              _TotalRow(
                label: 'Outstanding',
                value: _money(_amountOutstanding),
                bold: true,
              ),

              if (_hasPendingCustomerPaymentClaim) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE0C26C)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer marked this invoice as paid',
                        style: TextStyle(
                          color: Color(0xFF9A6700),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Claimed ${_money(_asDouble(_invoice?['customer_payment_claimed_amount']))}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (clean(
                        _invoice?['customer_payment_claimed_note'],
                        fallback: '',
                      ).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          clean(_invoice?['customer_payment_claimed_note']),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => _reviewCustomerPaymentClaim(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                              child: const Text('Confirm'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => _reviewCustomerPaymentClaim(false),
                              child: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _canSendToButcher && !_isSaving
                    ? _sendInvoiceToButcher
                    : null,
                style: FilledButton.styleFrom(backgroundColor: _darkRed),
                icon: Icon(
                  _sentToButcher
                      ? Icons.mark_email_read_outlined
                      : Icons.send_outlined,
                ),
                label: Text(
                  !_hasButcherAccount
                      ? 'External Customer'
                      : _sentToButcher
                      ? 'Sent to Customer'
                      : 'Send Invoice to Customer',
                ),
              ),
              const SizedBox(height: 7),
              OutlinedButton.icon(
                onPressed: _canRecordPayment && !_isSaving
                    ? _recordPayment
                    : null,
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  _amountOutstanding <= 0 ? 'Paid in Full' : 'Record Payment',
                ),
              ),

              if (clean(
                    _invoice?['bank_name_snapshot'],
                    fallback: '',
                  ).isNotEmpty ||
                  clean(
                    _invoice?['bank_account_name_snapshot'],
                    fallback: '',
                  ).isNotEmpty ||
                  clean(
                    _invoice?['bank_bsb_snapshot'],
                    fallback: '',
                  ).isNotEmpty ||
                  clean(
                    _invoice?['bank_account_number_snapshot'],
                    fallback: '',
                  ).isNotEmpty ||
                  clean(
                    _invoice?['payment_instructions_snapshot'],
                    fallback: '',
                  ).isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                sectionTitle(
                  'Payment Details',
                  icon: Icons.account_balance_outlined,
                ),
                if (clean(
                  _invoice?['bank_name_snapshot'],
                  fallback: '',
                ).isNotEmpty)
                  fact('Bank', clean(_invoice?['bank_name_snapshot'])),
                if (clean(
                  _invoice?['bank_account_name_snapshot'],
                  fallback: '',
                ).isNotEmpty)
                  fact(
                    'Account name',
                    clean(_invoice?['bank_account_name_snapshot']),
                  ),
                if (clean(
                  _invoice?['bank_bsb_snapshot'],
                  fallback: '',
                ).isNotEmpty)
                  fact('BSB', clean(_invoice?['bank_bsb_snapshot'])),
                if (clean(
                  _invoice?['bank_account_number_snapshot'],
                  fallback: '',
                ).isNotEmpty)
                  fact(
                    'Account no.',
                    clean(_invoice?['bank_account_number_snapshot']),
                  ),
                if (clean(
                  _invoice?['payment_instructions_snapshot'],
                  fallback: '',
                ).isNotEmpty)
                  fact(
                    'Instructions',
                    clean(_invoice?['payment_instructions_snapshot']),
                  ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              sectionTitle('Invoice Notes', icon: Icons.notes_outlined),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                enabled: status != 'void' && !_isSaving,
                decoration: const InputDecoration(
                  hintText: 'Invoice notes',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 7),
              OutlinedButton.icon(
                onPressed: status != 'void' && !_isSaving ? _saveNotes : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Notes'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _canIssue && !_isSaving ? _issueInvoice : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _darkRed,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.task_alt),
                label: Text(
                  status == 'issued'
                      ? 'Invoice Issued'
                      : _canIssue
                      ? 'Issue Invoice'
                      : 'Invoice Not Ready',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0DD)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
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
                Text(
                  _invoice?['invoice_number']?.toString() ?? 'Invoice',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  clean(_invoice?['customer_name_snapshot']),
                  style: const TextStyle(
                    color: _darkRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(_statusLabel(status)),
          ),
          const SizedBox(width: 6),
          const Chip(
            visualDensity: VisualDensity.compact,
            label: Text('GST inclusive'),
          ),
          if (_sentToButcher) ...[
            const SizedBox(width: 6),
            const Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.mark_email_read_outlined, size: 16),
              label: Text('Sent'),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;

        if (!desktop) {
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              header,
              const SizedBox(height: 10),
              customerSummaryPanel(),
              const SizedBox(height: 10),
              invoiceSummaryPanel(),
              const SizedBox(height: 10),
              SizedBox(height: 460, child: itemsPanel()),
              const SizedBox(height: 10),
              totalsActionsPanel(),
            ],
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  header,
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: customerSummaryPanel()),
                      const SizedBox(width: 12),
                      Expanded(child: invoiceSummaryPanel()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: itemsPanel()),
                        const SizedBox(width: 12),
                        SizedBox(width: 350, child: totalsActionsPanel()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final catchWeight = item['catch_weight_snapshot'] == true;

    final gradeCode = item['grade_code']?.toString().trim() ?? '';
    final gradeName = item['grade_name']?.toString().trim() ?? '';
    final specification = item['specification_name']?.toString().trim() ?? '';
    final hamCode = item['ham_code']?.toString().trim() ?? '';
    final section = item['section_name']?.toString().trim() ?? '';
    final animal = item['animal_name']?.toString().trim() ?? '';

    final gradeLabel = [
      gradeCode,
      if (gradeName.isNotEmpty && gradeName != gradeCode) gradeName,
    ].where((value) => value.isNotEmpty).join(' — ');

    final specificationLabel = [
      specification,
      if (hamCode.isNotEmpty) 'HAM $hamCode',
    ].where((value) => value.isNotEmpty).join(' • ');

    Widget pill(String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F1F1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE1D3D3)),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: _darkRed,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    Widget metric(String label, String value) {
      return SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    final ordered =
        '${_formatNumber(item['ordered_quantity'])} '
        '${_unitLabel(item['ordered_quantity_unit']?.toString())}';
    final supplied =
        '${_formatNumber(item['supplied_quantity'])} '
        '${_unitLabel(item['supplied_quantity_unit']?.toString())}';
    final rate =
        '${_money(item['locked_unit_price'])}'
        '${_basisLabel(item['price_basis']?.toString()).isEmpty ? '' : ' / ${_basisLabel(item['price_basis']?.toString())}'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBF9),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE2E2DE)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;

          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['product_name_snapshot']?.toString() ?? 'Product',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if ((item['sku_snapshot']?.toString().trim() ?? '')
                  .isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'SKU ${item['sku_snapshot']}',
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 10.5,
                  ),
                ),
              ],
              if (gradeLabel.isNotEmpty ||
                  specificationLabel.isNotEmpty ||
                  section.isNotEmpty ||
                  animal.isNotEmpty) ...[
                const SizedBox(height: 7),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    if (gradeLabel.isNotEmpty) pill('Grade: $gradeLabel'),
                    if (specificationLabel.isNotEmpty) pill(specificationLabel),
                    if (section.isNotEmpty) pill(section),
                    if (animal.isNotEmpty) pill(animal),
                  ],
                ),
              ],
            ],
          );

          final metrics = Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              metric('ORDERED', ordered),
              metric('SUPPLIED', supplied),
              if (catchWeight)
                metric(
                  'ACTUAL WEIGHT',
                  '${_formatNumber(item['actual_weight'])} kg',
                ),
              metric('LOCKED RATE', rate),
            ],
          );

          final amount = Column(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              const Text(
                'LINE TOTAL INC GST',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _money(item['line_amount']),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 10),
                metrics,
                const SizedBox(height: 10),
                amount,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: identity),
              const SizedBox(width: 14),
              Expanded(flex: 5, child: metrics),
              const SizedBox(width: 12),
              amount,
            ],
          );
        },
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
