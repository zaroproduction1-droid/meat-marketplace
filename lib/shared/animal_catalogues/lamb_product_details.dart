import 'product_variant.dart';

/// Presentation helpers for Lamb's commercial attributes.
///
/// These values stay separate from the canonical cut name so supplier programs,
/// Fat Class and weights remain searchable and reusable throughout CutLink.
abstract final class LambProductDetails {
  static Map<String, dynamic>? _nested(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  static String _clean(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty ||
        const {'not_specified', 'not_applicable', 'unknown'}.contains(value)) {
      return '';
    }
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          if (part.length <= 2) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  static String animalCode(Map<String, dynamic> product) =>
      (_nested(product['meat_animals'])?['code'] ?? product['animal_code'])
          ?.toString()
          .trim()
          .toUpperCase() ??
      '';

  static bool isLamb(Map<String, dynamic> product) =>
      animalCode(product) == 'LAMB';

  static bool isWholeCarcase(Map<String, dynamic> product) {
    final section = _nested(product['meat_sections']);
    final code = (section?['code'] ?? product['section_code'])
        ?.toString()
        .toUpperCase();
    return isLamb(product) && code == 'WHOLE_CARCASE';
  }

  static String fatClass(Map<String, dynamic> product) {
    final value = int.tryParse('${product['fat_class'] ?? ''}');
    return value != null && value >= 1 && value <= 5 ? 'Fat Class $value' : '';
  }

  static String program(Map<String, dynamic> product) =>
      _clean(product['breed_program']);

  static String commercialDescription(Map<String, dynamic> product) =>
      product['commercial_description']?.toString().trim() ?? '';

  static String secondaryLine(Map<String, dynamic> product) {
    if (!isLamb(product)) return '';
    final parts = <String>[
      fatClass(product),
      productSizeLabel(product),
      _clean(product['bone_state']),
      _clean(product['temperature_state']),
      _clean(product['halal_status']),
    ].where((value) => value.isNotEmpty).toSet().toList();
    return parts.join(' • ');
  }

  static String title(Map<String, dynamic> product, String productName) {
    final value = program(product);
    return value.isEmpty ? productName : '$value — $productName';
  }

  static String searchableText(Map<String, dynamic> product) => <String>[
    program(product),
    commercialDescription(product),
    fatClass(product),
    product['lot_batch']?.toString() ?? '',
    product['slaughter_date']?.toString() ?? '',
    product['use_by_date']?.toString() ?? '',
  ].where((value) => value.trim().isNotEmpty).join(' ');
}
