import 'admin_theme.dart';
import '../../../shared/navigation/page_location.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../shared/widgets/phone_layout.dart';
import '../../../shared/widgets/zoomable_pdf_preview.dart';
import '../services/platform_admin_service.dart';
import '../services/platform_invoice_pdf.dart';
import 'admin_widgets.dart';

class PlatformInvoicePage extends StatefulWidget {
  const PlatformInvoicePage({super.key, required this.invoiceId});
  final String invoiceId;
  @override
  State<PlatformInvoicePage> createState() => _PlatformInvoicePageState();
}

class _PlatformInvoicePageState extends State<PlatformInvoicePage> {
  AdminRow? _invoice;
  String? _error;
  bool _loading = true, _exporting = false;
  int _version = 0;
  Future<Uint8List>? _pdf;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = PlatformAdminService.map(
        await PlatformAdminService.query('invoice', id: widget.invoiceId),
      );
      if (row.isEmpty) {
        throw StateError('Invoice not found.');
      }
      if (mounted) {
        setState(() {
          _invoice = row;
          _pdf = null;
          _version++;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = PlatformAdminService.error(e);
          _loading = false;
        });
      }
    }
  }

  Future<Uint8List> _bytes() => _pdf ??= PlatformInvoicePdf.build(_invoice!);
  Future<void> _export(bool print) async {
    setState(() => _exporting = true);
    try {
      final bytes = await _bytes();
      final name = '${_invoice!['invoice_number']}.pdf';
      if (print) {
        await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(PlatformAdminService.error(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _payment() async {
    final requestKey = PlatformAdminService.requestKey();
    final saved = await adminForm(
      context,
      title: 'Record subscription payment',
      explanation:
          'Record funds you have received. This does not charge a card or move money.',
      submitLabel: 'Confirm received',
      initial: {
        'amount': PlatformAdminService.amount(
          _invoice!['outstanding'],
        ).toStringAsFixed(2),
        'paid_on': PlatformAdminService.iso(DateTime.now()),
        'method': 'bank_transfer',
      },
      fields: const [
        AdminField(
          'amount',
          'Amount received (AUD)',
          required: true,
          number: true,
        ),
        AdminField('paid_on', 'Received on', required: true, date: true),
        AdminField(
          'method',
          'Payment method',
          required: true,
          options: ['bank_transfer', 'card', 'cash', 'other'],
        ),
        AdminField('reference', 'Payment reference'),
      ],
      submit: (data) async {
        await PlatformAdminService.action('record_payment', {
          ...data,
          'id': widget.invoiceId,
          'request_key': requestKey,
        });
      },
    );
    if (saved && mounted) {
      await _load();
    }
  }

  Future<void> _reason(String action, String id, String title) async {
    final saved = await adminForm(
      context,
      title: title,
      fields: const [AdminField('reason', 'Reason', required: true, lines: 3)],
      submitLabel: 'Confirm',
      submit: (data) async {
        await PlatformAdminService.action(action, {...data, 'id': id});
      },
    );
    if (saved && mounted) {
      await _load();
    }
  }

  Future<void> _payments() async {
    final payments = PlatformAdminService.rows(_invoice!['payments']);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .65,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Payment history',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (payments.isEmpty) const Text('No payments recorded.'),
              for (final p in payments)
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${PlatformAdminService.money(p['amount'])} · ${PlatformAdminService.date(p['paid_on'])}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('${p['method']}'.replaceAll('_', ' ')),
                      if ('${p['reference'] ?? ''}'.isNotEmpty)
                        Text('${p['reference']}'),
                      if (p['reversed_at'] != null)
                        Text('Reversed: ${p['reversal_reason']}')
                      else
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _reason(
                              'reverse_payment',
                              '${p['id']}',
                              'Reverse payment record',
                            );
                          },
                          icon: const Icon(Icons.undo),
                          label: const Text('Reverse payment record'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PageLocation.track(context, {
      'page': 'platform_invoice',
      'id': widget.invoiceId,
    });
    return AdminTheme(
      child: Scaffold(
        appBar: phoneAppBar(
          context,
          AppBar(
            title: Text(
              _invoice?['invoice_number']?.toString() ?? 'Subscription invoice',
            ),
            actions: [
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        body: _loading
            ? const AdminLoading()
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Balance ${PlatformAdminService.money(_invoice!['outstanding'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _exporting ? null : () => _export(false),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Download / share'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _exporting ? null : () => _export(true),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print'),
                        ),
                        if (_invoice!['voided_at'] == null &&
                            PlatformAdminService.amount(
                                  _invoice!['outstanding'],
                                ) >
                                0)
                          OutlinedButton.icon(
                            onPressed: _payment,
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Record payment'),
                          ),
                        TextButton(
                          onPressed: _payments,
                          child: const Text('Payment history'),
                        ),
                        if (_invoice!['voided_at'] == null &&
                            PlatformAdminService.amount(
                                  _invoice!['amount_paid'],
                                ) ==
                                0)
                          TextButton(
                            onPressed: () => _reason(
                              'void_invoice',
                              widget.invoiceId,
                              'Void subscription invoice',
                            ),
                            child: const Text('Void invoice'),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ZoomablePdfPreview(
                      documentKey: 'platform-${widget.invoiceId}-$_version',
                      buildPdf: _bytes,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<void> createSubscriptionInvoice(
  BuildContext context,
  AdminRow account,
) async {
  final start =
      DateTime.tryParse('${account['next_billing_date']}') ?? DateTime.now();
  final nextMonthLastDay = DateTime(start.year, start.month + 2, 0).day;
  final next = DateTime(
    start.year,
    start.month + 1,
    start.day > nextMonthLastDay ? nextMonthLastDay : start.day,
  );
  String? invoiceId;
  final saved = await adminForm(
    context,
    title: 'Generate monthly invoice',
    submitLabel: 'Generate invoice',
    explanation:
        '${account['billing_name']}\n${account['plan_name']} · ${PlatformAdminService.money(account['monthly_fee'])} excluding GST\nGST is added only when enabled in CutLink billing settings. Download the invoice to email it externally.',
    initial: {
      'period_start': PlatformAdminService.iso(start),
      'period_end': PlatformAdminService.iso(
        next.subtract(const Duration(days: 1)),
      ),
    },
    fields: const [
      AdminField('period_start', 'Period starts', required: true, date: true),
      AdminField('period_end', 'Period ends', required: true, date: true),
    ],
    submit: (data) async {
      final result = await PlatformAdminService.action('create_invoice', {
        ...data,
        'id': account['id'],
      });
      invoiceId = result['id']?.toString();
    },
  );
  if (saved && context.mounted && invoiceId != null) {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlatformInvoicePage(invoiceId: invoiceId!),
      ),
    );
  }
}
