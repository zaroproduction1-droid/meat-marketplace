import 'package:flutter/material.dart';

/// Uses only the active prices already returned for this customer by Supabase.
/// A comparison is shown only for a lower price with the same selling basis.
class CustomerPriceDisplay extends StatelessWidget {
  const CustomerPriceDisplay({
    super.key,
    required this.product,
    this.visiblePrice,
    this.alignment = CrossAxisAlignment.start,
    this.fontSize = 18,
    this.showLabel = false,
    this.showSavings = false,
  });

  final Map<String, dynamic> product;
  final Map<String, dynamic>? visiblePrice;
  final CrossAxisAlignment alignment;
  final double fontSize;
  final bool showLabel;
  final bool showSavings;

  static Map<String, dynamic>? selectVisiblePrice(
    Map<String, dynamic> product,
  ) {
    Map<String, dynamic>? selected;
    var priority = 0;
    for (final row in _prices(product)) {
      final list = row['price_lists'];
      if (list is! Map) continue;
      final rank = switch (list['visibility']) {
        'private' => 3,
        'approved_customers' => 2,
        'public' => 1,
        _ => 0,
      };
      if (rank > priority) {
        priority = rank;
        selected = row;
      }
    }
    return selected;
  }

  static Iterable<Map<String, dynamic>> _prices(
    Map<String, dynamic> product,
  ) sync* {
    final prices = product['product_prices'];
    if (prices is! List) return;
    for (final value in prices) {
      if (value is! Map) continue;
      final row = Map<String, dynamic>.from(value);
      final list = row['price_lists'];
      if (row['active'] == true && list is Map && list['active'] == true) {
        yield row;
      }
    }
  }

  static double? _amount(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite && number >= 0 ? number : null;
  }

  static String _basis(dynamic value) => switch (value?.toString()) {
    'kilogram' || 'per_kg' => 'kg',
    'carton' || 'per_carton' => 'carton',
    'unit' || 'per_unit' => 'unit',
    'piece' || 'per_piece' => 'piece',
    'each' => 'each',
    _ => value?.toString() ?? '',
  };

  static String _money(double value, String basis) =>
      '\$${value.toStringAsFixed(2)}${basis.isEmpty ? '' : ' / $basis'}';

  @override
  Widget build(BuildContext context) {
    final selected = visiblePrice ?? selectVisiblePrice(product);
    final amount = _amount(selected?['amount']);
    if (amount == null) {
      return const Text(
        'Contact supplier',
        style: TextStyle(color: Color(0xFF666666), fontWeight: FontWeight.w700),
      );
    }
    final basis = _basis(selected?['price_basis']);
    final selectedList = selected?['price_lists'];
    final visibility = selectedList is Map ? selectedList['visibility'] : null;
    double? original;
    if (visibility == 'private' || visibility == 'approved_customers') {
      for (final row in _prices(product)) {
        final list = row['price_lists'] as Map;
        if (list['visibility'] == 'public' &&
            basis.isNotEmpty &&
            _basis(row['price_basis']) == basis) {
          original = _amount(row['amount']);
          break;
        }
      }
    }
    final reference = original ?? amount;
    final discounted = original != null && reference > amount;
    final label = switch (visibility) {
      'private' => 'Your special price',
      'approved_customers' => 'Your trade price',
      _ => 'Standard price',
    };
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: alignment == CrossAxisAlignment.end
              ? WrapAlignment.end
              : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 3,
          children: [
            Text(
              _money(amount, basis),
              style: TextStyle(
                color: discounted
                    ? const Color(0xFF1B7439)
                    : const Color(0xFF20252B),
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (discounted)
              Text(
                _money(reference, basis),
                semanticsLabel: 'Original price ${_money(reference, basis)}',
                style: TextStyle(
                  fontSize: fontSize * .8,
                  color: const Color(0xFF777777),
                  decoration: TextDecoration.lineThrough,
                  decorationThickness: 2,
                ),
              ),
          ],
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: discounted
                  ? const Color(0xFF1B7439)
                  : const Color(0xFF666666),
            ),
          ),
        ],
        if (showSavings && discounted) ...[
          const SizedBox(height: 4),
          Text(
            'You save ${_money(reference - amount, basis)} • '
            '${((reference - amount) / reference * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B7439),
            ),
          ),
        ],
      ],
    );
  }
}
