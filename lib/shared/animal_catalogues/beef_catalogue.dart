import 'animal_catalogue.dart';

class BeefCatalogue extends AnimalCatalogue {
  const BeefCatalogue();

  @override
  String get animalCode => 'BEEF';

  @override
  String get animalName => 'Beef';

  @override
  String get svgAssetPath => 'assets/images/CutLink-Beef-Cuts.svg';

  @override
  bool get usesGradeStage => true;

  @override
  String get gradeStageLabel => 'AUS-MEAT Category';

  @override
  String? get attributeStageLabel => null;

  static const Map<String, String> _regionLabels = {
    'round': 'Round',
    'silverside-outside': 'Silverside / Outside',
    'rump': 'Rump',
    'loin': 'Loin',
    'rib-eye': 'Rib Eye',
    'ribs': 'Ribs',
    'chuck': 'Chuck',
    'neck': 'Neck',
    'blade': 'Blade',
    'shoulder': 'Shoulder',
    'brisket': 'Brisket',
    'flank': 'Flank',
    'plate': 'Plate',
    'skirt': 'Skirt',
    'shin-shank': 'Shin / Shank',
    'cheek': 'Cheek',
    'ox-tail': 'Ox Tail',
    'misc-offal-other': 'Miscellaneous / Offal',
  };

  static const Map<String, String> _regionToSectionCode = {
    'round': 'HIND',
    'silverside-outside': 'SILVERSIDE',
    'rump': 'RUMP',
    'loin': 'LOIN',
    'rib-eye': 'RIBEYE',
    'ribs': 'RIB',
    'chuck': 'CHUCK',
    'neck': 'NECK',
    'blade': 'BLADE',
    'shoulder': 'SHOULDER',
    'brisket': 'BRISKET',
    'flank': 'FLANK',
    'plate': 'PLATE',
    'skirt': 'SKIRT',
    'shin-shank': 'SHANK',
    'cheek': 'CHEEK',
    'ox-tail': 'TAIL',
    'misc-offal-other': 'MISC',
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
    'marbling_score',
    'grade',
    'breed_program',
    'feeding_days',
    'production_claim',
    'hgp_free',
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
