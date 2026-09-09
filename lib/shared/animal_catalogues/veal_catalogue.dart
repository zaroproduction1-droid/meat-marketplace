import 'animal_catalogue.dart';

class VealCatalogue extends AnimalCatalogue {
  const VealCatalogue();

  @override
  String get animalCode => 'VEAL';

  @override
  String get animalName => 'Veal';

  @override
  String get svgAssetPath => 'assets/images/CutLink-Veal-Cuts.svg';

  @override
  bool get usesGradeStage => false;

  @override
  String? get gradeStageLabel => null;

  @override
  String get attributeStageLabel => 'Veal Attributes';

  @override
  String? get defaultRegionKey => 'Whole Veal';

  static const Map<String, String> _regionLabels = {
    'Whole Veal': 'Whole Veal / Carcase',
    'Forequarter': 'Forequarter',
    'Shoulder / Blade': 'Shoulder / Blade',
    'Neck': 'Neck',
    'Brisket / Breast': 'Brisket / Breast',
    'Rack / Rib': 'Rack / Rib',
    'Loin': 'Loin',
    'Tenderloin': 'Tenderloin',
    'Leg / Round': 'Leg / Round',
    'Rump': 'Rump',
    'Shin / Shank': 'Shin / Shank',
    'Flank / Flap': 'Flank / Flap',
    'Trim / Manufacturing': 'Trim / Manufacturing',
    'Bones / Offal': 'Bones / Offal',
  };

  static const Map<String, String> _regionToSectionCode = {
    'Whole Veal': 'WHOLE_CARCASE',
    'Forequarter': 'FOREQUARTER',
    'Shoulder / Blade': 'SHOULDER_BLADE',
    'Neck': 'NECK',
    'Brisket / Breast': 'BRISKET_BREAST',
    'Rack / Rib': 'RACK_RIB',
    'Loin': 'LOIN',
    'Tenderloin': 'TENDERLOIN',
    'Leg / Round': 'LEG_ROUND',
    'Rump': 'RUMP',
    'Shin / Shank': 'SHIN_SHANK',
    'Flank / Flap': 'FLANK_FLAP',
    'Trim / Manufacturing': 'TRIM_MANUFACTURING',
    'Bones / Offal': 'BONES_OFFAL',
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
