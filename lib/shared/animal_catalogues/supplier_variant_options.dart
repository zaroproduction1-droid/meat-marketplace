/// Stable value codes; per-cut applicability is loaded from the catalogue.
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
    'fat_trim': 'Surface fat trim',
    'chump': 'Chump',
    'shank': 'Shank attached',
    'aitch_bone': 'Aitch bone',
    'boning_method': 'Boning method',
    'side_strap': 'Side strap',
    'silverskin': 'Silverskin',
    'flap': 'Flap',
    'chine': 'Chine bone',
    'feather_bones': 'Feather bones',
    'shank_finish': 'Shank finish',
    'rib_exposure': 'Exposed rib length',
    'tail_length': 'Loin tail length',
    'bone_cut': 'Bone preparation',
    'tripe_finish': 'Tripe preparation',
    'kidney_fat': 'Kidney fat',
    'chemical_lean': 'Declared chemical lean',
    'mince_grind': 'Mince grind',
    'portion_count': 'Pieces per bird',
    'wing_tip': 'Wing tip',
    'wing_bone_finish': 'Supreme wing bone',
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
      'chops': 'Chops',
      'cutlets': 'Cutlets',
      'steaks': 'Steaks',
      'halved': 'Halved',
      'quartered': 'Quartered',
      'six_way_cut': 'Six way cut',
      'pieces': 'Pieces',
      'osso_buco': 'Osso buco',
    },
    'cap': {'cap_on': 'Cap on', 'cap_off': 'Cap off'},
    'rack_style': {'standard': 'Standard rack', 'frenched': 'Frenched'},
    'rib_count': {
      '0': '0 ribs',
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
    'chump': {'chump_on': 'Chump on', 'chump_off': 'Chump off'},
    'shank': {'shank_on': 'Shank on', 'shank_off': 'Shank off'},
    'aitch_bone': {'retained': 'Retained', 'removed': 'Removed'},
    'boning_method': {
      'seam_boned': 'Seam boned',
      'tunnel_boned': 'Tunnel boned',
    },
    'side_strap': {'strap_on': 'Strap on', 'strap_off': 'Strap off'},
    'silverskin': {'retained': 'Retained', 'removed': 'Removed'},
    'flap': {'flap_on': 'Flap on', 'flap_off': 'Flap off'},
    'chine': {'retained': 'Retained', 'removed': 'Removed'},
    'feather_bones': {'retained': 'Retained', 'removed': 'Removed'},
    'shank_finish': {
      'standard': 'Standard shank',
      'frenched': 'Frenched shank',
    },
    'rib_exposure': {
      '10_mm': '10 mm',
      '15_mm': '15 mm',
      '20_mm': '20 mm',
      '25_mm': '25 mm',
      '30_mm': '30 mm',
      '35_mm': '35 mm',
      '40_mm': '40 mm',
      '45_mm': '45 mm',
      '50_mm': '50 mm',
      '60_mm': '60 mm',
      '70_mm': '70 mm',
      '75_mm': '75 mm',
      '80_mm': '80 mm',
      '90_mm': '90 mm',
      '100_mm': '100 mm',
    },
    'tail_length': {
      '0_mm': '0 mm',
      '25_mm': '25 mm',
      '50_mm': '50 mm',
      '75_mm': '75 mm',
      '100_mm': '100 mm',
    },
    'bone_cut': {
      'whole': 'Whole',
      'sawn': 'Sawn',
      'cross_cut': 'Cross cut',
      'length_split': 'Split lengthways',
    },
    'tripe_finish': {'scalded': 'Scalded', 'unscalded': 'Unscalded'},
    'kidney_fat': {'retained': 'Retained', 'removed': 'Removed'},
    'chemical_lean': {
      '65_cl': '65 CL',
      '70_cl': '70 CL',
      '75_cl': '75 CL',
      '80_cl': '80 CL',
      '85_cl': '85 CL',
      '90_cl': '90 CL',
      '95_cl': '95 CL',
    },
    'mince_grind': {'fine': 'Fine', 'medium': 'Medium', 'coarse': 'Coarse'},
    'portion_count': {
      '2': '2 pieces',
      '4': '4 pieces',
      '8': '8 pieces',
      '9': '9 pieces',
    },
    'wing_tip': {'tip_on': 'Tip on', 'tip_off': 'Tip off'},
    'wing_bone_finish': {
      'standard': 'Standard',
      'exposed': 'Exposed',
      'cleaned': 'Cleaned',
    },
  };
  static const _animalFields = <String, List<String>>{
    'CHICKEN': [
      'production',
      'bone',
      'skin',
      'preparation',
      'portion_count',
      'tender',
      'wing_bone_finish',
      'wing_tip',
      'mince_grind',
      'bone_cut',
    ],
    'GOAT': [
      'production',
      'preparation',
      'skin',
      'bone',
      'fat_trim',
      'rib_count',
      'silverskin',
      'chump',
      'shank',
      'aitch_bone',
      'boning_method',
      'cap',
      'flap',
      'tail_length',
      'side_strap',
      'rack_style',
      'chine',
      'feather_bones',
      'rib_exposure',
      'shank_finish',
      'chemical_lean',
      'mince_grind',
      'bone_cut',
      'kidney_fat',
    ],
    'LAMB': [
      'production',
      'preparation',
      'bone',
      'fat_trim',
      'rib_count',
      'silverskin',
      'rack_style',
      'rib_exposure',
      'cap',
      'chine',
      'feather_bones',
      'flap',
      'tail_length',
      'side_strap',
      'chump',
      'shank',
      'aitch_bone',
      'boning_method',
      'shank_finish',
      'chemical_lean',
      'mince_grind',
      'bone_cut',
      'kidney_fat',
      'tripe_finish',
    ],
    'MUTTON': [
      'production',
      'preparation',
      'bone',
      'fat_trim',
      'rib_count',
      'rack_style',
      'rib_exposure',
      'silverskin',
      'cap',
      'chine',
      'feather_bones',
      'flap',
      'tail_length',
      'side_strap',
      'chump',
      'shank',
      'aitch_bone',
      'boning_method',
      'shank_finish',
      'chemical_lean',
      'mince_grind',
      'bone_cut',
      'kidney_fat',
      'tripe_finish',
    ],
    'VEAL': [
      'production',
      'preparation',
      'bone',
      'fat_trim',
      'rib_count',
      'silverskin',
      'rack_style',
      'cap',
      'chine',
      'feather_bones',
      'rib_exposure',
      'flap',
      'tail_length',
      'side_strap',
      'chump',
      'shank',
      'aitch_bone',
      'boning_method',
      'shank_finish',
      'chemical_lean',
      'mince_grind',
      'bone_cut',
      'kidney_fat',
    ],
  };
  static List<String> fields(String? animal) =>
      _animalFields[animal] ?? const [];
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
    return all;
  }

  static Map<String, String> normalise(String? animal, dynamic raw) => {
    if (raw is Map)
      for (final field in fields(animal))
        if (options(animal, field).containsKey(raw[field]))
          field: raw[field] as String,
  };

  static Map<String, String> cutOptions(dynamic rules, String field) {
    final raw = rules is Map ? rules[field] : null;
    return {
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.key is String &&
              entry.value is String &&
              choices[field]?.containsKey(entry.key) == true)
            entry.key as String: entry.value as String,
    };
  }

  static bool _visible(
    dynamic rules,
    String field,
    Map<String, String> values,
  ) {
    final when = rules is Map ? rules['_when'] : null;
    final conditions = when is Map ? when[field] : null;
    return conditions is! Map ||
        conditions.entries.every(
          (entry) =>
              entry.value is List &&
              (entry.value as List).contains(values[entry.key]),
        );
  }

  static List<String> fieldsForCut(
    dynamic rules, {
    Map<String, String> values = const {},
    bool ignoreConditions = false,
  }) => [
    if (rules is Map)
      for (final key in labels.keys)
        if (cutOptions(rules, key).isNotEmpty &&
            (ignoreConditions || _visible(rules, key, values)))
          key,
  ];
  static Map<String, String> normaliseForCut(
    String? animal,
    dynamic raw,
    dynamic rules, {
    bool ignoreConditions = false,
  }) {
    final values = normalise(animal, raw)
      ..removeWhere((k, v) => !cutOptions(rules, k).containsKey(v));
    if (!ignoreConditions) {
      // Repeat so a removed parent cannot leave a hidden child selection behind.
      for (var i = 0; i < labels.length; i++) {
        final before = values.length;
        values.removeWhere((key, _) => !_visible(rules, key, values));
        if (values.length == before) {
          break;
        }
      }
    }
    return values;
  }

  static Map<String, dynamic> unionRules(Iterable<dynamic> inputs) {
    final result = <String, dynamic>{};
    for (final rules in inputs) {
      for (final key in fieldsForCut(rules, ignoreConditions: true)) {
        final values =
            result.putIfAbsent(key, () => <String, String>{})
                as Map<String, String>;
        values.addAll(cutOptions(rules, key));
      }
    }
    return result;
  }

  static Map<String, String> fromProduct(
    String? animal,
    Map<String, dynamic> p,
  ) {
    // An explicit structured record, including an empty one, is authoritative.
    if (p['supplier_attributes'] is Map) {
      return normalise(animal, p['supplier_attributes']);
    }
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
