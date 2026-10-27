import '../../../shared/widgets/ios_density.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

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
import 'admin_membership_actions.dart';

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
  AdminRow? _notice;
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
          _notice = null;
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

  Future<Uint8List> _bytes() => _pdf ??= PlatformInvoicePdf.build({
    ..._invoice!,
    if (_notice != null) 'notice': _notice,
  });
  Future<void> _export(bool print) async {
    setState(() => _exporting = true);
    try {
      final bytes = await _bytes();
      final name =
          '${_invoice!['invoice_number']}${_notice == null ? '' : '-notice-${_notice!['stage']}'}.pdf';
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

  Future<void> _issueNotice() async {
    final notices = PlatformAdminService.rows(_invoice!['notices']);
    final stage = notices.length + 1;
    final saved = await adminForm(
      context,
      title: stage == 3
          ? 'Third notice — place account on hold'
          : 'Generate overdue notice $stage',
      explanation: stage == 3
          ? 'This suspends this business and its active members. Support and owner/manager access to unpaid subscription invoices remain available. This does not create another debt or send an email.'
          : 'Download this reminder and email it to the business. The original invoice number and debt stay unchanged. The next notice cannot be issued until this deadline has passed.',
      submitLabel: stage == 3
          ? 'Issue notice & hold account'
          : 'Generate notice',
      initial: {
        'deadline': PlatformAdminService.iso(
          DateTime.now().add(Duration(days: stage == 3 ? 0 : 7)),
        ),
      },
      fields: const [
        AdminField('deadline', 'Payment deadline', required: true, date: true),
      ],
      submit: (data) async {
        await Supabase.instance.client.rpc(
          'platform_issue_invoice_notice',
          params: {
            'p_invoice_id': widget.invoiceId,
            'p_stage': stage,
            'p_payment_deadline': data['deadline'],
          },
        );
      },
    );
    if (saved && mounted) {
      await _load();
      if (mounted && _invoice != null) {
        final notices = PlatformAdminService.rows(_invoice!['notices']);
        setState(() {
          _notice = notices.isEmpty ? null : notices.last;
          _pdf = null;
          _version++;
        });
      }
    }
  }

  Future<void> _restoreBillingAccess() async {
    final saved = await adminForm(
      context,
      title: 'Restore business access',
      explanation:
          'All subscription invoices must be paid or voided. Confirm the payments are verified before restoring access.',
      submitLabel: 'Restore access',
      fields: const [],
      submit: (_) async {
        await Supabase.instance.client.rpc(
          'platform_restore_billing_hold',
          params: {'p_invoice_id': widget.invoiceId},
        );
      },
    );
    if (saved && mounted) {
      await _load();
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
          optionLabels: {
            'bank_transfer': 'Bank transfer',
            'card': 'Card',
            'cash': 'Cash',
            'other': 'Other',
          },
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
              const IosGap(height: 12),
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

  bool get _canIssueNotice {
    if (_invoice == null ||
        _invoice!['voided_at'] != null ||
        PlatformAdminService.amount(_invoice!['outstanding']) <= 0) {
      return false;
    }
    final notices = PlatformAdminService.rows(_invoice!['notices']);
    if (notices.length >= 3) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = DateTime.tryParse(
      '${notices.isEmpty ? _invoice!['due_date'] : notices.last['payment_deadline']}',
    );
    return deadline != null && deadline.isBefore(today);
  }

  Widget _value(String label, dynamic amount) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text(
        PlatformAdminService.money(amount),
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
    ],
  );

  void _more(String action) {
    switch (action) {
      case 'payments':
        _payments();
      case 'notice':
        _issueNotice();
      case 'restore':
        _restoreBillingAccess();
      case 'void':
        _reason('void_invoice', widget.invoiceId, 'Void CutLink invoice');
    }
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
                child: IosPadding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!),
                ),
              )
            : Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .45,
                    ),
                    child: SingleChildScrollView(
                      child: IosPadding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${PlatformAdminService.map(_invoice!['customer_snapshot'])['billing_name'] ?? 'Business'}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const IosGap(height: 12),
                            Wrap(
                              spacing: 24,
                              runSpacing: 10,
                              children: [
                                _value(
                                  'Invoice total',
                                  _invoice!['total_amount'],
                                ),
                                _value(
                                  'Payments received',
                                  _invoice!['amount_paid'],
                                ),
                                _value(
                                  'Still unpaid',
                                  _invoice!['outstanding'],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Due date'),
                                    Text(
                                      PlatformAdminService.date(
                                        _invoice!['due_date'],
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const IosGap(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (_invoice!['voided_at'] == null &&
                                    PlatformAdminService.amount(
                                          _invoice!['outstanding'],
                                        ) >
                                        0)
                                  FilledButton.icon(
                                    onPressed: _payment,
                                    icon: const Icon(Icons.payments_outlined),
                                    label: const Text(
                                      'Record received payment',
                                    ),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: _exporting
                                      ? null
                                      : () => _export(false),
                                  icon: const Icon(Icons.download_outlined),
                                  label: Text(
                                    _notice == null
                                        ? 'Download invoice'
                                        : 'Download reminder',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _exporting
                                      ? null
                                      : () => _export(true),
                                  icon: const Icon(Icons.print_outlined),
                                  label: const Text('Print'),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'More invoice actions',
                                  onSelected: _more,
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'payments',
                                      child: Text('Payment history'),
                                    ),
                                    if (_canIssueNotice)
                                      const PopupMenuItem(
                                        value: 'notice',
                                        child: Text('Create overdue reminder'),
                                      ),
                                    if (_invoice!['billing_hold'] == true)
                                      const PopupMenuItem(
                                        value: 'restore',
                                        child: Text('Review & restore access'),
                                      ),
                                    if (_invoice!['voided_at'] == null &&
                                        PlatformAdminService.amount(
                                              _invoice!['amount_paid'],
                                            ) ==
                                            0)
                                      const PopupMenuItem(
                                        value: 'void',
                                        child: Text('Void this invoice'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const IosGap(height: 8),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Chip(
                                  label: Text(
                                    _invoice!['voided_at'] != null
                                        ? 'Voided'
                                        : PlatformAdminService.amount(
                                                _invoice!['outstanding'],
                                              ) <=
                                              0
                                        ? 'Paid'
                                        : 'Payment outstanding',
                                  ),
                                ),
                                PopupMenuButton<AdminRow>(
                                  tooltip: 'View original invoice or reminder',
                                  child: IosPadding(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _notice == null
                                              ? 'Viewing original invoice'
                                              : 'Viewing reminder ${_notice!['stage']}',
                                        ),
                                        const Icon(Icons.arrow_drop_down),
                                      ],
                                    ),
                                  ),
                                  onSelected: (value) => setState(() {
                                    _notice = value.isEmpty ? null : value;
                                    _pdf = null;
                                    _version++;
                                  }),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: <String, dynamic>{},
                                      child: Text('Original invoice'),
                                    ),
                                    for (final notice
                                        in PlatformAdminService.rows(
                                          _invoice!['notices'],
                                        ))
                                      PopupMenuItem(
                                        value: notice,
                                        child: Text(
                                          'Reminder ${notice['stage']} · ${PlatformAdminService.date(notice['created_at'])}',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
  final id = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _InvoiceReviewDialog(accountId: '${account['id']}'),
  );
  if (!context.mounted || id == null) {
    return;
  }
  if (id == 'invoice_settings') {
    if (await editCutLinkInvoiceDetails(context) && context.mounted) {
      await createSubscriptionInvoice(context, account);
    }
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PlatformInvoicePage(invoiceId: id)),
  );
}

class _InvoiceReviewDialog extends StatefulWidget {
  const _InvoiceReviewDialog({required this.accountId});
  final String accountId;
  @override
  State<_InvoiceReviewDialog> createState() => _InvoiceReviewDialogState();
}

class _InvoiceReviewDialogState extends State<_InvoiceReviewDialog> {
  AdminRow? _quote;
  String? _error;
  bool _loading = true, _saving = false;
  final _start = TextEditingController(), _end = TextEditingController();
  bool get _edited =>
      _quote != null &&
      (_start.text != _quote!['period_start'] ||
          _end.text != _quote!['period_end']);
  @override
  void initState() {
    super.initState();
    _load();
    _start.addListener(_datesChanged);
    _end.addListener(_datesChanged);
  }

  void _datesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _load({bool custom = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (custom &&
          (DateTime.tryParse(_start.text) == null ||
              DateTime.tryParse(_end.text) == null)) {
        throw ArgumentError('Choose valid start and end dates.');
      }
      final quote = await PlatformAdminService.invoicePreview(
        widget.accountId,
        start: custom ? _start.text : null,
        end: custom ? _end.text : null,
      );
      if (mounted) {
        setState(() {
          _quote = quote;
          _start.text = '${quote['period_start']}';
          _end.text = '${quote['period_end']}';
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = PlatformAdminService.error(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    if (_saving || _loading || _quote == null || _edited || _error != null) {
      return;
    }
    if (_quote!['existing_invoice_id'] != null) {
      Navigator.of(context).pop('${_quote!['existing_invoice_id']}');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await PlatformAdminService.action('create_invoice', {
        'id': widget.accountId,
        'period_start': _quote!['period_start'],
        'period_end': _quote!['period_end'],
        'expected_total': _quote!['total'],
      });
      if (result['id'] == null) {
        throw StateError(
          'No invoice was returned. Refresh the preview and try again.',
        );
      }
      if (mounted) {
        Navigator.of(context).pop('${result['id']}');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = PlatformAdminService.error(error);
          _saving = false;
        });
      }
    }
  }

  Future<void> _date(TextEditingController controller) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(controller.text) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      controller.text = PlatformAdminService.iso(date);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Review CutLink invoice'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading)
                const IosPadding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading && _quote != null) ...[
                Text(
                  '${_quote!['business']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const IosGap(height: 12),
                Text(
                  '${PlatformAdminService.date(_quote!['period_start'])} – ${PlatformAdminService.date(_quote!['period_end'])}',
                ),
                const IosGap(height: 12),
                Text(
                  PlatformAdminService.money(_quote!['total']),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.accent,
                  ),
                ),
                Text(
                  'Total AUD · Includes ${PlatformAdminService.money(_quote!['gst_amount'])} GST',
                ),
                Text(
                  'Payment due ${PlatformAdminService.date(_quote!['due_date'])}',
                ),
                const IosGap(height: 10),
                if (_quote!['stage'] == 'free_founding')
                  const Text('This period is free under the founding offer.'),
                if (_quote!['stage'] == 'founding_half_price')
                  const Text('This period is part of the half-price year.'),
                if (_quote!['existing_invoice_id'] != null)
                  Text(
                    '${_quote!['invoice_number']} already covers these dates. Open it instead of creating another.',
                  ),
                if (_quote!['issuer_ready'] != true) ...[
                  const Text(
                    'Add your CutLink business name and billing email before creating invoices.',
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop('invoice_settings'),
                    child: const Text('Add invoice details'),
                  ),
                ],
                ExpansionTile(
                  title: const Text('Change billing period'),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    TextField(
                      controller: _start,
                      enabled: !_saving && !_loading,
                      decoration: InputDecoration(
                        labelText: 'Starts (YYYY-MM-DD)',
                        suffixIcon: IconButton(
                          onPressed: _saving ? null : () => _date(_start),
                          icon: const Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                    ),
                    const IosGap(height: 12),
                    TextField(
                      controller: _end,
                      enabled: !_saving && !_loading,
                      decoration: InputDecoration(
                        labelText: 'Ends (YYYY-MM-DD)',
                        suffixIcon: IconButton(
                          onPressed: _saving ? null : () => _date(_end),
                          icon: const Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _saving || _loading
                          ? null
                          : () => _load(custom: true),
                      child: const Text('Update preview'),
                    ),
                    TextButton(
                      onPressed: _saving || _loading ? null : () => _load(),
                      child: const Text('Use next invoice period'),
                    ),
                  ],
                ),
                const IosGap(height: 8),
                const Text(
                  'Creates an invoice only. Download its PDF to send to the business. No money is charged.',
                ),
              ],
              if (_error != null)
                IosPadding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_error != null)
                TextButton(
                  onPressed: _saving || _loading
                      ? null
                      : () => _load(custom: _quote != null),
                  child: const Text('Refresh preview'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _saving ||
                  _loading ||
                  _error != null ||
                  _quote == null ||
                  _quote!['issuer_ready'] != true
              ? null
              : _edited
              ? () => _load(custom: true)
              : _create,
          child: Text(
            _saving
                ? 'Creating…'
                : _edited
                ? 'Update preview'
                : _quote?['existing_invoice_id'] != null
                ? 'Open existing invoice'
                : 'Create invoice',
          ),
        ),
      ],
    ),
  );
}
