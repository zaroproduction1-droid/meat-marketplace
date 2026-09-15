import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/quote_pdf_service.dart';

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
  final _previewTransformController = TransformationController();
  final _previewViewportKey = GlobalKey();
  double _previewZoom = 1;
  bool _isPreviewDragging = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _previewTransformController.dispose();
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
          id, product_name_snapshot, sku_snapshot, quantity, quantity_unit,
          unit_price, price_basis, catch_weight_snapshot, notes
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

      if (!mounted) return;
      setState(() {
        _quote = quote;
        _supplier = Map<String, dynamic>.from(supplierRaw);
        _supplierProfile = supplierProfileRaw == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(supplierProfileRaw);
        _supplierLogoBytes = logoBytes;
        _customer = _map(quote['supplier_customer_accounts']);
        _items = (quote['order_items'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
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
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summary(
              'Customer',
              _customer['customer_name'] ??
                  _customer['legal_name'] ??
                  'Customer',
            ),
            _summary('Created', _date(quote['created_at'])),
            _summary('Fulfilment', quote['fulfilment_method'] ?? '—'),
            _summary('Lines', _items.length),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          decoration: _panel(),
          child: Column(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                ListTile(
                  title: Text(
                    _items[i]['product_name_snapshot']?.toString() ?? 'Product',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${_items[i]['quantity']} ${_items[i]['quantity_unit']} × ${_money(_items[i]['unit_price'])} / ${_items[i]['price_basis']}${_items[i]['catch_weight_snapshot'] == true ? ' • final amount pending weight' : ''}',
                  ),
                  trailing: Text(
                    '${_money(_items[i]['unit_price'])} / ${_items[i]['price_basis']}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (i < _items.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _infoPanel('Quote information', [
          ['Customer reference', quote['customer_reference']],
          ['Payment', quote['payment_method_snapshot']],
          [
            'Payment terms',
            quote['payment_terms_days_snapshot'] == null
                ? null
                : '${quote['payment_terms_days_snapshot']} days',
          ],
          ['Requested date', _date(quote['requested_fulfilment_date'])],
          ['Delivery notes', quote['delivery_notes']],
          ['Internal notes', quote['internal_notes']],
        ]),
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
  Widget _infoPanel(String title, List<List<dynamic>> rows) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _panel(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        for (final row in rows.where(
          (row) => (row[1]?.toString().trim() ?? '').isNotEmpty,
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    row[0].toString(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(child: Text(row[1].toString())),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _preview() => Column(
    children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Quote PDF',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            _zoomControls(),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight > 24
                ? constraints.maxHeight - 24
                : constraints.maxHeight;
            final availableWidth = constraints.maxWidth > 24
                ? constraints.maxWidth - 24
                : constraints.maxWidth;
            final fitWidth =
                availableHeight *
                PdfPageFormat.a4.width /
                PdfPageFormat.a4.height;
            final maxWidth = fitWidth < availableWidth
                ? fitWidth
                : availableWidth;
            return ClipRect(
              key: _previewViewportKey,
              child: MouseRegion(
                cursor: _previewZoom > 1
                    ? (_isPreviewDragging
                          ? SystemMouseCursors.grabbing
                          : SystemMouseCursors.grab)
                    : MouseCursor.defer,
                child: Listener(
                  onPointerSignal: _handlePreviewPointerSignal,
                  child: InteractiveViewer(
                    transformationController: _previewTransformController,
                    minScale: 0.75,
                    maxScale: 3,
                    panEnabled: _previewZoom > 1,
                    onInteractionStart: (_) {
                      if (_previewZoom > 1) {
                        setState(() => _isPreviewDragging = true);
                      }
                    },
                    onInteractionUpdate: (_) => _syncPreviewZoom(),
                    onInteractionEnd: (_) {
                      _syncPreviewZoom();
                      if (_isPreviewDragging) {
                        setState(() => _isPreviewDragging = false);
                      }
                    },
                    child: PdfPreview(
                      build: (_) => _pdf(),
                      pdfFileName: '$_number.pdf',
                      maxPageWidth: maxWidth,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      allowPrinting: false,
                      allowSharing: false,
                      loadingWidget: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _zoomControls() => Container(
    height: 36,
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5F6),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFFE0E2E5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _previewZoom <= .75
              ? null
              : () => _setPreviewZoom(_previewZoom - .1),
          tooltip: 'Zoom out',
          icon: const Icon(Icons.zoom_out, size: 18),
          visualDensity: VisualDensity.compact,
        ),
        Tooltip(
          message: 'Reset and centre preview',
          child: TextButton.icon(
            onPressed: _resetPreviewZoom,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4F555B),
              minimumSize: const Size(72, 34),
              padding: const EdgeInsets.symmetric(horizontal: 7),
            ),
            icon: const Icon(Icons.center_focus_strong_outlined, size: 15),
            label: Text(
              '${(_previewZoom * 100).round()}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        IconButton(
          onPressed: _previewZoom >= 3
              ? null
              : () => _setPreviewZoom(_previewZoom + .1),
          tooltip: 'Zoom in',
          icon: const Icon(Icons.zoom_in, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );

  void _handlePreviewPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _setPreviewZoom(
      _previewZoom + (event.scrollDelta.dy < 0 ? .1 : -.1),
      focalPoint: event.localPosition,
    );
  }

  void _setPreviewZoom(double value, {Offset? focalPoint}) {
    final zoom = value.clamp(.75, 3.0);
    if (zoom == _previewZoom) return;
    final focal = focalPoint ?? _previewCentre();
    final factor = zoom / _previewZoom;
    final adjustment = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
      ..multiply(_previewTransformController.value);
    _previewTransformController.value = adjustment;
    setState(() => _previewZoom = zoom);
  }

  void _syncPreviewZoom() {
    final zoom = _previewTransformController.value.getMaxScaleOnAxis().clamp(
      .75,
      3.0,
    );
    if ((zoom - _previewZoom).abs() > .001 && mounted) {
      setState(() => _previewZoom = zoom);
    }
  }

  Offset _previewCentre() {
    final object = _previewViewportKey.currentContext?.findRenderObject();
    return object is RenderBox ? object.size.center(Offset.zero) : Offset.zero;
  }

  void _resetPreviewZoom() {
    _previewTransformController.value = Matrix4.identity();
    setState(() => _previewZoom = 1);
  }

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
