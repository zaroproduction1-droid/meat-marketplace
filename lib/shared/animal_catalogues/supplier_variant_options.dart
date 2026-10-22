/// Stable values shared by supplier dropdowns and exact buyer filters.
/// These are product attributes, not new cuts or invented quality grades.
class SupplierVariantOptions {
  static const animals = {'CHICKEN', 'LAMB', 'MUTTON', 'GOAT', 'VEAL'};
  static bool supports(String? animal) => animals.contains(animal);

  static const labels = <String, String>{
    'bone': 'Bone',
    'skin': 'Skin',
    'preparation': 'Preparation',
    'cap': 'Cap',
    'rack_style': 'Rack style',
    'rib_count': 'Rib count',
    'tender': 'Tender',
    'production': 'Production type',
    'fat_trim': 'Fat trim',
  };
  static const choices = <String, Map<String, String>>{
    'bone': {'bone_in': 'Bone in', 'boneless': 'Boneless'},
    'skin': {'skin_on': 'Skin on', 'skin_off': 'Skin off'},
    'preparation': {
      'whole': 'Whole',
      'trimmed': 'Trimmed',
      'untrimmed': 'Untrimmed',
      'fillet': 'Fillet',
      'sliced': 'Sliced',
      'diced': 'Diced',
      'strips': 'Strips',
      'minced': 'Minced',
      'butterflied': 'Butterflied',
      'schnitzel': 'Schnitzel',
      'portion_controlled': 'Portion controlled',
      'rolled_netted': 'Rolled and netted',
    },
    'cap': {'cap_on': 'Cap on', 'cap_off': 'Cap off'},
    'rack_style': {'standard': 'Standard rack', 'frenched': 'Frenched'},
    'rib_count': {
      '1': '1 rib',
      '2': '2 ribs',
      '3': '3 ribs',
      '4': '4 ribs',
      '5': '5 ribs',
      '6': '6 ribs',
      '7': '7 ribs',
      '8': '8 ribs',
      '9': '9 ribs',
      '10': '10 ribs',
      '11': '11 ribs',
      '12': '12 ribs',
      '13': '13 ribs',
      '14': '14 ribs',
      '15': '15 ribs',
      '16': '16 ribs',
      '17': '17 ribs',
      '18': '18 ribs',
      '19': '19 ribs',
      '20': '20 ribs',
    },
    'tender': {'tender_on': 'Tender on', 'tender_off': 'Tender off'},
    'production': {
      'conventional': 'Conventional',
      'free_range': 'Free range',
      'organic': 'Organic',
      'grass_fed': 'Grass fed',
      'grain_fed': 'Grain fed',
      'mixed': 'Mixed feed',
    },
    'fat_trim': {
      'fat_on': 'Fat on',
      'fat_off': 'Fat off',
      '0_mm': '0 mm',
      '3_mm': '3 mm',
      '5_mm': '5 mm',
      '10_mm': '10 mm',
    },
  };

  static List<String> fields(String? animal) => !supports(animal)
      ? const []
      : animal == 'CHICKEN'
      ? const ['bone', 'skin', 'preparation', 'tender', 'production']
      : const [
          'bone',
          'preparation',
          'cap',
          'rack_style',
          'rib_count',
          'production',
          'fat_trim',
        ];

  static Map<String, String> options(String? animal, String field) {
    if (!fields(animal).contains(field)) {
      return const {};
    }
    final all = choices[field]!;
    if (field == 'production') {
      final allowed = animal == 'CHICKEN'
          ? const {'conventional', 'free_range', 'organic'}
          : const {'grass_fed', 'grain_fed', 'mixed'};
      return Map.fromEntries(all.entries.where((e) => allowed.contains(e.key)));
    }
    if (field == 'preparation' && animal == 'CHICKEN') {
      return Map.fromEntries(
        all.entries.where((e) => e.key != 'rolled_netted'),
      );
    }
    return all;
  }

  static Map<String, String> normalise(String? animal, dynamic raw) => {
    if (raw is Map)
      for (final field in fields(animal))
        if (options(animal, field).containsKey(raw[field]))
          field: raw[field] as String,
  };

  static Map<String, String> fromProduct(
    String? animal,
    Map<String, dynamic> p,
  ) {
    final values = <String, dynamic>{};
    void copy(String key, String column) {
      final value = p[column]?.toString();
      if (value != null && options(animal, key).containsKey(value)) {
        values[key] = value;
      }
    }

    copy('bone', animal == 'CHICKEN' ? 'chicken_bone' : 'bone_state');
    copy('skin', 'chicken_skin');
    copy('preparation', 'chicken_preparation');
    copy(
      'production',
      animal == 'CHICKEN' ? 'chicken_production_type' : 'production_claim',
    );
    copy('rib_count', 'rib_count');
    // Explicit structured values take precedence over legacy columns.
    values.addAll(normalise(animal, p['supplier_attributes']));
    return normalise(animal, values);
  }

  static String summary(Map<String, dynamic> p) {
    final raw = p['supplier_attributes'];
    if (raw is! Map) {
      return '';
    }
    return [
      for (final field in labels.keys)
        if (choices[field]!.containsKey(raw[field]))
          choices[field]![raw[field]]!,
    ].join(' · ');
  }

  static bool matches(Map<String, dynamic> p, Map<String, String> filters) {
    final raw = p['supplier_attributes'];
    return filters.isEmpty ||
        raw is Map && filters.entries.every((e) => raw[e.key] == e.value);
  }
}
