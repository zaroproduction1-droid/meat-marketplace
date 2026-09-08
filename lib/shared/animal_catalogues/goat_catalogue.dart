import 'animal_catalogue.dart';

class GoatCatalogue extends AnimalCatalogue {
  const GoatCatalogue();

  @override
  String get animalCode => 'GOAT';

  @override
  String get animalName => 'Goat';

  @override
  String get svgAssetPath => 'assets/images/CutLink-Goat-Cuts-v2.svg';

  @override
  bool get usesGradeStage => false;

  @override
  String? get gradeStageLabel => null;

  @override
  String get attributeStageLabel => 'Goat Attributes';

  @override
  String? get defaultRegionKey => 'Whole Goat';

  static const Map<String, String> _regionLabels = {
    'Whole Goat': 'Whole Goat',
    'Forequarter': 'Forequarter',
    'Hindquarter': 'Hindquarter',
    'Leg': 'Leg',
    'Shoulder': 'Shoulder',
    'Loin': 'Loin',
    'Rack / Rib': 'Rack / Rib',
    'Breast / Flap': 'Breast / Flap',
    'Neck': 'Neck',
    'Shank': 'Shank',
    'Trim / Manufacturing': 'Trim / Manufacturing',
    'Offal / Other': 'Offal / Other',
  };

  static const Map<String, String> _regionToSectionCode = {
    'Whole Goat': 'WHOLE',
    'Forequarter': 'FOREQUARTER',
    'Hindquarter': 'HINDQUARTER',
    'Leg': 'LEG',
    'Shoulder': 'SHOULDER',
    'Loin': 'LOIN',
    'Rack / Rib': 'RACK_RIB',
    'Breast / Flap': 'BREAST_FLAP',
    'Neck': 'NECK',
    'Shank': 'SHANK',
    'Trim / Manufacturing': 'TRIM',
    'Offal / Other': 'OFFAL',
  };

  @override
  Set<String> get regionKeys => _regionLabels.keys.toSet();

  @override
  String regionLabel(String regionKey) => _regionLabels[regionKey] ?? regionKey;

  @override
  String? sectionCodeForRegion(String regionKey) =>
      _regionToSectionCode[regionKey];

  @override
  bool productMatchesRegion(Map<String, dynamic> product, String regionKey) {
    final expectedCode = sectionCodeForRegion(regionKey);
    if (expectedCode == null) return false;

    final section = _nestedMap(product['meat_sections']);
    final sectionCode = section?['code']?.toString().trim().toUpperCase();

    return sectionCode == expectedCode;
  }

  @override
  List<String> get attributeKeys => const [
    'bone_state',
    'temperature_state',
    'halal_status',
    'piece_weight_min',
    'piece_weight_max',
    'piece_weight_unit',
    'carton_weight',
    'carton_weight_unit',
    'pieces_per_carton',
    'packaging_type',
    'brand',
    'supplier_specification',
  ];

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
