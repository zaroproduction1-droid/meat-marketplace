import '../services/document_product_details.dart';
import '../services/document_product_loader.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/quote_pdf_service.dart';
import 'supplier_work_order_page.dart';
import '../../../shared/widgets/zoomable_pdf_preview.dart';

class SupplierQuotePage extends StatefulWidget {
  const SupplierQuotePage({super.key, required this.orderId});

  final String orderId;

  @override
  State<SupplierQuotePage> createState() => _SupplierQuotePageState();
}

class _SupplierQuotePageState extends State<SupplierQuotePage> {
  static const _darkRed = Color(0xFF741C1C);
  bool _loading = true;
  String? _error;
  int _tab = 0;
  Map<String, dynamic>? _quote;
  Map<String, dynamic> _supplier = {};
  Map<String, dynamic> _supplierProfile = {};
  Map<String, dynamic> _customer = {};
  Uint8List? _supplierLogoBytes;
  List<Map<String, dynamic>> _items = [];
  Map<String, String> _privateComments = {};
  String? _selectedLineId;
  String? _lineAction;
  String? _selectedDiscountType;
  bool _savingLine = false;
  bool _convertingToWorkOrder = false;
  final _lineEditorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lineEditorController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final raw = await client
          .from('orders')
          .select('''
        id, order_number, quote_number, quote_revision, quote_last_saved_at,
        status, order_source, source_reference, customer_reference,
        customer_contact_name_snapshot,
        delivery_notes, internal_notes, payment_method_snapshot,
        payment_terms_days_snapshot, fulfilment_method,
        requested_fulfilment_date, requested_fulfilment_time, delivery_fee,
        supplier_business_id, created_at, updated_at,
        supplier_customer_accounts(
          customer_name, legal_name, contact_name, email, phone, abn,
          billing_address_line_1, billing_address_line_2,
          billing_suburb, billing_state, billing_postcode,
          delivery_address_line_1, delivery_address_line_2,
          delivery_suburb, delivery_state, delivery_postcode
        ),
        order_items(
          id, product_id, product_name_snapshot, product_details_snapshot, sku_snapshot, quantity, quantity_unit,
          unit_price, price_basis, line_subtotal, catch_weight_snapshot, notes,
          discount_type, discount_value, discount_amount, public_comment
        )
      ''')
          .eq('id', widget.orderId)
          .single();
      final quote = Map<String, dynamic>.from(raw);
      if (quote['status']?.toString() != 'draft') {
        throw Exception('This document is no longer an open quote.');
      }
      final supplierRaw = await client
          .from('businesses')
          .select('''
        trading_name, legal_name, abn, business_email, business_phone,
        address_line_1, address_line_2, suburb, state, postcode, logo_path
      ''')
          .eq('id', quote['supplier_business_id'])
          .single();

      final supplierProfileRaw = await client
          .from('supplier_invoice_profiles')
          .select()
          .eq('supplier_business_id', quote['supplier_business_id'])
          .maybeSingle();

      Uint8List? logoBytes;
      final logoPath = supplierRaw['logo_path']?.toString().trim() ?? '';
      if (logoPath.isNotEmpty) {
        try {
          logoBytes = await client.storage
              .from('business-branding')
              .download(logoPath);
        } catch (_) {
          logoBytes = null;
        }
      }

