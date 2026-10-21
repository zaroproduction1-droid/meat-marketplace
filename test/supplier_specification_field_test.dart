import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutlink/shared/widgets/supplier_specification_field.dart';
import 'package:cutlink/shared/widgets/cutlink_picker.dart';

void main() {
  testWidgets('Supplier specification uses dropdowns instead of free text', (
    tester,
  ) async {
    final values = <String, String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, update) => SupplierSpecificationField(
                animalCode: 'CHICKEN',
                values: values,
                onChanged: (key, value) => update(() {
                  values[key] = value;
                }),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(CutLinkPickerField<String>), findsNWidgets(5));
    await tester.tap(find.text('Bone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boneless'));
    await tester.pumpAndSettle();
    expect(values['bone'], 'boneless');
  });

  testWidgets('Old written details are preserved for reference', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SupplierSpecificationField(
              animalCode: 'LAMB',
              values: const {'cap': 'cap_off', 'rib_count': '8'},
              previousDetails: 'Original saved supplier wording',
              onChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(TextFormField), findsNothing);
    await tester.ensureVisible(find.text('Previous written details'));
    await tester.tap(find.text('Previous written details'));
    await tester.pumpAndSettle();
    expect(find.text('Original saved supplier wording'), findsOneWidget);
  });
}
