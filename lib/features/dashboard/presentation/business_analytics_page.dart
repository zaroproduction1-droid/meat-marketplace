import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/business_analytics_pdf_service.dart';

class BusinessAnalyticsPage extends StatefulWidget {
  const BusinessAnalyticsPage({
    super.key,
    required this.businessId,
    required this.businessType,
    required this.businessName,
    this.embedded = true,
  });

  final String businessId;
  final String businessType;
  final String businessName;
  final bool embedded;

  @override
  State<BusinessAnalyticsPage> createState() => _BusinessAnalyticsPageState();
}

class _BusinessAnalyticsPageState extends State<BusinessAnalyticsPage> {
  static const Color _darkRed = Color(0xFF8B1E2D);
  static const Color _deepNavy = Color(0xFF081625);
  static const Color _canvas = Color(0xFFF7F8FA);
  static const Color _border = Color(0xFFE3E5E8);
  static const Color _muted = Color(0xFF6A6E75);
  static const Color _positive = Color(0xFF2E7D32);
  static const Color _warning = Color(0xFF9A5B00);
  static const Color _danger = Color(0xFFB3261E);

  int _days = 30;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _loading = true;
  bool _exportingPdf = false;
  String? _error;
  Map<String, dynamic> _analytics = const {};

  bool get _isSupplier => widget.businessType == 'supplier';

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _integer(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) {
    final amount = _number(value);
    final abs = amount.abs();
    if (abs >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(abs >= 10000000 ? 1 : 2)}m';
    }
    if (abs >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(abs >= 10000 ? 1 : 2)}k';
    }
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _moneyFull(dynamic value) => '\$${_number(value).toStringAsFixed(2)}';

  String _percent(dynamic value, {int decimals = 1}) {
    if (value == null) {
      return '—';
    }
    return '${_number(value).toStringAsFixed(decimals)}%';
  }

  Map<String, dynamic> get _summary {
    final raw = _analytics['summary'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _analytics[key];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get _periodLabel {
    final start = _customStartDate;
    final end = _customEndDate;
    if (start != null && end != null) {
      if (_dateIso(start) == _dateIso(end)) {
        return _dateLabel(start);
      }
      return '${_dateLabel(start)} – ${_dateLabel(end)}';
    }
    if (_days == 1) {
      return 'Today';
    }
    if (_days == 365) {
      return 'Last 1 year';
    }
    return 'Last $_days days';
  }

  String get _dateRangeChipLabel {
    final start = _customStartDate;
    final end = _customEndDate;
    if (start == null || end == null) {
      return 'Date range';
    }
    return 'From ${_dateLabel(start)} → To ${_dateLabel(end)}';
  }

  String get _comparisonCaption {
    final start = _customStartDate;
    final end = _customEndDate;
    if (start != null && end != null) {
      final periodDays = end.difference(start).inDays + 1;
      return periodDays == 1
          ? 'Compared with the previous day'
          : 'Compared with the previous $periodDays days';
    }
    if (_days == 1) {
      return 'Compared with the previous day';
    }
    if (_days == 365) {
      return 'Compared with the previous year';
    }
    return 'Compared with the previous $_days days';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final params = <String, dynamic>{
        'p_business_id': widget.businessId,
        'p_days': _days,
        'p_start_date': _customStartDate == null
            ? null
            : _dateIso(_customStartDate!),
        'p_end_date': _customEndDate == null ? null : _dateIso(_customEndDate!),
      };

      final response = await Supabase.instance.client.rpc(
        'get_business_analytics',
        params: params,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _analytics = response is Map
            ? Map<String, dynamic>.from(response)
            : <String, dynamic>{};
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _changeDays(int days) {
    if (_days == days && _customStartDate == null && _customEndDate == null) {
      return;
    }
    setState(() {
      _days = days;
      _customStartDate = null;
      _customEndDate = null;
    });
    _load();
  }

  Future<void> _pickDateRange() async {
    final currentStart = _customStartDate;
    final currentEnd = _customEndDate;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _today,
      initialDateRange: currentStart != null && currentEnd != null
          ? DateTimeRange(start: currentStart, end: currentEnd)
          : null,
      helpText: 'Choose analytics date range',
      saveText: 'Apply',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _customStartDate = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _customEndDate = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
    });
    _load();
  }

  Future<void> _downloadPdf() async {
    if (_analytics.isEmpty || _exportingPdf) {
      return;
    }
    setState(() => _exportingPdf = true);
    try {
      final bytes = await BusinessAnalyticsPdfService.build(
        businessName: widget.businessName,
        businessType: widget.businessType,
        periodLabel: _periodLabel,
        analytics: _analytics,
      );
      final safeName = widget.businessName
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final safePeriod = _periodLabel
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'CutLink_${safeName.isEmpty ? 'Business' : safeName}_Analytics_${safePeriod.isEmpty ? 'Period' : safePeriod}.pdf',
      );
    } finally {
      if (mounted) {
        setState(() => _exportingPdf = false);
      }
    }
  }

  Widget _header() {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EAEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: _darkRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSupplier ? 'Business Analytics' : 'Purchasing Analytics',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _isSupplier
                      ? 'Sales, customers, stock and fulfilment performance'
                      : 'Spend, suppliers, products and purchasing performance',
                  style: const TextStyle(
                    color: Color(0xFF74787E),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _loading || _exportingPdf ? null : _downloadPdf,
            icon: _exportingPdf
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 17),
            label: const Text('Download PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _darkRed,
              side: const BorderSide(color: Color(0xFFD7A8AE)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Refresh analytics',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _periodSelector() {
    const options = <int, String>{
      1: 'Today',
      7: '7D',
      30: '30D',
      90: '90D',
      365: '1Y',
    };

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected:
                _customStartDate == null &&
                _customEndDate == null &&
                _days == entry.key,
            onSelected: (_) => _changeDays(entry.key),
            showCheckmark: false,
            side: BorderSide(
              color:
                  _customStartDate == null &&
                      _customEndDate == null &&
                      _days == entry.key
                  ? _darkRed
                  : _border,
            ),
            selectedColor: const Color(0xFFF5EAEA),
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color:
                  _customStartDate == null &&
                      _customEndDate == null &&
                      _days == entry.key
                  ? _darkRed
                  : _muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5),
          ),
        ActionChip(
          avatar: const Icon(Icons.date_range_outlined, size: 16),
          label: Text(_dateRangeChipLabel),
          onPressed: _pickDateRange,
          side: BorderSide(
            color: _customStartDate != null && _customEndDate != null
                ? _darkRed
                : _border,
          ),
          backgroundColor: _customStartDate != null && _customEndDate != null
              ? const Color(0xFFF5EAEA)
              : Colors.white,
          labelStyle: TextStyle(
            color: _customStartDate != null && _customEndDate != null
                ? _darkRed
                : _muted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  double? _changePercent(double current, double previous) {
    if (previous == 0) {
      return current == 0 ? 0 : null;
    }
    return ((current - previous) / previous) * 100;
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required IconData icon,
    String? caption,
    double? change,
    Color? valueColor,
  }) {
    final changeColor = change == null
        ? _muted
        : change >= 0
        ? _positive
        : _danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F0F1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: _darkRed),
              ),
              const Spacer(),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: changeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change >= 0
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: changeColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${change.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 10.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? _deepNavy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8A8E94),
                fontSize: 9.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryGrid() {
    final s = _summary;
    final currentValue = _number(
      _isSupplier ? s['order_value'] : s['purchase_value'],
    );
    final previousValue = _number(
      _isSupplier ? s['previous_order_value'] : s['previous_purchase_value'],
    );
    final orderCount = _integer(s['order_count']);
    final previousCount = _integer(s['previous_order_count']);

    final cards = <Widget>[
      _kpiCard(
        label: _isSupplier ? 'Sales value' : 'Purchase spend',
        value: _money(currentValue),
        icon: _isSupplier
            ? Icons.attach_money_rounded
            : Icons.shopping_cart_checkout_rounded,
        change: _changePercent(currentValue, previousValue),
        caption: _comparisonCaption,
      ),
      _kpiCard(
        label: 'Orders',
        value: '$orderCount',
        icon: Icons.receipt_long_outlined,
        change: _changePercent(orderCount.toDouble(), previousCount.toDouble()),
        caption: 'Non-draft orders in this period',
      ),
      _kpiCard(
        label: 'Average order value',
        value: _money(s['average_order_value']),
        icon: Icons.calculate_outlined,
        caption: 'Average value per order',
      ),
      _kpiCard(
        label: _isSupplier ? 'Outstanding receivables' : 'Outstanding payables',
        value: _money(s['outstanding']),
        icon: Icons.account_balance_wallet_outlined,
        valueColor: _number(s['overdue']) > 0 ? _warning : null,
        caption: _number(s['overdue']) > 0
            ? '${_money(s['overdue'])} overdue'
            : 'No overdue balance',
      ),
      _kpiCard(
        label: _isSupplier
            ? 'Made through CutLink'
            : (_number(s['cutlink_saved']) >= 0
                  ? 'Saved with CutLink'
                  : 'Public price difference'),
        value: _money(_isSupplier ? s['cutlink_made'] : s['cutlink_saved']),
        icon: _isSupplier ? Icons.hub_outlined : Icons.savings_outlined,
        valueColor: !_isSupplier && _number(s['cutlink_saved']) < 0
            ? _warning
            : _positive,
        caption: _isSupplier
            ? '${_percent(s['cutlink_marketplace_share'])} of sales came through the CutLink marketplace'
            : '${_percent(s['cutlink_savings_coverage'])} of spend has a valid public-price benchmark',
      ),
      _kpiCard(
        label: 'Completion rate',
        value: _percent(s['completion_rate']),
        icon: Icons.task_alt_rounded,
        valueColor: _number(s['completion_rate']) >= 90 ? _positive : null,
        caption: 'Orders completed in this period',
      ),
      _kpiCard(
        label: 'Issue rate',
        value: _percent(s['issue_rate']),
        icon: Icons.report_problem_outlined,
        valueColor: _number(s['issue_rate']) > 5 ? _danger : null,
        caption: 'Orders with a reported issue',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1250
            ? 6
            : constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _deepNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          child,
        ],
      ),
    );
  }

  Widget _trendCard() {
    final trend = _list('trend');
    return _sectionCard(
      title: _isSupplier ? 'Sales trend' : 'Purchasing trend',
      subtitle: 'Hover or tap any day to see the exact value • $_periodLabel',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
        child: SizedBox(
          height: 235,
          child: trend.isEmpty
              ? _emptyState('No order activity in this period')
              : _TrendChart(data: trend, darkRed: _darkRed),
        ),
      ),
    );
  }

  Widget _rankingCard({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> data,
  }) {
    final maxValue = data.fold<double>(
      0,
      (maxValue, row) => math.max(maxValue, _number(row['value'])),
    );

    return _sectionCard(
      title: title,
      subtitle: subtitle,
      child: data.isEmpty
          ? SizedBox(height: 220, child: _emptyState('No data in this period'))
          : Column(
              children: [
                for (var i = 0; i < data.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i < 3
                                ? const Color(0xFFF7F0F1)
                                : const Color(0xFFF4F5F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i < 3 ? _darkRed : _muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data[i]['label']?.toString() ?? 'Unknown',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  minHeight: 5,
                                  value: maxValue <= 0
                                      ? 0
                                      : (_number(data[i]['value']) / maxValue)
                                            .clamp(0, 1),
                                  backgroundColor: const Color(0xFFF0F1F2),
                                  valueColor: const AlwaysStoppedAnimation(
                                    _darkRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _moneyFull(data[i]['value']),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (data[i]['orders'] != null)
                              Text(
                                '${_integer(data[i]['orders'])} orders',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 9.5,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (i != data.length - 1)
                    const Divider(height: 1, indent: 15, endIndent: 15),
                ],
              ],
            ),
    );
  }

  Widget _animalMixCard() {
    final data = _list('animal_mix');
    final total = data.fold<double>(
      0,
      (sum, row) => sum + _number(row['value']),
    );

    return _sectionCard(
      title: _isSupplier ? 'Sales by animal' : 'Spend by animal',
      subtitle: 'Where order value is concentrated',
      child: data.isEmpty
          ? SizedBox(height: 220, child: _emptyState('No category data yet'))
          : Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  for (var i = 0; i < data.length; i++) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            data[i]['label']?.toString() ?? 'Other',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: total <= 0
                                  ? 0
                                  : (_number(data[i]['value']) / total).clamp(
                                      0,
                                      1,
                                    ),
                              backgroundColor: const Color(0xFFF0F1F2),
                              valueColor: AlwaysStoppedAnimation(_mixColour(i)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 55,
                          child: Text(
                            total <= 0
                                ? '0%'
                                : '${((_number(data[i]['value']) / total) * 100).toStringAsFixed(0)}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i != data.length - 1) const SizedBox(height: 13),
                  ],
                ],
              ),
            ),
    );
  }

  Color _mixColour(int index) {
    const colours = [
      _darkRed,
      Color(0xFF315A8C),
      Color(0xFF9A5B00),
      Color(0xFF2E7D32),
      Color(0xFF6A4C93),
      Color(0xFF47666D),
    ];
    return colours[index % colours.length];
  }

  Widget _statusCard() {
    final rows = _list('status_mix');
    final total = rows.fold<int>(0, (sum, row) => sum + _integer(row['count']));

    return _sectionCard(
      title: 'Order status',
      subtitle: 'Current mix for orders in the selected period',
      child: rows.isEmpty
          ? SizedBox(
              height: 180,
              child: _emptyState('No orders in this period'),
            )
          : Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: _statusColour(rows[i]['label']?.toString()),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _statusLabel(rows[i]['label']?.toString()),
                            style: const TextStyle(
                              fontSize: 10.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${_integer(rows[i]['count'])}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 38,
                          child: Text(
                            total == 0
                                ? '0%'
                                : '${((_integer(rows[i]['count']) / total) * 100).toStringAsFixed(0)}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i != rows.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }

  String _statusLabel(String? status) {
    if (status == null || status.isEmpty) {
      return 'Unknown';
    }
    return status
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Color _statusColour(String? status) {
    switch (status) {
      case 'completed':
      case 'delivered':
        return _positive;
      case 'processing':
      case 'accepted':
        return const Color(0xFF315A8C);
      case 'submitted':
        return _warning;
      case 'cancelled':
      case 'rejected':
        return _danger;
      default:
        return _muted;
    }
  }

  Widget _supplierOperationsCard() {
    final s = _summary;
    final active = _integer(s['active_products']);
    final inStock = _integer(s['in_stock_products']);
    final limited = _integer(s['limited_products']);
    final out = _integer(s['out_of_stock_products']);
    final inStockPct = active == 0 ? 0.0 : (inStock / active) * 100;

    return _sectionCard(
      title: 'Inventory health',
      subtitle: 'Availability across your active catalogue',
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _miniStat('Active', '$active', _deepNavy)),
                const SizedBox(width: 8),
                Expanded(child: _miniStat('In stock', '$inStock', _positive)),
                const SizedBox(width: 8),
                Expanded(child: _miniStat('Limited', '$limited', _warning)),
                const SizedBox(width: 8),
                Expanded(child: _miniStat('Out', '$out', _danger)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Text(
                  'In-stock coverage',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${inStockPct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: (inStockPct / 100).clamp(0, 1),
                backgroundColor: const Color(0xFFF0F1F2),
                valueColor: const AlwaysStoppedAnimation(_positive),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 17,
                  color: _muted,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'On-time fulfilment',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _percent(s['on_time_rate']),
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

  Widget _butcherSupplierRiskCard() {
    final concentration = _number(_summary['top_supplier_concentration']);
    final riskColor = concentration >= 60
        ? _danger
        : concentration >= 40
        ? _warning
        : _positive;

    return _sectionCard(
      title: 'Supplier concentration',
      subtitle: 'Share of spend going to your largest supplier',
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${concentration.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    concentration >= 60
                        ? 'High concentration'
                        : concentration >= 40
                        ? 'Moderate concentration'
                        : 'Diversified',
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: (concentration / 100).clamp(0, 1),
                backgroundColor: const Color(0xFFF0F1F2),
                valueColor: AlwaysStoppedAnimation(riskColor),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'A very high share can increase exposure to price changes, stock shortages or service disruption from one supplier.',
              style: TextStyle(color: _muted, fontSize: 10.2, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 9.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<_Insight> _insights() {
    final s = _summary;
    final result = <_Insight>[];
    final current = _number(
      _isSupplier ? s['order_value'] : s['purchase_value'],
    );
    final previous = _number(
      _isSupplier ? s['previous_order_value'] : s['previous_purchase_value'],
    );
    final change = _changePercent(current, previous);

    if (change != null && change.abs() >= 5) {
      result.add(
        _Insight(
          icon: change >= 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          title: change >= 0
              ? (_isSupplier
                    ? 'Sales are trending up'
                    : 'Purchasing spend is higher')
              : (_isSupplier
                    ? 'Sales are trending down'
                    : 'Purchasing spend is lower'),
          body:
              '${change.abs().toStringAsFixed(1)}% ${change >= 0 ? 'above' : 'below'} the previous $_days-day period.',
          colour: change >= 0 ? _positive : _warning,
        ),
      );
    }

    final overdue = _number(s['overdue']);
    if (overdue > 0) {
      result.add(
        _Insight(
          icon: Icons.schedule_rounded,
          title: _isSupplier
              ? 'Overdue money needs attention'
              : 'Overdue invoices need attention',
          body: '${_moneyFull(overdue)} is currently overdue.',
          colour: _danger,
        ),
      );
    }

    final issueRate = _number(s['issue_rate']);
    if (issueRate > 5) {
      result.add(
        _Insight(
          icon: Icons.report_problem_outlined,
          title: 'Issue rate is elevated',
          body:
              '${issueRate.toStringAsFixed(1)}% of orders had a reported issue in this period.',
          colour: _warning,
        ),
      );
    }

    if (_isSupplier) {
      final out = _integer(s['out_of_stock_products']);
      final limited = _integer(s['limited_products']);
      if (out + limited > 0) {
        result.add(
          _Insight(
            icon: Icons.inventory_2_outlined,
            title: 'Catalogue availability needs review',
            body:
                '$out products are out of stock and $limited are marked limited.',
            colour: out > 0 ? _danger : _warning,
          ),
        );
      }
    } else {
      final concentration = _number(s['top_supplier_concentration']);
      if (concentration >= 50) {
        result.add(
          _Insight(
            icon: Icons.hub_outlined,
            title: 'Purchasing is concentrated',
            body:
                '${concentration.toStringAsFixed(1)}% of spend is with your largest supplier.',
            colour: concentration >= 65 ? _danger : _warning,
          ),
        );
      }
    }

    if (result.isEmpty) {
      result.add(
        const _Insight(
          icon: Icons.check_circle_outline_rounded,
          title: 'No major exceptions detected',
          body:
              'The selected period does not show any obvious performance warning from the metrics available in CutLink.',
          colour: _positive,
        ),
      );
    }

    return result.take(4).toList();
  }

  Widget _insightsCard() {
    final insights = _insights();
    return _sectionCard(
      title: 'Business insights',
      subtitle: 'Automatic highlights from your CutLink activity',
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            for (var i = 0; i < insights.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: insights[i].colour.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      insights[i].icon,
                      size: 17,
                      color: insights[i].colour,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insights[i].title,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insights[i].body,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i != insights.length - 1) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.query_stats_rounded,
            color: Color(0xFFB0B3B7),
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: _darkRed, size: 46),
                const SizedBox(height: 12),
                const Text(
                  'Analytics could not be loaded',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.businessName,
                              style: const TextStyle(
                                color: _deepNavy,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isSupplier
                                  ? 'Track the numbers that drive sales, cash flow, stock availability and service.'
                                  : 'Understand purchasing spend, supplier dependence, product mix and order performance.',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _periodSelector(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _summaryGrid(),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 980) {
                        return Column(
                          children: [
                            _trendCard(),
                            const SizedBox(height: 14),
                            _insightsCard(),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _trendCard()),
                          const SizedBox(width: 14),
                          Expanded(child: _insightsCard()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final primaryRanking = _rankingCard(
                        title: _isSupplier ? 'Top customers' : 'Top suppliers',
                        subtitle: _isSupplier
                            ? 'Customers ranked by order value'
                            : 'Suppliers ranked by purchasing spend',
                        data: _list(
                          _isSupplier ? 'top_customers' : 'top_suppliers',
                        ),
                      );
                      final productRanking = _rankingCard(
                        title: _isSupplier
                            ? 'Top products'
                            : 'Top purchased products',
                        subtitle: 'Products ranked by order value',
                        data: _list('top_products'),
                      );
                      if (constraints.maxWidth < 900) {
                        return Column(
                          children: [
                            primaryRanking,
                            const SizedBox(height: 14),
                            productRanking,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: primaryRanking),
                          const SizedBox(width: 14),
                          Expanded(child: productRanking),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final operational = _isSupplier
                          ? _supplierOperationsCard()
                          : _butcherSupplierRiskCard();
                      if (constraints.maxWidth < 900) {
                        return Column(
                          children: [
                            _animalMixCard(),
                            const SizedBox(height: 14),
                            _statusCard(),
                            const SizedBox(height: 14),
                            operational,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _animalMixCard()),
                          const SizedBox(width: 14),
                          Expanded(child: _statusCard()),
                          const SizedBox(width: 14),
                          Expanded(child: operational),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F3F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: _muted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Analytics are calculated from CutLink order, invoice, product, stock and issue records. Profit and gross margin are intentionally not shown until reliable cost-of-goods data is available.',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 9.8,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = ColoredBox(
      color: _canvas,
      child: Column(
        children: [
          _header(),
          Expanded(child: _content()),
        ],
      ),
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(child: body),
    );
  }
}

class BusinessAnalyticsOverviewPanel extends StatefulWidget {
  const BusinessAnalyticsOverviewPanel({
    super.key,
    required this.businessId,
    required this.businessType,
  });

  final String businessId;
  final String businessType;

  @override
  State<BusinessAnalyticsOverviewPanel> createState() =>
      _BusinessAnalyticsOverviewPanelState();
}

class _BusinessAnalyticsOverviewPanelState
    extends State<BusinessAnalyticsOverviewPanel> {
  static const Color _darkRed = Color(0xFF8B1E2D);
  static const Color _border = Color(0xFFE3E5E8);
  static const Color _muted = Color(0xFF6A6E75);

  int _days = 30;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _analytics = const {};

  bool get _isSupplier => widget.businessType == 'supplier';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BusinessAnalyticsOverviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId ||
        oldWidget.businessType != widget.businessType) {
      _load();
    }
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _integer(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) {
    final amount = _number(value);
    final raw = amount.toStringAsFixed(2);
    final parts = raw.split('.');
    final negative = parts.first.startsWith('-');
    final whole = negative ? parts.first.substring(1) : parts.first;
    final decimals = parts.last;
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '${negative ? '-' : ''}\$${buffer.toString()}.$decimals';
  }

  Map<String, dynamic> get _summary {
    final raw = _analytics['summary'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> get _trend {
    final raw = _analytics['trend'];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'get_business_analytics',
        params: {
          'p_business_id': widget.businessId,
          'p_days': _days,
          'p_start_date': null,
          'p_end_date': null,
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _analytics = response is Map
            ? Map<String, dynamic>.from(response)
            : <String, dynamic>{};
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _changeDays(int days) {
    if (_days == days) {
      return;
    }
    setState(() => _days = days);
    _load();
  }

  String get _periodLabel {
    if (_days == 1) {
      return 'Today';
    }
    if (_days == 365) {
      return 'Last 1 year';
    }
    return 'Last $_days days';
  }

  @override
  Widget build(BuildContext context) {
    const options = <int, String>{
      1: 'Today',
      7: '7D',
      30: '30D',
      90: '90D',
      365: '1Y',
    };

    if (_loading && _analytics.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _analytics.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB3261E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    final summary = _summary;
    final value = _number(
      _isSupplier ? summary['order_value'] : summary['purchase_value'],
    );
    final orders = _integer(summary['order_count']);
    final trend = _trend;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in options.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _days == entry.key,
                      onSelected: (_) => _changeDays(entry.key),
                      showCheckmark: false,
                      side: BorderSide(
                        color: _days == entry.key ? _darkRed : _border,
                      ),
                      selectedColor: const Color(0xFFF5EAEA),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _days == entry.key ? _darkRed : _muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _OverviewMetric(
                label: _isSupplier ? 'Sales' : 'Purchases',
                value: _money(value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewMetric(label: 'Orders', value: '$orders'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewMetric(
                label: 'Average order',
                value: _money(summary['average_order_value']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '$_periodLabel • Hover or tap the graph for the exact daily value',
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: trend.isEmpty
              ? const Center(
                  child: Text(
                    'No activity in this period',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : _TrendChart(data: trend, darkRed: _darkRed),
        ),
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7E9EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6A6E75),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF081625),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Insight {
  const _Insight({
    required this.icon,
    required this.title,
    required this.body,
    required this.colour,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color colour;
}

class _TrendChart extends StatefulWidget {
  const _TrendChart({required this.data, required this.darkRed});

  final List<Map<String, dynamic>> data;
  final Color darkRed;

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  int? _selectedIndex;

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _label(dynamic raw, {bool full = false}) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (parsed == null) {
      return '';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return full
        ? '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}'
        : '${parsed.day} ${months[parsed.month - 1]}';
  }

  String _money(double value) {
    final raw = value.toStringAsFixed(2);
    final parts = raw.split('.');
    final whole = parts.first;
    final decimals = parts.last;
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '\$${buffer.toString()}.$decimals';
  }

  int _nearestIndex(double dx, double width) {
    if (widget.data.length <= 1 || width <= 0) {
      return 0;
    }
    return ((dx / width) * (widget.data.length - 1))
        .round()
        .clamp(0, widget.data.length - 1)
        .toInt();
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.data.map((e) => _number(e['value'])).toList();
    final maxValue = values.fold<double>(0, math.max);
    final total = values.fold<double>(0, (sum, value) => sum + value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              _money(total),
              style: const TextStyle(
                color: Color(0xFF081625),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'total',
              style: TextStyle(color: Color(0xFF777C82), fontSize: 10),
            ),
            const Spacer(),
            if (_selectedIndex != null)
              Text(
                '${_label(widget.data[_selectedIndex!]['bucket'], full: true)}  •  ${_money(values[_selectedIndex!])}',
                style: TextStyle(
                  color: widget.darkRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return MouseRegion(
                cursor: SystemMouseCursors.precise,
                onHover: (event) {
                  final next = _nearestIndex(
                    event.localPosition.dx,
                    constraints.maxWidth,
                  );
                  if (next != _selectedIndex) {
                    setState(() => _selectedIndex = next);
                  }
                },
                onExit: (_) => setState(() => _selectedIndex = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    setState(() {
                      _selectedIndex = _nearestIndex(
                        details.localPosition.dx,
                        constraints.maxWidth,
                      );
                    });
                  },
                  child: CustomPaint(
                    painter: _TrendPainter(
                      values: values,
                      maxValue: maxValue,
                      lineColor: widget.darkRed,
                      selectedIndex: _selectedIndex,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _label(widget.data.first['bucket']),
                style: const TextStyle(color: Color(0xFF8A8E94), fontSize: 9),
              ),
            ),
            if (widget.data.length > 2)
              Text(
                _label(widget.data[widget.data.length ~/ 2]['bucket']),
                style: const TextStyle(color: Color(0xFF8A8E94), fontSize: 9),
              ),
            Expanded(
              child: Text(
                _label(widget.data.last['bucket']),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Color(0xFF8A8E94), fontSize: 9),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.maxValue,
    required this.lineColor,
    required this.selectedIndex,
  });

  final List<double> values;
  final double maxValue;
  final Color lineColor;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFECEEF0)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) {
      return;
    }

    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height - ((values[i] / safeMax) * (size.height * 0.88));
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.16),
            lineColor.withValues(alpha: 0.01),
          ],
        ).createShader(Offset.zero & size),
    );

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (points.length <= 40) {
      final dotPaint = Paint()..color = lineColor;
      for (final point in points) {
        canvas.drawCircle(point, 2.4, dotPaint);
      }
    }

    if (selectedIndex != null && selectedIndex! < points.length) {
      final point = points[selectedIndex!];
      canvas.drawLine(
        Offset(point.dx, 0),
        Offset(point.dx, size.height),
        Paint()
          ..color = lineColor.withValues(alpha: 0.25)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(point, 5.2, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3.6, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