      var loadedItems = (quote['order_items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      loadedItems = await loadDocumentProductDetails(loadedItems);

      final privateComments = <String, String>{};
      final lineIds = loadedItems
          .map((item) => item['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (lineIds.isNotEmpty) {
        final privateRows = await client
            .from('supplier_document_line_private_notes')
            .select('line_id, private_comment')
            .eq('document_kind', 'quote')
            .eq('document_id', widget.orderId)
            .inFilter('line_id', lineIds);

        for (final rawNote in privateRows) {
          final lineId = rawNote['line_id']?.toString();
          final comment = rawNote['private_comment']?.toString() ?? '';
          if (lineId != null &&
              lineId.isNotEmpty &&
              comment.trim().isNotEmpty) {
            privateComments[lineId] = comment;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _quote = quote;
        _supplier = Map<String, dynamic>.from(supplierRaw);
        _supplierProfile = supplierProfileRaw == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(supplierProfileRaw);
        _supplierLogoBytes = logoBytes;
        _customer = _map(quote['supplier_customer_accounts']);
        final contactSnapshot =
            quote['customer_contact_name_snapshot']?.toString().trim() ?? '';
        if (contactSnapshot.isNotEmpty) {
          _customer['contact_name'] = contactSnapshot;
        }
        _items = loadedItems;
        _privateComments = privateComments;
        if (_selectedLineId != null &&
            !loadedItems.any(
              (item) => item['id']?.toString() == _selectedLineId,
            )) {
          _selectedLineId = null;
          _lineAction = null;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PostgrestException ? error.message : error.toString();
        _loading = false;
      });
    }
  }

  String get _number {
    final quote = _quote ?? {};
    final base =
        quote['quote_number']?.toString() ??
        quote['order_number']?.toString() ??
        'Quote';
    final revision = (quote['quote_revision'] as num?)?.toInt() ?? 0;
    return revision > 0 ? '$base R$revision' : base;
  }

  String _lineTitle(Map<String, dynamic> item) => documentProductTitle(item);

  String _date(dynamic value, {bool time = false}) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '—';
    final date =
        '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    if (!time) return date;
    return '$date ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  double _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  String _money(dynamic value) => '\$${_asDouble(value).toStringAsFixed(2)}';

  Future<Uint8List> _pdf() => CutLinkQuotePdf.build(
    quote: _quote!,
    supplier: _supplier,
    supplierProfile: _supplierProfile,
    customer: _customer,
    items: _items,
    supplierLogoBytes: _supplierLogoBytes,
  );

  Future<void> _print() async {
    try {
      await Printing.layoutPdf(name: '$_number.pdf', onLayout: (_) => _pdf());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print quote: $error')),
        );
      }
    }
  }

  Future<void> _download() async {
    try {
      await Printing.sharePdf(bytes: await _pdf(), filename: '$_number.pdf');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export quote: $error')),
        );
      }
    }
  }

  Map<String, dynamic>? get _selectedLine {
    final id = _selectedLineId;
    if (id == null) return null;
    for (final item in _items) {
      if (item['id']?.toString() == id) return item;
    }
    return null;
  }

  double get _currentDeliveryFee => _asDouble(_quote?['delivery_fee']);

  void _selectQuoteLine(Map<String, dynamic> item) {
    setState(() {
      _selectedLineId = item['id']?.toString();
      _lineAction = null;
      _lineEditorController.clear();
    });
  }

  void _openQuoteLineAction(String action) {
    final item = _selectedLine;
    if (item == null) return;

    if (action == 'remove') {
      _removeSelectedQuoteLine();
      return;
    }

    if (_lineAction == action) {
      setState(() {
        _lineAction = null;
        _selectedDiscountType = null;
        _lineEditorController.clear();
      });
      return;
    }

    setState(() {
      _lineAction = action;
      if (action == 'discount') {
        final type = item['discount_type']?.toString();
        _selectedDiscountType = type == 'percent' || type == 'fixed'
            ? type
            : null;
        final value = _asDouble(item['discount_value']);
        _lineEditorController.text = _selectedDiscountType == null
            ? ''
            : value.toStringAsFixed(2);
      } else if (action == 'delivery') {
        _lineEditorController.text = _currentDeliveryFee.toStringAsFixed(2);
      } else if (action == 'private') {
        _lineEditorController.text =
            _privateComments[item['id']?.toString() ?? ''] ?? '';
      } else if (action == 'public') {
        _lineEditorController.text = item['public_comment']?.toString() ?? '';
      }
    });
  }

  Future<void> _saveSelectedQuoteLineAction() async {
    final item = _selectedLine;
    if (item == null || _lineAction == null || _savingLine) return;

    var discountType = item['discount_type']?.toString();
    if (discountType != 'percent' && discountType != 'fixed') {
      discountType = null;
    }
    double? discountValue = discountType == null
        ? null
        : _asDouble(item['discount_value']);
    var publicComment = item['public_comment']?.toString() ?? '';
    var privateComment = _privateComments[item['id']?.toString() ?? ''] ?? '';
    var deliveryFee = _currentDeliveryFee;

    if (_lineAction == 'discount') {
      discountType = _selectedDiscountType;
      discountValue = discountType == null
          ? null
          : double.tryParse(_lineEditorController.text.trim());
      if (discountType != null && discountValue == null) {
        _message('Enter a valid discount.');
        return;
      }
      if (discountType == 'percent' &&
          (discountValue! < 0 || discountValue > 100)) {
        _message('Percentage discount must be between 0 and 100%.');
        return;
      }
      if (discountValue != null && discountValue < 0) {
        _message('Discount cannot be negative.');
        return;
      }
    } else if (_lineAction == 'delivery') {
      final parsed = double.tryParse(_lineEditorController.text.trim());
      if (parsed == null || parsed < 0) {
        _message('Enter a valid delivery charge.');
        return;
      }
      deliveryFee = parsed;
    } else if (_lineAction == 'private') {
      privateComment = _lineEditorController.text.trim();
    } else if (_lineAction == 'public') {
      publicComment = _lineEditorController.text.trim();
    }

    setState(() => _savingLine = true);
    try {
      await Supabase.instance.client.rpc(
        'update_supplier_quote_line',
        params: {
          'p_order_item_id': item['id'],
          'p_discount_type': discountType,
          'p_discount_value': discountValue,
          'p_public_comment': publicComment,
          'p_private_comment': privateComment,
          'p_delivery_fee': deliveryFee,
          'p_remove': false,
        },
      );
      if (!mounted) return;
      setState(() => _lineAction = null);
      await _load();
    } on PostgrestException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _savingLine = false);
    }
  }

  Future<void> _removeSelectedQuoteLine() async {
    final item = _selectedLine;
    if (item == null || _savingLine) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this quote item?'),
        content: Text(
          '${item['product_name_snapshot'] ?? 'This item'} will be removed from the quote.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove Item'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _savingLine = true);
    try {
      await Supabase.instance.client.rpc(
        'update_supplier_quote_line',
        params: {
          'p_order_item_id': item['id'],
          'p_discount_type': item['discount_type'],
          'p_discount_value': item['discount_value'],
          'p_public_comment': item['public_comment'],
          'p_private_comment':
              _privateComments[item['id']?.toString() ?? ''] ?? '',
          'p_delivery_fee': _currentDeliveryFee,
          'p_remove': true,
        },
      );
      if (!mounted) return;
      setState(() {
        _selectedLineId = null;
        _lineAction = null;
      });
      await _load();
    } on PostgrestException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _savingLine = false);
    }
  }

  Future<void> _convertToWorkOrder() async {
    if (_convertingToWorkOrder || _quote?['status']?.toString() != 'draft') {
      return;
    }

    setState(() => _convertingToWorkOrder = true);
    try {
      await Supabase.instance.client.rpc(
        'convert_supplier_quote_to_sales_order',
        params: {'target_order_id': widget.orderId},
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SupplierWorkOrderPage(orderId: widget.orderId),
        ),
      );
    } on PostgrestException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _convertingToWorkOrder = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _tabs() => Container(
    height: 49,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFF0F1F2))),
    ),
    child: Row(
      children: [
        _tabButton(0, Icons.description_outlined, 'Quote Details'),
        _tabButton(1, Icons.picture_as_pdf_outlined, 'Preview'),
        _tabButton(2, Icons.history, 'Order History'),
      ],
    ),
  );

  Widget _tabButton(int index, IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: TextButton.icon(
      onPressed: () => setState(() => _tab = index),
      style: TextButton.styleFrom(
        foregroundColor: _tab == index ? Colors.white : const Color(0xFF5E6369),
        backgroundColor: _tab == index ? _darkRed : const Color(0xFFF4F5F6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
            color: _tab == index ? _darkRed : const Color(0xFFE1E3E6),
          ),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    ),
  );

  Widget _details() {
    final quote = _quote!;
    final customerName =
        _customer['customer_name']?.toString() ??
        _customer['legal_name']?.toString() ??
        'Customer';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: _panel(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                Widget metric(String label, String value, {int flex = 1}) {
                  return Expanded(
                    flex: flex,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .35,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (constraints.maxWidth < 760) {
                  return Wrap(
                    runSpacing: 9,
                    children: [
                      SizedBox(
                        width: 250,
                        child: _summary('Customer', customerName),
                      ),
                      SizedBox(
                        width: 180,
                        child: _summary(
                          'Fulfilment',
                          quote['fulfilment_method'] ?? '—',
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: _summary(
                          'Payment',
                          quote['payment_method_snapshot'] ?? '—',
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    metric('CUSTOMER', customerName, flex: 2),
                    const VerticalDivider(width: 1),
                    metric(
                      'PAYMENT',
                      quote['payment_method_snapshot']?.toString() ?? '—',
                    ),
                    const VerticalDivider(width: 1),
                    metric(
                      'FULFILMENT',
                      quote['fulfilment_method']?.toString() ?? '—',
                    ),
                    const VerticalDivider(width: 1),
                    metric(
                      'REQUESTED',
                      _date(quote['requested_fulfilment_date']),
                    ),
                    const VerticalDivider(width: 1),
                    metric('LINES', '${_items.length}'),
                    const VerticalDivider(width: 1),
                    metric('DELIVERY', _money(quote['delivery_fee'])),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: _panel(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.list_alt_outlined,
                          color: _darkRed,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Quote Items',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Select an item for actions',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 5),
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        final selected =
                            item['id']?.toString() == _selectedLineId;
                        final discount = _asDouble(item['discount_amount']);
                        final publicComment =
                            item['public_comment']?.toString().trim() ?? '';
                        return Material(
                          color: selected
                              ? const Color(0xFFF7EDED)
                              : const Color(0xFFFBFBF9),
                          borderRadius: BorderRadius.circular(9),
                          child: InkWell(
                            onTap: () => _selectQuoteLine(item),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: selected
                                      ? _darkRed
                                      : const Color(0xFFE4E4E0),
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        selected
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        size: 18,
                                        color: selected
                                            ? _darkRed
                                            : const Color(0xFF999999),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _lineTitle(item),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            if (documentProductSpecifications(
                                              item,
                                            ).isNotEmpty)
                                              Text(
                                                documentProductSpecifications(
                                                  item,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color: Color(0xFF646A70),
                                                ),
                                              ),
                                            Text(
                                              '${item['quantity']} ${item['quantity_unit']} • '
                                              '${_money(item['unit_price'])} / ${item['price_basis']}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF777777),
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (discount > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: Text(
                                            '-${_money(discount)}',
                                            style: const TextStyle(
                                              color: _darkRed,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      SizedBox(
                                        width: 110,
                                        child: Text(
                                          _money(
                                            _asDouble(item['line_subtotal']) -
                                                discount,
                                          ),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (publicComment.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F3F3),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.chat_bubble_outline,
                                            size: 14,
                                            color: _darkRed,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              publicComment,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                height: 1.3,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_selectedLine != null) ...[
                    const Divider(height: 1),
                    _buildQuoteLineDock(),
                  ],
                ],
              ),
            ),
          ),
          if ((quote['delivery_notes']?.toString().trim() ?? '').isNotEmpty ||
              (quote['internal_notes']?.toString().trim() ?? '')
                  .isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: _panel(),
              child: Wrap(
                spacing: 20,
                runSpacing: 5,
                children: [
                  if ((quote['delivery_notes']?.toString().trim() ?? '')
                      .isNotEmpty)
                    Text(
                      'Delivery: ${quote['delivery_notes']}',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  if ((quote['internal_notes']?.toString().trim() ?? '')
                      .isNotEmpty)
                    Text(
                      'Internal: ${quote['internal_notes']}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF777777),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuoteLineDock() {
    final item = _selectedLine;
    if (item == null) return const SizedBox.shrink();

    Widget actionButton({
      required String label,
      required IconData icon,
      required String action,
      bool danger = false,
    }) {
      final active = _lineAction == action;
      return TextButton.icon(
        onPressed: _savingLine ? null : () => _openQuoteLineAction(action),
        style: TextButton.styleFrom(
          foregroundColor: danger
              ? Colors.red.shade700
              : active
              ? Colors.white
              : _darkRed,
          backgroundColor: active ? _darkRed : Colors.transparent,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        ),
        icon: Icon(icon, size: 17),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      );
    }

    return Container(
      color: const Color(0xFFFAFAF8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item['product_name_snapshot']?.toString() ?? 'Selected item',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: _savingLine
                    ? null
                    : () => setState(() {
                        _selectedLineId = null;
                        _lineAction = null;
                      }),
                child: const Text('Clear'),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              actionButton(
                label: 'Discount',
                icon: Icons.percent,
                action: 'discount',
              ),
              actionButton(
                label: 'Delivery',
                icon: Icons.local_shipping_outlined,
                action: 'delivery',
              ),
              actionButton(
                label: 'Private Comment',
                icon: Icons.lock_outline,
                action: 'private',
              ),
              actionButton(
                label: 'Public Comment',
                icon: Icons.chat_bubble_outline,
                action: 'public',
              ),
              actionButton(
                label: 'Remove Item',
                icon: Icons.delete_outline,
                action: 'remove',
                danger: true,
              ),
            ],
          ),
          if (_lineAction != null && _lineAction != 'remove') ...[
            const SizedBox(height: 7),
            _buildQuoteLineInlineEditor(),
          ],
        ],
      ),
    );
  }

  Widget _buildQuoteLineInlineEditor() {
    Widget saveButton() => FilledButton.icon(
      onPressed: _savingLine ? null : _saveSelectedQuoteLineAction,
      style: FilledButton.styleFrom(
        backgroundColor: _darkRed,
        visualDensity: VisualDensity.compact,
      ),
      icon: _savingLine
          ? const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined, size: 16),
      label: const Text('Save'),
    );

    if (_lineAction == 'discount') {
      Widget typeField() => DropdownButtonFormField<String?>(
        initialValue: _selectedDiscountType,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Discount',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem<String?>(value: null, child: Text('No discount')),
          DropdownMenuItem<String?>(
            value: 'percent',
            child: Text('Percentage (%)'),
          ),
          DropdownMenuItem<String?>(
            value: 'fixed',
            child: Text(r'Fixed amount ($)'),
          ),
        ],
        onChanged: _savingLine
            ? null
            : (value) => setState(() {
                _selectedDiscountType = value;
                if (value == null) _lineEditorController.clear();
              }),
      );

      Widget amountField() => TextField(
        controller: _lineEditorController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: _selectedDiscountType == 'percent'
              ? 'Percentage'
              : 'Amount',
          suffixText: _selectedDiscountType == 'percent' ? '%' : null,
          prefixText: _selectedDiscountType == 'fixed' ? r'$' : null,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      );

      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                typeField(),
                if (_selectedDiscountType != null) ...[
                  const SizedBox(height: 8),
                  amountField(),
                ],
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: saveButton()),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 190, child: typeField()),
              if (_selectedDiscountType != null) ...[
                const SizedBox(width: 8),
                Expanded(child: amountField()),
              ] else
                const Spacer(),
              const SizedBox(width: 8),
              saveButton(),
            ],
          );
        },
      );
    }

    if (_lineAction == 'delivery') {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _lineEditorController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Delivery charge for this quote',
                prefixText: r'$',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          saveButton(),
        ],
      );
    }

    final private = _lineAction == 'private';
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _lineEditorController,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: private
                  ? 'Private supplier comment'
                  : 'Public comment',
              helperText: private
                  ? 'Supplier only. Never printed or shown to the customer.'
                  : 'Printed beneath this item on the quote.',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        saveButton(),
      ],
    );
  }

  BoxDecoration _panel() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE0E0DD)),
  );
  Widget _summary(String label, dynamic value) => Container(
    width: 220,
    padding: const EdgeInsets.all(14),
    decoration: _panel(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value?.toString() ?? '—',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
  Widget _preview() => Column(
    children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: const Row(
          children: [
            Expanded(
              child: Text(
                'Quote PDF',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ZoomablePdfPreview(
          documentKey:
              'quote-${widget.orderId}-${_quote?['quote_revision']}-${_quote?['updated_at']}',
          buildPdf: _pdf,
          dpi: 480,
          minScale: 0.55,
          maxScale: 5,
          maxPageWidth: 920,
        ),
      ),
    ],
  );

  Widget _history() {
    final quote = _quote!;
    final events = <List<dynamic>>[
      ['Quote created', quote['created_at'], Icons.add_circle_outline],
      if (quote['quote_last_saved_at'] != null)
        [
          'Quote revision saved',
          quote['quote_last_saved_at'],
          Icons.edit_outlined,
        ],
      if (quote['updated_at'] != null &&
          quote['updated_at'] != quote['quote_last_saved_at'])
        ['Last updated', quote['updated_at'], Icons.update],
    ];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _panel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order History',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Activity recorded for this quote.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 18),
              for (final event in events)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF5EAEA),
                    child: Icon(
                      event[2] as IconData,
                      color: _darkRed,
                      size: 19,
                    ),
                  ),
                  title: Text(
                    event[0].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(_date(event[1], time: true)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F7F5),
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text(
        _loading ? 'Quote' : _number,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      actions: _loading || _error != null
          ? null
          : [
              if (_quote?['status']?.toString() == 'draft') ...[
                FilledButton.icon(
                  onPressed: _convertingToWorkOrder
                      ? null
                      : _convertToWorkOrder,
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  icon: _convertingToWorkOrder
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.inventory_2_outlined, size: 17),
                  label: Text(
                    _convertingToWorkOrder
                        ? 'Converting...'
                        : 'Convert to Work Order',
                  ),
                ),
                const SizedBox(width: 7),
              ],
              OutlinedButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download_outlined, size: 17),
                label: const Text('Download'),
              ),
              const SizedBox(width: 7),
              FilledButton.icon(
                onPressed: _print,
                style: FilledButton.styleFrom(backgroundColor: _darkRed),
                icon: const Icon(Icons.print_outlined, size: 17),
                label: const Text('Print'),
              ),
              const SizedBox(width: 7),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Quote'),
              ),
              const SizedBox(width: 8),
            ],
      bottom: _loading || _error != null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(49),
              child: _tabs(),
            ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Try Again')),
              ],
            ),
          )
        : switch (_tab) {
            1 => _preview(),
            2 => _history(),
            _ => _details(),
          },
  );
}
