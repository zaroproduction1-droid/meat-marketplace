abstract class AnimalCatalogue {
  const AnimalCatalogue();

  String get animalCode;
  String get animalName;

  /// Optional diagram asset used by the shared animal browser.
  String? get svgAssetPath;

  /// Default selected diagram region when the animal is chosen.
  String? get defaultRegionKey => null;

  /// Whether the buying flow uses a grade/category stage.
  bool get usesGradeStage;

  /// Human-readable label for the grade/category stage when used.
  String? get gradeStageLabel;

  /// Human-readable label for the animal-specific attribute stage.
  String? get attributeStageLabel;

  /// Region keys exposed by the diagram/navigation layer.
  Set<String> get regionKeys;

  /// Human-readable region label.
  String regionLabel(String regionKey);

  /// Map a diagram region to a canonical section code where one exists.
  String? sectionCodeForRegion(String regionKey);

  /// Whether the product belongs to the selected diagram region.
  ///
  /// Product shape follows the existing CutLink product query structure:
  /// meat_animals, meat_sections, meat_specifications and animal-specific
  /// product attributes may be present.
  bool productMatchesRegion(Map<String, dynamic> product, String regionKey);

  /// Animal-specific attribute keys shown in catalogue/buying flows.
  ///
  /// These are intentionally independent from the shared product shell so
  /// Beef, Chicken and Goat can expose different buying structures.
  List<String> get attributeKeys;
}
