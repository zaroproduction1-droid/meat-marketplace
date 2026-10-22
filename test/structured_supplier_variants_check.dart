import 'dart:io';

import 'package:cutlink/shared/animal_catalogues/supplier_variant_options.dart';
import 'package:cutlink/shared/animal_catalogues/animal_catalogue_registry.dart';

void main() {
  var checks = 0;
  void check(bool condition, String message) {
    if (!condition) {
      throw StateError(message);
    }
    checks++;
  }

  check(
    SupplierVariantOptions.fields('BEEF').isEmpty,
    'Beef received non-Beef attributes',
  );
  check(
    AnimalCatalogueRegistry.forCode('BEEF')!.usesGradeStage,
    'Beef grade flow changed',
  );
  for (final animal in SupplierVariantOptions.animals) {
    check(
      !AnimalCatalogueRegistry.forCode(animal)!.usesGradeStage,
      'Beef grade forced on $animal',
    );
    check(
      SupplierVariantOptions.options(animal, 'bone')['boneless'] == 'Boneless',
      'Missing bone option for $animal',
    );
    check(
      SupplierVariantOptions.normalise(animal, {
        'bone': 'bone out',
        'unknown': 'x',
      }).isEmpty,
      'Unrecognised wording accepted',
    );
    final p = <String, dynamic>{
      'supplier_attributes': {'bone': 'boneless', 'preparation': 'sliced'},
    };
    check(
      SupplierVariantOptions.matches(p, {
        'bone': 'boneless',
        'preparation': 'sliced',
      }),
      'Exact combined filter failed',
    );
    check(
      !SupplierVariantOptions.matches(p, {'bone': 'bone_in'}),
      'Bone-in matched boneless',
    );
    check(
      !SupplierVariantOptions.matches(p, {'preparation': 'diced'}),
      'Diced matched sliced',
    );
    check(
      SupplierVariantOptions.matches(p, {}),
      'Clearing filters excluded product',
    );
  }
  check(
    SupplierVariantOptions.options('CHICKEN', 'cap').isEmpty,
    'Chicken got a rack cap option',
  );
  check(
    SupplierVariantOptions.options('LAMB', 'skin').isEmpty,
    'Lamb got a chicken skin option',
  );
  check(
    !SupplierVariantOptions.options(
      'CHICKEN',
      'production',
    ).containsKey('grass_fed'),
    'Chicken received red-meat feed option',
  );
  check(
    !SupplierVariantOptions.options(
      'VEAL',
      'production',
    ).containsKey('free_range'),
    'Veal received poultry production option',
  );
  final legacy = SupplierVariantOptions.fromProduct('CHICKEN', {
    'chicken_bone': 'boneless',
    'chicken_skin': 'skin_off',
    'supplier_specification': 'cap off maybe',
  });
  check(
    legacy['bone'] == 'boneless' && legacy['skin'] == 'skin_off',
    'Existing explicit values lost',
  );
  check(!legacy.containsKey('cap'), 'A claim was inferred from prose');
  check(
    SupplierVariantOptions.normalise('LAMB', {'rib_count': '8'})['rib_count'] ==
        '8',
    'Rib count was not preserved',
  );
  check(
    SupplierVariantOptions.normalise('LAMB', {'rib_count': '21'}).isEmpty,
    'Invalid rib count accepted',
  );
  check(
    SupplierVariantOptions.summary({
          'supplier_attributes': {
            'cap': 'cap_off',
            'rack_style': 'frenched',
            'rib_count': '8',
          },
        }) ==
        'Cap off · Frenched · 8 ribs',
    'Product summary lost combinations',
  );
  stdout.writeln(
    'PASS: $checks structured supplier and buyer matching checks.',
  );
}
