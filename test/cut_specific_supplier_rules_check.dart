import 'dart:convert';
import 'dart:io';

import 'package:cutlink/shared/animal_catalogues/supplier_variant_options.dart';

void main() {
  final rows =
      (jsonDecode(
                File.fromUri(
                  Platform.script.resolve(
                    '../database/CutSpecificationRules.json',
                  ),
                ).readAsStringSync(),
              )
              as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  var checks = 0;
  void check(bool ok, String message) {
    if (!ok) {
      throw StateError(message);
    }
    checks++;
  }

  Map<String, dynamic> rule(String animal, String section, String cut) =>
      Map<String, dynamic>.from(
        rows.singleWhere(
              (r) =>
                  r['animal'] == animal &&
                  r['section'] == section &&
                  r['cut'] == cut,
            )['rules']
            as Map,
      );
  check(rows.length == 182, 'Not all current cuts covered');
  check(
    rows.map((r) => '${r['animal']}/${r['section']}').toSet().length == 63,
    'Main section coverage changed',
  );
  for (final row in rows) {
    final rules = Map<String, dynamic>.from(row['rules'] as Map);
    final animal = row['animal'] as String;
    check(animal != 'BEEF', 'Beef rules changed');
    for (final key in SupplierVariantOptions.fieldsForCut(
      rules,
      ignoreConditions: true,
    )) {
      final options = SupplierVariantOptions.cutOptions(rules, key);
      check(options.isNotEmpty, 'Empty options for $row');
      for (final value in options.keys) {
        final input = <String, String>{key: value};
        final when = rules['_when'];
        final conditions = when is Map ? when[key] : null;
        if (conditions is Map) {
          for (final condition in conditions.entries) {
            input[condition.key as String] =
                (condition.value as List).first as String;
          }
        }
        final clean = SupplierVariantOptions.normaliseForCut(
          animal,
          input,
          rules,
        );
        check(
          clean[key] == value,
          'Allowed option lost for ${row['cut']}: $key=$value',
        );
      }
    }
    check(
      SupplierVariantOptions.normaliseForCut(animal, {
        'invented': 'value',
        'bone': 'invented',
      }, rules).isEmpty,
      'Invalid value accepted',
    );
  }
  final leg = rule('LAMB', 'LEG', 'Leg');
  final rack = rule('LAMB', 'RACK_RIB', 'Rack');
  final shoulder = rule('LAMB', 'SHOULDER', 'Shoulder');
  final shoulderRack = rule('LAMB', 'SHOULDER', 'Shoulder Rack');
  for (final r in [leg, shoulder, rule('LAMB', 'OFFAL_OTHER', 'Liver / Fry')]) {
    check(
      !SupplierVariantOptions.fieldsForCut(
        r,
        ignoreConditions: true,
      ).contains('rack_style'),
      'Rack style leaked into another cut',
    );
    check(
      !SupplierVariantOptions.fieldsForCut(
        r,
        ignoreConditions: true,
      ).contains('rib_count'),
      'Rib count leaked into non-rib cut',
    );
  }
  check(
    SupplierVariantOptions.fieldsForCut(shoulderRack).contains('rack_style'),
    'Shoulder Rack exception lost',
  );
  check(
    SupplierVariantOptions.cutOptions(
          shoulderRack,
          'rib_count',
        ).keys.join(',') ==
        '2,3,4,5',
    'Shoulder rib range incorrect',
  );
  check(
    SupplierVariantOptions.cutOptions(rack, 'rib_count').containsKey('8'),
    'Lamb rack lost eight-rib choice',
  );
  check(
    !SupplierVariantOptions.fieldsForCut(
      leg,
      values: const {'bone': 'boneless'},
    ).contains('aitch_bone'),
    'Hidden aitch option on boneless leg',
  );
  check(
    SupplierVariantOptions.fieldsForCut(
      leg,
      values: const {'bone': 'boneless'},
    ).contains('boning_method'),
    'Boneless leg lost boning method',
  );
  final moved = SupplierVariantOptions.normaliseForCut('LAMB', {
    'bone': 'bone_in',
    'rack_style': 'frenched',
    'rib_count': '8',
    'cap': 'cap_off',
  }, leg);
  check(
    moved.length == 1 && moved['bone'] == 'bone_in',
    'Changing Rack to Leg retained hidden choices',
  );
  final filet = rule('VEAL', 'TENDERLOIN', 'Tenderloin / Fillet');
  check(
    SupplierVariantOptions.fieldsForCut(filet).contains('side_strap'),
    'Veal fillet lost strap option',
  );
  check(
    !SupplierVariantOptions.fieldsForCut(
      rule('VEAL', 'RACK_RIB', 'Cube Roll / Rib Eye'),
    ).contains('rack_style'),
    'Boneless cube roll got rack style',
  );
  check(
    SupplierVariantOptions.fieldsForCut(
      rule('CHICKEN', 'BREAST', 'Breast Fillet'),
    ).contains('tender'),
    'Chicken breast lost tender option',
  );
  check(
    !SupplierVariantOptions.fieldsForCut(
      rule('CHICKEN', 'THIGH', 'Thigh'),
    ).contains('tender'),
    'Chicken thigh got breast tender option',
  );
  check(
    SupplierVariantOptions.fieldsForCut(
      rule('LAMB', 'TRIM_MANUFACTURING', 'Mince'),
    ).contains('mince_grind'),
    'Mince lost grind',
  );
  check(
    SupplierVariantOptions.fieldsForCut(
      rule('LAMB', 'OFFAL_OTHER', 'Bones'),
    ).contains('bone_cut'),
    'Bones lost sawing/split options',
  );
  check(
    SupplierVariantOptions.fieldsForCut(const {}).isEmpty,
    'No cut still shows animal-wide options',
  );
  final union = SupplierVariantOptions.unionRules([
    leg,
    rule('LAMB', 'LEG', 'Topside'),
  ]);
  check(
    !SupplierVariantOptions.fieldsForCut(union).contains('rack_style'),
    'Leg buyer filters leaked rack style',
  );
  stdout.writeln(
    'PASS: $checks cut-specific dropdown, option and transition checks across all 182 cuts.',
  );
}
