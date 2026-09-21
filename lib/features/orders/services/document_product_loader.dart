import 'package:supabase_flutter/supabase_flutter.dart';

import 'document_product_details.dart';

/// Uses frozen specifications where recorded. Legacy lookups are labelled as
/// current information and never written into historical document records.
Future<List<Map<String, dynamic>>> loadDocumentProductDetails(
  List<Map<String, dynamic>> items,
) async {
  final missing = items
      .where((item) => documentProductDetails(item).isEmpty)
      .map((item) => item['product_id'])
      .whereType<String>()
      .toSet()
      .toList();
  final current = <String, Map<String, dynamic>>{};
  for (var start = 0; start < missing.length; start += 80) {
    final rows = await Supabase.instance.client
        .from('products')
        .select(
          'id,brand,origin_country,origin_state,temperature_state,marbling_score,'
          'breed_program,piece_size_kind,piece_weight_min,piece_weight_max,piece_weight_unit,'
          'carton_weight,carton_weight_unit,pieces_per_carton,packaging_type,'
          'trim_specification,fat_specification,halal_status,supplier_specification,'
          'chicken_skin,chicken_bone,chicken_production_type,chicken_preparation,'
          'chicken_size_weight,chicken_carton_size,feeding_days,bone_state,rib_count,'
          'production_claim,hgp_free,meat_grades(code,name),meat_animals(code,name),'
          'meat_sections(name),meat_specifications(name,ham_code)',
        )
        .inFilter('id', missing.skip(start).take(80).toList());
    for (final row in rows) {
      Map<String, dynamic> nested(String key) =>
          row[key] is Map ? Map<String, dynamic>.from(row[key] as Map) : {};
      current[row['id'].toString()] = {
        ...row,
        'grade_code': nested('meat_grades')['code'],
        'grade_name': nested('meat_grades')['name'],
        'animal_name': nested('meat_animals')['name'],
        'animal_code': nested('meat_animals')['code'],
        'section_name': nested('meat_sections')['name'],
        'specification_name': nested('meat_specifications')['name'],
        'ham_code': nested('meat_specifications')['ham_code'],
      };
    }
  }
  return items.map((item) {
    final snapshot = documentProductDetails(item);
    final legacy = snapshot.isEmpty;
    final details = legacy
        ? current[item['product_id']] ?? <String, dynamic>{}
        : snapshot;
    return <String, dynamic>{
      ...item,
      'product_details_snapshot': details,
      if (legacy && details.isNotEmpty) '_product_details_current': true,
      for (final key in [
        'grade_code',
        'grade_name',
        'animal_name',
        'animal_code',
        'section_name',
        'specification_name',
        'ham_code',
      ])
        key: details[key],
    };
  }).toList();
}
