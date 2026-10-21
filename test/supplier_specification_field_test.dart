import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutlink/shared/widgets/supplier_specification_field.dart';

void main() {
  test(
    'All five requested animals use general cuts; Beef keeps its current flow',
    () {
      for (final code in ['CHICKEN', 'LAMB', 'MUTTON', 'GOAT', 'VEAL']) {
        expect(SupplierSpecificationField.usesGeneralSubcuts(code), isTrue);
      }
      expect(SupplierSpecificationField.usesGeneralSubcuts('BEEF'), isFalse);
      expect(SupplierSpecificationField.usesGeneralSubcuts(null), isFalse);
    },
  );

  testWidgets(
    'Supplier can type their own preparation without another sub-cut selector',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupplierSpecificationField(
              controller: controller,
              animalCode: 'CHICKEN',
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField),
        'Skinless, tender off, sliced 10 mm',
      );
      expect(controller.text, 'Skinless, tender off, sliced 10 mm');
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    },
  );

  testWidgets('Existing supplier notes stay visible and editable', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Cap off, 8 ribs, frenched');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupplierSpecificationField(
            controller: controller,
            animalCode: 'LAMB',
          ),
        ),
      ),
    );
    expect(find.text('Cap off, 8 ribs, frenched'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Cap on, 6 ribs');
    expect(controller.text, 'Cap on, 6 ribs');
  });

  test('Chicken attribute fallback accepts only supported values', () {
    expect(
      ChickenProductAttributes.value('chicken_skin', 'skin_off'),
      'skin_off',
    );
    expect(
      ChickenProductAttributes.value('chicken_skin', 'unsupported'),
      'not_applicable',
    );
    expect(
      ChickenProductAttributes.value('chicken_preparation', 'diced'),
      'diced',
    );
  });
}
