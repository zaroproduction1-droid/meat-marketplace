/// Diagram regions navigate the saved catalogue; specifications remain attached
/// to their existing section so every saved sub-cut is included in filtering.
class ChickenCutCatalogue {
  const ChickenCutCatalogue({
    this.sections = const [],
    this.specifications = const [],
  });

  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> specifications;
  static const sectionAliases = <String, List<String>>{
    'whole-chicken': ['WHOLE', 'WHOLE_CHICKEN', 'WHOLE_BIRD', 'Whole Chicken'],
    'neck': ['NECK', 'NECKS', 'Chicken Necks'],
    'back-frame': [
      'BONES_FRAMES_SKIN',
      'BACK_FRAME',
      'FRAME',
      'FRAMES',
      'BACK',
      'BONES',
      'SKIN',
      'BONES_FRAMES',
      'Bones / Frames / Skin',
      'Back / Frame',
    ],
    'wing': ['WING', 'WINGS', 'Chicken Wings'],
    'breast': ['BREAST', 'BREASTS', 'Chicken Breast'],
    'tenderloin': [
      'TENDERLOIN',
      'TENDERLOINS',
      'TENDERS',
      'Chicken Tenderloin',
    ],
    'tail': ['TAIL', 'TAILS', 'Chicken Tail'],
    'maryland': ['MARYLAND', 'MARYLANDS', 'LEG_QUARTER', 'Chicken Maryland'],
    'thigh': ['THIGH', 'THIGHS', 'Chicken Thigh'],
    'drumstick': ['DRUMSTICK', 'DRUMSTICKS', 'Chicken Drumsticks'],
    'chicken-chop-cutlet': [
      'CHOP_CUTLET',
      'CHICKEN_CHOP_CUTLET',
      'CHOP',
      'CUTLET',
      'Chicken Chop / Cutlet',
    ],
    'mince-manufacturing': [
      'MINCE_MANUFACTURING',
      'MINCE',
      'MANUFACTURING',
      'Mince / Manufacturing',
    ],
    'misc-offal-other': [
      'MISC',
      'OFFAL',
      'OFFAL_OTHER',
      'MISC_OFFAL_OTHER',
      'Offal / Other',
    ],
  };

  static const regionNames = <String, String>{
    'whole-chicken': 'Whole Chicken',
    'neck': 'Neck',
    'back-frame': 'Bones / Frames / Skin',
    'wing': 'Wings',
    'breast': 'Breast',
    'tenderloin': 'Tenderloin',
    'tail': 'Tail',
    'maryland': 'Maryland',
    'thigh': 'Thigh',
    'drumstick': 'Drumstick',
    'chicken-chop-cutlet': 'Chicken Chop / Cutlet',
    'mince-manufacturing': 'Mince / Manufacturing',
    'misc-offal-other': 'Offal / Other',
  };

  static String _normalise(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '')
      .replaceFirst(RegExp(r'^CHICKEN'), '');

