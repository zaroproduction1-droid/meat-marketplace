import 'animal_catalogue.dart';
import 'beef_catalogue.dart';
import 'chicken_catalogue.dart';
import 'goat_catalogue.dart';
import 'lamb_catalogue.dart';
import 'mutton_catalogue.dart';
import 'veal_catalogue.dart';

abstract final class AnimalCatalogueRegistry {
  static const AnimalCatalogue beef = BeefCatalogue();
  static const AnimalCatalogue chicken = ChickenCatalogue();
  static const AnimalCatalogue goat = GoatCatalogue();
  static const AnimalCatalogue lamb = LambCatalogue();
  static const AnimalCatalogue mutton = MuttonCatalogue();
  static const AnimalCatalogue veal = VealCatalogue();

  static const Map<String, AnimalCatalogue> _catalogues = {
    'BEEF': beef,
    'CHICKEN': chicken,
    'GOAT': goat,
    'LAMB': lamb,
    'MUTTON': mutton,
    'VEAL': veal,
  };

  static AnimalCatalogue? forCode(String? animalCode) {
    final code = animalCode?.trim().toUpperCase();
    if (code == null || code.isEmpty) return null;
    return _catalogues[code];
  }

  static bool supports(String? animalCode) => forCode(animalCode) != null;

  static Iterable<AnimalCatalogue> get all => _catalogues.values;
}
