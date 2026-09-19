/// A piece's size is independent of carton weight and ordering quantity.
class ProductPieceSize {
  const ProductPieceSize(this.kind, this.min, this.max, this.unit);
  final String? kind;
  final double? min;
  final double? max;
  final String unit;

  factory ProductPieceSize.fromProduct(Map<String, dynamic> product) {
    double? number(dynamic value) => double.tryParse('$value');
    return ProductPieceSize(
      product['piece_size_kind']?.toString(),
      number(product['piece_weight_min']),
      number(product['piece_weight_max']),
      product['piece_weight_unit'] == 'g' ? 'g' : 'kg',
    );
  }

  String get effectiveKind =>
      kind ??
      (min != null && max != null
          ? (min == max ? 'exact' : 'range')
          : min != null
          ? 'at_least'
          : max != null
          ? 'up_to'
          : 'none');

  String? get error {
    if (effectiveKind == 'none') return null;
    if (![
      'exact',
      'range',
      'at_least',
      'under',
      'up_to',
    ].contains(effectiveKind)) {
      return 'Choose a size type.';
    }
    final lowerNeeded = ['exact', 'range', 'at_least'].contains(effectiveKind);
    final upperNeeded = ['range', 'under', 'up_to'].contains(effectiveKind);
    if (lowerNeeded && (min == null || !min!.isFinite || min! <= 0) ||
        upperNeeded && (max == null || !max!.isFinite || max! <= 0)) {
      return 'Enter a piece weight greater than zero.';
    }
    if (effectiveKind == 'range' && max! <= min!) {
      return 'Maximum must be greater than minimum.';
    }
    return null;
  }

  static String number(double value) => value
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');

  String get label {
    if (min == null && max == null) return '';
    final low = min == null ? '' : number(min!);
    final high = max == null ? '' : number(max!);
    return switch (effectiveKind) {
      'exact' => '$low $unit',
      'range' => '$low–$high $unit',
      'at_least' => '$low $unit+',
      'under' => 'Under $high $unit',
      'up_to' => 'Up to $high $unit',
      _ => '',
    };
  }

  Map<String, dynamic> get fields {
    final type = effectiveKind;
    return {
      'piece_size_kind': type == 'none' ? null : type,
      'piece_weight_min': ['exact', 'range', 'at_least'].contains(type)
          ? min
          : null,
      'piece_weight_max': type == 'exact'
          ? min
          : ['range', 'under', 'up_to'].contains(type)
          ? max
          : null,
      'piece_weight_unit': type == 'none' ? null : unit,
    };
  }
}

String productSizeLabel(Map<String, dynamic> product) {
  final weight = ProductPieceSize.fromProduct(product).label;
  if (weight.isNotEmpty) return weight;
  return product['chicken_size_weight']?.toString().trim() ?? '';
}

String productProgram(Map<String, dynamic> product) {
  final text = product['breed_program']?.toString().trim() ?? '';
  if (text.toLowerCase().contains('wagyu')) return 'Wagyu';
  if (text.toLowerCase().contains('angus')) return 'Angus';
  return text;
}
