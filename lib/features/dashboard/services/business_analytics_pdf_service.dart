import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class BusinessAnalyticsPdfService {
  const BusinessAnalyticsPdfService._();

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _integer(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _money(dynamic value) =>
      '\$${_number(value).toStringAsFixed(2)}';

  static String _percent(dynamic value) {
    if (value == null) return '—';
    return '${_number(value).toStringAsFixed(1)}%';
  }

  static String _date(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (parsed == null) return raw?.toString() ?? '—';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  static Map<String, dynamic> _map(dynamic raw) {
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(
    Map<String, dynamic> analytics,
    String key,
  ) {
    final raw = analytics[key];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static pw.Widget _sectionTitle(String title, {String? subtitle}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          if (subtitle != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _kpi(String label, String value, {String? note}) {
    return pw.Container(
      width: 164,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          if (note != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              note,
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _rankingTable(
    String title,
    List<Map<String, dynamic>> rows,
    String valueLabel,
  ) {
    if (rows.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(title),
        pw.TableHelper.fromTextArray(
          headers: ['#', 'Name', valueLabel, 'Orders'],
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          data: [
            for (var i = 0; i < rows.length; i++)
              [
                '${i + 1}',
                rows[i]['label']?.toString() ?? 'Unknown',
                _money(rows[i]['value']),
                rows[i]['orders'] == null
                    ? '—'
                    : '${_integer(rows[i]['orders'])}',
              ],
          ],
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
      ],
    );
  }

  static Future<Uint8List> build({
    required String businessName,
    required String businessType,
    required String periodLabel,
    required Map<String, dynamic> analytics,
  }) async {
    final document = pw.Document();
    final supplier = businessType == 'supplier';
    final summary = _map(analytics['summary']);
    final trend = _list(
      analytics,
      'trend',
    ).where((row) => _number(row['value']) != 0).toList();
    final primaryRanking = _list(
      analytics,
      supplier ? 'top_customers' : 'top_suppliers',
    );
    final topProducts = _list(analytics, 'top_products');
    final animalMix = _list(analytics, 'animal_mix');
    final statusMix = _list(analytics, 'status_mix');

    final cutlinkValue = _number(
      supplier ? summary['cutlink_made'] : summary['cutlink_saved'],
    );
    final cutlinkLabel = supplier
        ? 'Made through CutLink'
        : cutlinkValue >= 0
        ? 'Saved with CutLink'
        : 'Public price difference';
    final cutlinkNote = supplier
        ? '${_percent(summary['cutlink_marketplace_share'])} of selected-period sales came through the CutLink marketplace.'
        : '${_percent(summary['cutlink_savings_coverage'])} of selected-period spend had a valid public-price benchmark.';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Row(
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
                  supplier
                      ? 'SUPPLIER ANALYTICS'
                      : 'BUTCHER PURCHASING ANALYTICS',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 8.5)),
                pw.Text(
                  'Generated ${_date(analytics['generated_at'])}',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CutLink business analytics',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text(
            supplier
                ? 'Sales, customers, stock and fulfilment performance'
                : 'Purchasing, suppliers, products and order performance',
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kpi(
                supplier ? 'Sales value' : 'Purchase spend',
                _money(summary[supplier ? 'order_value' : 'purchase_value']),
              ),
              _kpi('Orders', '${_integer(summary['order_count'])}'),
              _kpi(
                'Average order value',
                _money(summary['average_order_value']),
              ),
              _kpi(
                supplier ? 'Outstanding receivables' : 'Outstanding payables',
                _money(summary['outstanding']),
                note: '${_money(summary['overdue'])} overdue',
              ),
              _kpi(cutlinkLabel, _money(cutlinkValue), note: cutlinkNote),
              _kpi('Completion rate', _percent(summary['completion_rate'])),
              _kpi('Issue rate', _percent(summary['issue_rate'])),
              if (supplier)
                _kpi('On-time rate', _percent(summary['on_time_rate'])),
            ],
          ),
          pw.SizedBox(height: 18),
          _sectionTitle(
            supplier ? 'Daily sales activity' : 'Daily purchasing activity',
            subtitle:
                'Only days with activity are shown below. The selected period is $periodLabel.',
          ),
          if (trend.isEmpty)
            pw.Text(
              'No order value was recorded in this period.',
              style: const pw.TextStyle(fontSize: 9),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', supplier ? 'Sales value' : 'Purchase value'],
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              data: [
                for (final row in trend)
                  [_date(row['bucket']), _money(row['value'])],
              ],
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          pw.SizedBox(height: 18),
          _rankingTable(
            supplier ? 'Top customers' : 'Top suppliers',
            primaryRanking,
            supplier ? 'Sales' : 'Spend',
          ),
          pw.SizedBox(height: 16),
          _rankingTable(
            'Top products',
            topProducts,
            supplier ? 'Sales' : 'Spend',
          ),
          if (animalMix.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle(supplier ? 'Sales by animal' : 'Spend by animal'),
            pw.TableHelper.fromTextArray(
              headers: ['Animal', supplier ? 'Sales' : 'Spend'],
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              data: [
                for (final row in animalMix)
                  [row['label']?.toString() ?? 'Other', _money(row['value'])],
              ],
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
          if (statusMix.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('Order status'),
            pw.TableHelper.fromTextArray(
              headers: const ['Status', 'Orders'],
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              data: [
                for (final row in statusMix)
                  [
                    row['label']?.toString() ?? 'Unknown',
                    '${_integer(row['count'])}',
                  ],
              ],
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
          if (!supplier)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 14),
              child: pw.Text(
                'Savings methodology: compares the actual CutLink order-item value with the supplier public price for the same product, price basis and order date where a valid benchmark exists. A negative value means the benchmarked CutLink purchase price was higher than the public-price benchmark for the covered spend.',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          if (supplier)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 14),
              child: pw.Text(
                'Made through CutLink is the value of selected-period orders that originated through the CutLink marketplace. Manual supplier-entered sales are excluded from this CutLink marketplace figure.',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey700,
                ),
              ),
            ),
        ],
      ),
    );

    return document.save();
  }
}
