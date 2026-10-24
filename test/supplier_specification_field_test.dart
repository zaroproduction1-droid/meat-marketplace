import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutlink/shared/widgets/supplier_specification_field.dart';
import 'package:cutlink/shared/animal_catalogues/supplier_variant_options.dart';

void main() {
  const rack = <String, dynamic>{
    'bone': {'bone_in': 'Bone in'},
    'rack_style': {'standard': 'Standard rack', 'frenched': 'Frenched'},
    'rib_count': {'8': '8 ribs'},
  };
  const leg = <String, dynamic>{
    'bone': {'bone_in': 'Bone in', 'boneless': 'Boneless'},
    'chump': {'chump_on': 'Chump on', 'chump_off': 'Chump off'},
  };
  testWidgets('Rack options disappear when the supplier changes to Leg', (
    tester,
  ) async {
    var rules = rack;
    var values = <String, String>{
      'bone': 'bone_in',
      'rack_style': 'frenched',
      'rib_count': '8',
    };
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SupplierSpecificationField(
                  animalCode: 'LAMB',
                  cutRules: rules,
                  values: values,
                  onChanged: (key, value) => setState(() {
                    values[key] = value;
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Rack style'), findsOneWidget);
    expect(find.text('Rib count'), findsOneWidget);
    rebuild(() {
      rules = leg;
      values = SupplierVariantOptions.normaliseForCut('LAMB', values, leg);
    });
    await tester.pumpAndSettle();
    expect(find.text('Rack style'), findsNothing);
    expect(find.text('Rib count'), findsNothing);
    expect(find.text('Chump'), findsOneWidget);
    expect(values, {'bone': 'bone_in'});
  });
  testWidgets('No selected subcut shows a selection prompt without dropdowns', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupplierSpecificationField(
            animalCode: 'LAMB',
            cutRules: const {},
            values: const {},
            onChanged: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Select a sub-cut'), findsOneWidget);
    expect(find.text('Rack style'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });
}
