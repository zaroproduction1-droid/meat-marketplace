import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountStatementPage extends StatefulWidget {
  const AccountStatementPage({
    super.key,
    required this.supplierBusinessId,
    required this.supplierName,
    required this.customerName,
    this.supplierCustomerAccountId,
    this.butcherBusinessId,
    required this.supplierView,
  });

  final String supplierBusinessId;
  final String supplierName;
  final String customerName;
  final String? supplierCustomerAccountId;
  final String? butcherBusinessId;
  final bool supplierView;

  @override
  State<AccountStatementPage> createState() => _AccountStatementPageState();
}

class _AccountStatementPageState extends State<AccountStatementPage> {
  static const Color _darkRed = Color(0xFF741C1C);

  bool _loading = true;
  String? _error;

  late DateTime _fromDate;
  late DateTime _toDate;

  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _credits = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _toDate = DateTime(now.year, now.month, now.day);
    _fromDate = DateTime(now.year, now.month - 1, now.day);
    _loadStatement();
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

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _date(dynamic value) {
    final parsed = value is DateTime ? value : _parseDate(value);
    if (parsed == null) return '—';

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _loadStatement() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;

      var invoiceQuery = client
          .from('invoices')
          .select('''
            id,
            invoice_number,
            order_id,
            supplier_business_id,
            butcher_business_id,
            supplier_customer_account_id,
            status,
            invoice_date,
            due_date,
            total_amount,
            amount_paid,
            credit_applied,
            outstanding_amount,
            sent_to_butcher_at,
            created_at,
            orders(order_number)
          ''')
          .eq('supplier_business_id', widget.supplierBusinessId)
          .not('status', 'in', '(draft,ready)');

      if (widget.supplierCustomerAccountId != null &&
          widget.supplierCustomerAccountId!.isNotEmpty) {
        if (widget.butcherBusinessId != null &&
            widget.butcherBusinessId!.isNotEmpty) {
          invoiceQuery = invoiceQuery.or(
            'supplier_customer_account_id.eq.${widget.supplierCustomerAccountId},'
            'butcher_business_id.eq.${widget.butcherBusinessId}',
          );
        } else {
          invoiceQuery = invoiceQuery.eq(
            'supplier_customer_account_id',
            widget.supplierCustomerAccountId!,
          );
        }
      } else if (widget.butcherBusinessId != null &&
          widget.butcherBusinessId!.isNotEmpty) {
        invoiceQuery = invoiceQuery.eq(
          'butcher_business_id',
          widget.butcherBusinessId!,
        );
      }

      if (!widget.supplierView) {
        invoiceQuery = invoiceQuery.not('sent_to_butcher_at', 'is', null);
      }

      final invoicesResponse = await invoiceQuery.order(
        'invoice_date',
        ascending: true,
      );

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
            reversed_at,
            reversal_note,
            created_at
          ''')
          .eq('supplier_business_id', widget.supplierBusinessId);

      if (widget.supplierCustomerAccountId != null &&
          widget.supplierCustomerAccountId!.isNotEmpty) {
        if (widget.butcherBusinessId != null &&
            widget.butcherBusinessId!.isNotEmpty) {
          paymentQuery = paymentQuery.or(
            'supplier_customer_account_id.eq.${widget.supplierCustomerAccountId},'
            'butcher_business_id.eq.${widget.butcherBusinessId}',
          );
        } else {
          paymentQuery = paymentQuery.eq(
            'supplier_customer_account_id',
            widget.supplierCustomerAccountId!,
          );
        }
      } else if (widget.butcherBusinessId != null &&
          widget.butcherBusinessId!.isNotEmpty) {
        paymentQuery = paymentQuery.eq(
          'butcher_business_id',
          widget.butcherBusinessId!,
        );
      }

      final paymentsResponse = await paymentQuery.order(
        'payment_date',
        ascending: true,
      );

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
            status,
            reversed_at,
            reversal_note,
            created_at
          ''')
          .eq('supplier_business_id', widget.supplierBusinessId);

