import 'dart:io';

import 'package:cutlink/shared/animal_catalogues/animal_catalogue_registry.dart';
import 'package:cutlink/shared/animal_catalogues/lamb_product_details.dart';

void main() {
  var checks = 0;
  void check(bool condition, String message) {
    if (!condition) {
      throw StateError(message);
    }
    checks++;
  }

  check(
    AnimalCatalogueRegistry.forCode('BEEF')!.usesGradeStage,
    'Beef grade stage changed',
  );
  for (final code in ['CHICKEN', 'LAMB', 'MUTTON', 'GOAT', 'VEAL']) {
    final catalogue = AnimalCatalogueRegistry.forCode(code)!;
    check(!catalogue.usesGradeStage, '$code was forced into Beef grades');
    check(
      catalogue.regionKeys.isNotEmpty,
      '$code lost its main cut navigation',
    );
  }
  final lamb = <String, dynamic>{
    'meat_animals': {'code': 'LAMB'},
    'meat_sections': {'code': 'RACK_RIB'},
    'supplier_specification': 'Cap off, frenched, 8 ribs',
    'bone_state': 'bone_in',
    'temperature_state': 'chilled',
  };
  check(
    LambProductDetails.secondaryLine(
      lamb,
    ).contains('Cap off, frenched, 8 ribs'),
    'Supplier detail missing from the buyer summary',
  );
  check(
    LambProductDetails.searchableText(lamb).contains('8 ribs'),
    'Supplier detail missing from search',
  );
  for (final code in ['LAMB', 'MUTTON', 'GOAT', 'VEAL']) {
    final catalogue = AnimalCatalogueRegistry.forCode(code)!;
    final regions = catalogue.regionKeys.where(
      (r) => catalogue.sectionCodeForRegion(r) == 'RACK_RIB',
    );
    check(regions.isNotEmpty, '$code rack cannot be navigated');
    check(
      catalogue.productMatchesRegion({
        'meat_sections': {'code': 'RACK_RIB', 'name': 'Rack / Rib'},
        'meat_specifications': {'name': 'Rack'},
      }, regions.first),
      '$code rack no longer matches its main cut',
    );
  }
  stdout.writeln(
    'PASS: $checks catalogue navigation, grade separation and supplier detail checks.',
  );
}
