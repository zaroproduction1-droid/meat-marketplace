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
    'cheek': 'Cheek',
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
    'ox-tail': 'Ox Tail',
    'misc-offal-other': 'Miscellaneous / Offal',
  };

  static const Map<String, String> _regionToSectionCode = {
    'cheek': 'MISC_OFFAL',
    'round': 'ROUND',
    'silverside-outside': 'SILVERSIDE_OUTSIDE',
    'rump': 'RUMP',
    'loin': 'LOIN',
    'rib-eye': 'RIB_EYE',
    'ribs': 'RIBS',
    'chuck': 'CHUCK',
    'neck': 'NECK',
    'blade': 'BLADE',
    'shoulder': 'SHOULDER',
    'brisket': 'BRISKET',
    'flank': 'FLANK',
    'plate': 'PLATE',
    'skirt': 'SKIRT',
    'shin-shank': 'SHIN_SHANK',
    'ox-tail': 'MISC_OFFAL',
    'misc-offal-other': 'MISC_OFFAL',
  };

  @override
  Set<String> get regionKeys => _regionLabels.keys.toSet();

  @override
  String regionLabel(String regionKey) => _regionLabels[regionKey] ?? regionKey;

  @override
  String? sectionCodeForRegion(String regionKey) =>
      _regionToSectionCode[regionKey];

  @override
  bool productMatchesRegion(
    Map<String, dynamic> product,
    String regionKey,
  ) {
    final expectedCode = sectionCodeForRegion(regionKey);
    if (expectedCode == null) return false;

    final section = _nestedMap(product['meat_sections']);
    final sectionCode = section?['code']?.toString().trim().toUpperCase();

    if (regionKey == 'cheek') {
      final spec = _nestedMap(product['meat_specifications']);
      final specText = [
        spec?['name'],
        product['product_name'],
      ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
      return sectionCode == 'MISC_OFFAL' && RegExp(r'\\bcheek').hasMatch(specText);
    }

    if (regionKey == 'ox-tail') {
      final spec = _nestedMap(product['meat_specifications']);
      final specText = [
        spec?['name'],
        product['product_name'],
      ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');

      return sectionCode == 'MISC_OFFAL' &&
          RegExp(r'\box[\s-]?tail\b|\boxtail\b|\btail\b').hasMatch(specText);
    }

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
