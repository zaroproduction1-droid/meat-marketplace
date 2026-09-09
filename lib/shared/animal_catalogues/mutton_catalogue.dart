import 'animal_catalogue.dart';

class MuttonCatalogue extends AnimalCatalogue {
  const MuttonCatalogue();

  @override
  String get animalCode => 'MUTTON';

  @override
  String get animalName => 'Mutton';

  @override
  String get svgAssetPath => 'assets/images/CutLink-Mutton-Cuts.svg';

  @override
  bool get usesGradeStage => false;

  @override
  String? get gradeStageLabel => null;

  @override
  String get attributeStageLabel => 'Mutton Attributes';

  @override
  String? get defaultRegionKey => 'Whole Mutton';

  static const Map<String, String> _regionLabels = {
    'Whole Mutton': 'Whole Mutton / Carcase',
    'Forequarter': 'Forequarter',
    'Shoulder': 'Shoulder',
    'Neck': 'Neck',
    'Breast / Flap': 'Breast / Flap',
    'Rack / Rib': 'Rack / Rib',
    'Loin': 'Loin',
    'Tenderloin': 'Tenderloin',
    'Chump / Rump': 'Chump / Rump',
    'Leg': 'Leg',
    'Shank': 'Shank',
    'Trim / Manufacturing': 'Trim / Manufacturing',
    'Offal / Other': 'Offal / Other',
  };

  static const Map<String, String> _regionToSectionCode = {
    'Whole Mutton': 'WHOLE_CARCASE',
    'Forequarter': 'FOREQUARTER',
    'Shoulder': 'SHOULDER',
    'Neck': 'NECK',
    'Breast / Flap': 'BREAST_FLAP',
    'Rack / Rib': 'RACK_RIB',
    'Loin': 'LOIN',
    'Tenderloin': 'TENDERLOIN',
    'Chump / Rump': 'CHUMP_RUMP',
    'Leg': 'LEG',
    'Shank': 'SHANK',
    'Trim / Manufacturing': 'TRIM_MANUFACTURING',
    'Offal / Other': 'OFFAL_OTHER',
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
