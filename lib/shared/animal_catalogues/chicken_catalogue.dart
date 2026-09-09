import 'animal_catalogue.dart';

class ChickenCatalogue extends AnimalCatalogue {
  const ChickenCatalogue();

  @override
  String get animalCode => 'CHICKEN';

  @override
  String get animalName => 'Chicken';

  @override
  String get svgAssetPath => 'assets/images/CutLink-Chicken-Cuts.svg';

  @override
  bool get usesGradeStage => false;

  @override
  String? get gradeStageLabel => null;

  @override
  String get attributeStageLabel => 'Chicken Type & Attributes';

  @override
  String? get defaultRegionKey => 'whole-chicken';

  static const Map<String, String> _regionLabels = {
    'whole-chicken': 'Whole Chicken',
    'breast': 'Breast',
    'tenderloin': 'Tenderloin',
    'thigh': 'Thigh',
    'maryland': 'Maryland',
    'drumstick': 'Drumstick',
    'wing': 'Wings',
    'chicken-chop-cutlet': 'Chicken Chop / Cutlet',
    'mince-manufacturing': 'Mince / Manufacturing',
    'back-frame': 'Bones / Frames / Skin',
    'neck': 'Neck',
    'tail': 'Tail',
    'misc-offal-other': 'Offal / Other',
  };

  static const Map<String, List<String>> _regionAliases = {
    'whole-chicken': ['WHOLE', 'WHOLE_CHICKEN', 'WHOLE_BIRD', 'Whole Chicken'],
    'breast': ['BREAST', 'BREASTS', 'Chicken Breast'],
    'tenderloin': [
      'TENDERLOIN',
      'TENDERLOINS',
      'TENDERS',
      'Chicken Tenderloin',
    ],
    'thigh': ['THIGH', 'THIGHS', 'Chicken Thigh'],
    'maryland': ['MARYLAND', 'MARYLANDS', 'LEG_QUARTER', 'Chicken Maryland'],
    'drumstick': ['DRUMSTICK', 'DRUMSTICKS', 'Chicken Drumsticks'],
    'wing': ['WING', 'WINGS', 'Chicken Wings'],
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
    'neck': ['NECK', 'NECKS', 'Chicken Necks'],
    'tail': ['TAIL', 'TAILS', 'Chicken Tail'],
    'misc-offal-other': [
      'MISC',
      'OFFAL',
      'OFFAL_OTHER',
      'MISC_OFFAL_OTHER',
      'Offal / Other',
    ],
  };

  @override
  Set<String> get regionKeys => _regionLabels.keys.toSet();

  @override
  String regionLabel(String regionKey) => _regionLabels[regionKey] ?? regionKey;

  @override
  String? sectionCodeForRegion(String regionKey) {
    final aliases = _regionAliases[regionKey];
    if (aliases == null || aliases.isEmpty) return null;
    return aliases.first;
  }

  @override
  bool productMatchesRegion(Map<String, dynamic> product, String regionKey) {
    final section = _nestedMap(product['meat_sections']);
    final specification = _nestedMap(product['meat_specifications']);

    final values = <String>[
      if (section?['code'] != null) section!['code'].toString(),
      if (section?['name'] != null) section!['name'].toString(),
      if (specification?['name'] != null) specification!['name'].toString(),
      if (product['product_name'] != null) product['product_name'].toString(),
    ];

    final aliases = _regionAliases[regionKey] ?? const <String>[];
    if (aliases.any(
      (alias) => values.any((value) => _normalise(value) == _normalise(alias)),
    )) {
      return true;
    }

    final text = values.join(' ').toLowerCase();

    return switch (regionKey) {
      'whole-chicken' => RegExp(
        r'whole[ -](chicken|bird)|spatchcock|butterflied',
      ).hasMatch(text),
      'breast' => RegExp(r'\bbreast').hasMatch(text),
      'tenderloin' => RegExp(r'tenderloin|\btenders?\b').hasMatch(text),
      'thigh' => RegExp(r'\bthigh').hasMatch(text),
      'maryland' => RegExp(r'\bmaryland|leg[ -]quarter').hasMatch(text),
      'drumstick' => RegExp(r'drumstick').hasMatch(text),
      'wing' => RegExp(r'wing|drumette').hasMatch(text),
      'chicken-chop-cutlet' => RegExp(r'\bchop|\bcutlet').hasMatch(text),
      'mince-manufacturing' => RegExp(r'\bmince|manufacturing').hasMatch(text),
      'back-frame' => RegExp(
        r'\bframe|\bbones\b|\bskin\b|\bbacks?\b',
      ).hasMatch(text),
      'neck' => RegExp(r'\bneck').hasMatch(text),
      'tail' => RegExp(r'\btail').hasMatch(text),
      'misc-offal-other' => RegExp(
        r'\boffal|\bliver|\bheart|\bgizzard|\bgiblet|\bfeet',
      ).hasMatch(text),
      _ => false,
    };
  }

  @override
  List<String> get attributeKeys => const [
    'production_claim',
    'bone_state',
    'temperature_state',
    'packaging_type',
    'pieces_per_carton',
    'piece_weight_min',
    'piece_weight_max',
    'piece_weight_unit',
    'carton_weight',
    'carton_weight_unit',
    'halal_status',
    'brand',
  ];

  static String _normalise(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '')
      .replaceFirst(RegExp(r'^CHICKEN'), '');

  static Map<String, dynamic>? _nestedMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }
}