      if (widget.supplierCustomerAccountId != null &&
          widget.supplierCustomerAccountId!.isNotEmpty) {
        if (widget.butcherBusinessId != null &&
            widget.butcherBusinessId!.isNotEmpty) {
          creditQuery = creditQuery.or(
            'supplier_customer_account_id.eq.${widget.supplierCustomerAccountId},'
            'butcher_business_id.eq.${widget.butcherBusinessId}',
          );
        } else {
          creditQuery = creditQuery.eq(
            'supplier_customer_account_id',
            widget.supplierCustomerAccountId!,
          );
        }
      } else if (widget.butcherBusinessId != null &&
          widget.butcherBusinessId!.isNotEmpty) {
        creditQuery = creditQuery.eq(
          'butcher_business_id',
          widget.butcherBusinessId!,
        );
      }

      final creditsResponse = await creditQuery.order(
        'credit_date',
        ascending: true,
      );

      if (!mounted) return;

      setState(() {
        _invoices = List<Map<String, dynamic>>.from(invoicesResponse);
        _payments = List<Map<String, dynamic>>.from(paymentsResponse);
        _credits = List<Map<String, dynamic>>.from(creditsResponse);
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

  List<Map<String, dynamic>> get _allTransactions {
    final rows = <Map<String, dynamic>>[];

    for (final invoice in _invoices) {
      if (invoice['status']?.toString() == 'void') continue;

      final date = _parseDate(invoice['invoice_date'] ?? invoice['created_at']);
      if (date == null) continue;

      final order = invoice['orders'];
      final orderNumber = order is Map
          ? order['order_number']?.toString()
          : null;

      rows.add({
        'date': _dateOnly(date),
        'type': 'invoice',
        'reference': invoice['invoice_number']?.toString() ?? 'Invoice',
        'description': orderNumber == null || orderNumber.isEmpty
            ? 'Invoice'
            : 'Order $orderNumber',
        'debit': _asDouble(invoice['total_amount']),
        'credit': 0.0,
      });
    }

    for (final payment in _payments) {
      if (payment['status']?.toString() != 'active') continue;

      final date = _parseDate(payment['payment_date'] ?? payment['created_at']);
      if (date == null) continue;

      final reference = payment['reference']?.toString().trim() ?? '';

      rows.add({
        'date': _dateOnly(date),
        'type': 'payment',
        'reference': reference.isEmpty ? 'Payment' : reference,
        'description':
            'Payment received • ${_paymentMethodLabel(payment['payment_method']?.toString())}',
        'debit': 0.0,
        'credit': _asDouble(payment['amount']),
      });
    }

    for (final credit in _credits) {
      if (credit['status']?.toString() != 'active') continue;

      final date = _parseDate(credit['credit_date'] ?? credit['created_at']);
      if (date == null) continue;

      final type = credit['credit_type']?.toString() ?? 'credit';
      final reference = credit['reference']?.toString().trim() ?? '';

      rows.add({
        'date': _dateOnly(date),
        'type': type == 'adjustment' ? 'adjustment' : 'credit',
        'reference': reference.isEmpty
            ? (type == 'adjustment' ? 'Adjustment' : 'Credit')
            : reference,
        'description': credit['reason']?.toString().trim().isNotEmpty == true
            ? credit['reason'].toString()
            : _creditTypeLabel(type),
        'debit': 0.0,
        'credit': _asDouble(credit['amount']),
      });
    }

    rows.sort((a, b) {
      final ad = a['date'] as DateTime;
      final bd = b['date'] as DateTime;
      final compare = ad.compareTo(bd);
      if (compare != 0) return compare;

      const priority = {
        'invoice': 0,
        'payment': 1,
        'credit': 2,
        'adjustment': 3,
      };

      return (priority[a['type']] ?? 9).compareTo(priority[b['type']] ?? 9);
    });

    return rows;
  }

  double get _openingBalance {
    final start = _dateOnly(_fromDate);

    return _allTransactions
        .where((row) => (row['date'] as DateTime).isBefore(start))
        .fold(
          0.0,
          (balance, row) =>
              balance + _asDouble(row['debit']) - _asDouble(row['credit']),
        );
  }

  List<Map<String, dynamic>> get _periodTransactions {
    final from = _dateOnly(_fromDate);
    final to = _dateOnly(_toDate);

    return _allTransactions.where((row) {
      final date = row['date'] as DateTime;
      return !date.isBefore(from) && !date.isAfter(to);
    }).toList();
  }

  double get _periodInvoices => _periodTransactions
      .where((row) => row['type'] == 'invoice')
      .fold(0.0, (sum, row) => sum + _asDouble(row['debit']));

  double get _periodPayments => _periodTransactions
      .where((row) => row['type'] == 'payment')
      .fold(0.0, (sum, row) => sum + _asDouble(row['credit']));

  double get _periodCredits => _periodTransactions
      .where((row) => row['type'] == 'credit' || row['type'] == 'adjustment')
      .fold(0.0, (sum, row) => sum + _asDouble(row['credit']));

  double get _closingBalance =>
      _openingBalance + _periodInvoices - _periodPayments - _periodCredits;

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

  String _creditTypeLabel(String value) {
    switch (value) {
      case 'credit_note':
        return 'Credit Note';
      case 'adjustment':
        return 'Adjustment';
      case 'write_off':
        return 'Write Off';
      case 'other':
        return 'Account Credit';
      default:
        return 'Credit';
    }
  }

  String _typeLabel(String value) {
    switch (value) {
      case 'invoice':
        return 'Invoice';
      case 'payment':
        return 'Payment';
      case 'adjustment':
        return 'Adjustment';
      default:
        return 'Credit';
    }
  }

  Color _typeColor(String value) {
    switch (value) {
      case 'payment':
        return const Color(0xFF2E7D32);
      case 'credit':
      case 'adjustment':
        return const Color(0xFF315A8C);
      default:
        return _darkRed;
    }
  }

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: _toDate,
    );

    if (picked != null) {
      setState(() => _fromDate = _dateOnly(picked));
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _toDate = _dateOnly(picked));
    }
  }

  Future<Uint8List> _buildPdf() async {
    final document = pw.Document();

    final rows = _periodTransactions;
    var runningBalance = _openingBalance;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CUTLINK',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'ACCOUNT STATEMENT',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  '${_date(_fromDate)} - ${_date(_toDate)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Generated ${_date(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by CutLink',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (_) => [
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Supplier',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        widget.supplierName,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Customer',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        widget.customerName,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _pdfMetric('Opening Balance', _openingBalance),
              pw.SizedBox(width: 8),
              _pdfMetric('Invoices', _periodInvoices),
              pw.SizedBox(width: 8),
              _pdfMetric('Payments', _periodPayments),
              pw.SizedBox(width: 8),
              _pdfMetric('Credits', _periodCredits),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(1.7),
              3: pw.FlexColumnWidth(2.5),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(1.1),
              6: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfHeader('Date'),
                  _pdfHeader('Type'),
                  _pdfHeader('Reference'),
                  _pdfHeader('Description'),
                  _pdfHeader('Debit'),
                  _pdfHeader('Credit'),
                  _pdfHeader('Balance'),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfCell(_date(_fromDate)),
                  _pdfCell('Balance'),
                  _pdfCell('Opening'),
                  _pdfCell('Opening balance'),
                  _pdfCell(''),
                  _pdfCell(''),
                  _pdfMoney(_openingBalance),
                ],
              ),
              for (final row in rows) ...[
                ...(() {
                  runningBalance +=
                      _asDouble(row['debit']) - _asDouble(row['credit']);

                  return [
                    pw.TableRow(
                      children: [
                        _pdfCell(_date(row['date'])),
                        _pdfCell(_typeLabel(row['type'].toString())),
                        _pdfCell(row['reference'].toString()),
                        _pdfCell(row['description'].toString()),
                        _pdfMoneyOrBlank(_asDouble(row['debit'])),
                        _pdfMoneyOrBlank(_asDouble(row['credit'])),
                        _pdfMoney(runningBalance),
                      ],
                    ),
                  ];
                })(),
              ],
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 230,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Closing Balance',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _money(_closingBalance),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _pdfMetric(String label, double value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              _money(value),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfHeader(String value) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      value,
      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget _pdfCell(String value) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(value, style: const pw.TextStyle(fontSize: 7)),
  );

  pw.Widget _pdfMoney(double value) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(_money(value), style: const pw.TextStyle(fontSize: 7)),
    ),
  );

  pw.Widget _pdfMoneyOrBlank(double value) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        value == 0 ? '' : _money(value),
        style: const pw.TextStyle(fontSize: 7),
      ),
    ),
  );

  Future<void> _downloadPdf() async {
    final bytes = await _buildPdf();

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'CutLink_Statement_${_safeName(widget.customerName)}_'
          '${_isoDate(_fromDate)}_${_isoDate(_toDate)}.pdf',
    );
  }

  String _safeName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return cleaned.isEmpty ? 'Account' : cleaned;
  }

  Widget _metric(String label, double value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0DD)),
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
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateSelector({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFD9D9D5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: _darkRed,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _date(value),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionsTable() {
    final rows = _periodTransactions;
    var running = _openingBalance;

    final displayRows = <Map<String, dynamic>>[];

    for (final row in rows) {
      running += _asDouble(row['debit']) - _asDouble(row['credit']);

      displayRows.add({...row, 'balance': running});
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
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              'Statement Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          const Divider(height: 1),
          if (displayRows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: Text(
                  'No account activity in this date range.',
                  style: TextStyle(color: Color(0xFF777777)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 54,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Reference')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Debit'), numeric: true),
                  DataColumn(label: Text('Credit'), numeric: true),
                  DataColumn(label: Text('Balance'), numeric: true),
                ],
                rows: displayRows.map((row) {
                  final type = row['type'].toString();

                  return DataRow(
                    cells: [
                      DataCell(Text(_date(row['date']))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _typeColor(type).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _typeLabel(type),
                            style: TextStyle(
                              color: _typeColor(type),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          row['reference'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DataCell(Text(row['description'].toString())),
                      DataCell(
                        Text(
                          _asDouble(row['debit']) > 0
                              ? _money(row['debit'])
                              : '—',
                        ),
                      ),
                      DataCell(
                        Text(
                          _asDouble(row['credit']) > 0
                              ? _money(row['credit'])
                              : '—',
                        ),
                      ),
                      DataCell(
                        Text(
                          _money(row['balance']),
                          style: const TextStyle(fontWeight: FontWeight.w900),
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
            const Text(
              'Account Statement',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              widget.supplierView ? widget.customerName : widget.supplierName,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: _loading || _error != null ? null : _downloadPdf,
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Download Statement'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
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
                      onPressed: _loadStatement,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE0E0DD),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'SUPPLIER',
                                            style: TextStyle(
                                              color: Color(0xFF777777),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            widget.supplierName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'CUSTOMER',
                                            style: TextStyle(
                                              color: Color(0xFF777777),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            widget.customerName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _dateSelector(
                              label: 'FROM',
                              value: _fromDate,
                              onTap: _selectFromDate,
                            ),
                            const SizedBox(width: 8),
                            _dateSelector(
                              label: 'TO',
                              value: _toDate,
                              onTap: _selectToDate,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _metric('Opening Balance', _openingBalance),
                            const SizedBox(width: 10),
                            _metric(
                              'Invoices',
                              _periodInvoices,
                              color: _periodInvoices > 0 ? _darkRed : null,
                            ),
                            const SizedBox(width: 10),
                            _metric(
                              'Payments',
                              _periodPayments,
                              color: _periodPayments > 0
                                  ? const Color(0xFF2E7D32)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            _metric(
                              'Credits / Adjustments',
                              _periodCredits,
                              color: _periodCredits > 0
                                  ? const Color(0xFF315A8C)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            _metric(
                              'Closing Balance',
                              _closingBalance,
                              color: _closingBalance > 0 ? _darkRed : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _transactionsTable(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
