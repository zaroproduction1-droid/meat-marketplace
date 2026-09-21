import '../../../shared/animal_catalogues/product_variant.dart';

/// Shared by screens and vector PDFs. No private notes or live prices are read.
Map<String, dynamic> documentProductDetails(Map<String, dynamic> item) {
  final snapshot = item['product_details_snapshot'];
  return snapshot is Map ? Map<String, dynamic>.from(snapshot) : {};
}

String documentProductTitle(Map<String, dynamic> item) {
  final details = documentProductDetails(item);
  final name = item['product_name_snapshot']?.toString().trim() ?? 'Product';
  final code =
      (details['grade_code'] ?? item['grade_code'])?.toString().trim() ?? '';
  final grade =
      (details['grade_name'] ?? item['grade_name'])?.toString().trim() ?? '';
  return [
    name,
    if (code.isNotEmpty) code,
    if (grade.isNotEmpty && grade != code) grade,
  ].join(' - ');
}

String documentProductSpecifications(Map<String, dynamic> item) {
  final details = documentProductDetails(item);
  if (details.isEmpty) {
    return '';
  }
  String clean(dynamic value) =>
      value
          ?.toString()
          .trim()
          .replaceAll('_', ' ')
          .replaceAll(RegExp('[\u2010-\u2015]'), '-') ??
      '';
  final parts = <String>[];
  void add(String label, dynamic value) {
    final text = clean(value);
    if (text.isNotEmpty &&
        !['unknown', 'not specified', 'none'].contains(text.toLowerCase())) {
      parts.add('$label: $text');
    }
  }

  add('Piece size', productSizeLabel(details));
  add('Brand', details['brand']);
  add('Program', details['breed_program']);
  add('Marbling', details['marbling_score']);
  add('Feeding days', details['feeding_days']);
  add('Production', details['production_claim']);
  if (details['hgp_free'] == true) {
    parts.add('HGP free');
  }
  add(
    'Origin',
    [
      clean(details['origin_state']),
      clean(details['origin_country']),
    ].where((value) => value.isNotEmpty).join(', '),
  );
  add('Temperature', details['temperature_state']);
  add('Bone', details['bone_state'] ?? details['chicken_bone']);
  add('Ribs', details['rib_count']);
  add('Skin', details['chicken_skin']);
  add('Production type', details['chicken_production_type']);
  add('Preparation', details['chicken_preparation']);
  add('Trim', details['trim_specification']);
  add('Fat', details['fat_specification']);
  add('Packaging', details['packaging_type']);
  if (details['carton_weight'] != null) {
    add(
      'Carton weight',
      '${details['carton_weight']} ${details['carton_weight_unit'] ?? 'kg'}',
    );
  }
  add('Pieces/carton', details['pieces_per_carton']);
  add('Carton size', details['chicken_carton_size']);
  add('Halal', details['halal_status']);
  add('Specification', details['supplier_specification']);
  final result = parts.join(' | ');
  return result.isNotEmpty && item['_product_details_current'] == true
      ? 'Current product specifications: $result'
      : result;
}

bool invoiceIsPaid(Map<String, dynamic> invoice) =>
    invoice['status'] == 'paid' &&
    (num.tryParse('${invoice['outstanding_amount']}') ?? 0) <= 0;