  static String? regionForSection(Map<String, dynamic> section) {
    final hotspot = section['hotspot_key']?.toString();
    if (regionNames.containsKey(hotspot)) return hotspot;
    for (final entry in sectionAliases.entries) {
      for (final alias in entry.value) {
        if ([section['code'], section['name'], hotspot].any(
          (value) =>
              value != null &&
              _normalise(value.toString()) == _normalise(alias),
        )) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Parent diagram regions also expose their explicitly labelled child cuts.
  static bool _includes(String selected, String? region) =>
      selected == region ||
      (selected == 'breast' && region == 'tenderloin') ||
      (selected == 'maryland' && (region == 'thigh' || region == 'drumstick'));

  Map<String, dynamic>? sectionById(String? id) {
    for (final section in sections) {
      if (section['id']?.toString() == id) return section;
    }
    return null;
  }

  Map<String, dynamic>? specificationById(String? id) {
    for (final spec in specifications) {
      if (spec['id']?.toString() == id) return spec;
    }
    return null;
  }

  // Some catalogues store these diagram selectors as sub-cuts of a wider
  // section. Names and alternate names identify them without changing IDs.
  static String? _subcutRegion(Map<String, dynamic> spec) {
    final names = [
      spec['name'],
      spec['slug'],
      if (spec['alternate_names'] is List) ...(spec['alternate_names'] as List),
    ];
    final text = names.whereType<String>().join(' ').toLowerCase();
    if (RegExp(r'tenderloin|\btenders?\b').hasMatch(text)) return 'tenderloin';
    if (RegExp(r'\bmince|manufacturing').hasMatch(text)) {
      return 'mince-manufacturing';
    }
    if (RegExp(r'\bchop|\bcutlet').hasMatch(text)) {
      return 'chicken-chop-cutlet';
    }
    if (RegExp(r'\bmaryland|leg[ -]quarter').hasMatch(text)) return 'maryland';
    if (RegExp(r'\bbreast').hasMatch(text)) return 'breast';
    if (RegExp(r'drumstick').hasMatch(text)) return 'drumstick';
    if (RegExp(r'\bthigh').hasMatch(text)) return 'thigh';
    if (RegExp(r'wing|drumette').hasMatch(text)) return 'wing';
    if (RegExp(r'\bneck').hasMatch(text)) return 'neck';
    if (RegExp(r'\btail').hasMatch(text)) return 'tail';
    if (RegExp(
      r'whole[ -](chicken|bird)|spatchcock|butterflied',
    ).hasMatch(text)) {
      return 'whole-chicken';
    }
    if (RegExp(
      r'\bframe|\bbones\b|^(chicken[ -])?skin\b|\bbacks?\b',
    ).hasMatch(text)) {
      return 'back-frame';
    }
    if (RegExp(
      r'\boffal|\bliver|\bheart|\bgizzard|\bgiblet|\bfeet',
    ).hasMatch(text)) {
      return 'misc-offal-other';
    }
    return null;
  }

  bool specificationInRegion(Map<String, dynamic> spec, String region) {
    final section = sectionById(spec['section_id']?.toString());
    final parentRegion = section == null ? null : regionForSection(section);
    // Include every saved sub-cut under its own section, plus nested selectors.
    return _includes(region, parentRegion) ||
        _includes(region, _subcutRegion(spec));
  }

  List<Map<String, dynamic>> specificationsFor({
    String? region,
    String? sectionId,
  }) {
    final result = specifications
        .where(
          (spec) => region != null
              ? specificationInRegion(spec, region)
              : sectionId == null ||
                    spec['section_id']?.toString() == sectionId,
        )
        .toList();
    result.sort((a, b) {
      final order = ((a['display_order'] as num?)?.toInt() ?? 0).compareTo(
        (b['display_order'] as num?)?.toInt() ?? 0,
      );
      return order != 0
          ? order
          : (a['name']?.toString() ?? '').toLowerCase().compareTo(
              (b['name']?.toString() ?? '').toLowerCase(),
            );
    });
    return result;
  }

  bool productMatches(
    Map<String, dynamic> product, {
    String? region,
    String? sectionId,
  }) {
    final rawSpec = product['meat_specifications'];
    final rawSection = product['meat_sections'];
    final specId =
        product['meat_specification_id']?.toString() ??
        (rawSpec is Map ? rawSpec['id']?.toString() : null);
    final spec = specificationById(specId);
    final productSectionId =
        spec?['section_id']?.toString() ??
        product['meat_section_id']?.toString() ??
        (rawSection is Map ? rawSection['id']?.toString() : null);
    if (region == null) {
      return sectionId == null || productSectionId == sectionId;
    }
    if (spec != null) return specificationInRegion(spec, region);
    final section =
        sectionById(productSectionId) ??
        (rawSection is Map ? Map<String, dynamic>.from(rawSection) : null);
    return section != null && _includes(region, regionForSection(section));
  }

  static Map<String, dynamic>? sectionForRegion(
    String region,
    Iterable<Map<String, dynamic>> sections,
  ) {
    for (final section in sections) {
      if (regionForSection(section) == region) return section;
    }
    return null;
  }
}
