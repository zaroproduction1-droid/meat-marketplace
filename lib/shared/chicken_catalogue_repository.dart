import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/chicken_cut_catalogue.dart';

/// Loads catalogue identity independently of stock, supplier offers and prices.
/// Queries run with the signed-in user's normal RLS permissions.
class ChickenCatalogueRepository {
  const ChickenCatalogueRepository(this.client);
  final SupabaseClient client;

  Future<ChickenCutCatalogue> load() async {
    final animal = await client
        .from('meat_animals')
        .select('id')
        .eq('code', 'CHICKEN')
        .eq('is_active', true)
        .maybeSingle();
    if (animal == null) return const ChickenCutCatalogue();
    final animalId = animal['id'].toString();
    final rows = await Future.wait([
      _loadRows('meat_sections', animalId),
      _loadRows('meat_specifications', animalId),
    ]);
    final sectionIds = rows[0]
        .map((section) => section['id'].toString())
        .toSet();
    return ChickenCutCatalogue(
      sections: rows[0],
      specifications: rows[1]
          .where((spec) => sectionIds.contains(spec['section_id']?.toString()))
          .toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadRows(
    String table,
    String animalId,
  ) async {
    final result = <Map<String, dynamic>>[];
    const pageSize = 500;
    for (var offset = 0; ; offset += pageSize) {
      final page = await client
          .from(table)
          .select()
          .eq('animal_id', animalId)
          .eq('is_active', true)
          .order('display_order')
          .order('id')
          .range(offset, offset + pageSize - 1);
      result.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < pageSize) return result;
    }
  }
}
