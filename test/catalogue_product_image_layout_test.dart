import 'package:cutlink/shared/widgets/catalogue_product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      '54px Buy again image fits its border in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: CatalogueProductImage(
                    product: {},
                    thumbnail: true,
                    imageWidth: 54,
                    imageHeight: 54,
                    allowGenericPreview: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(CatalogueProductImage)),
          const Size(54, 54),
        );
        expect(find.byIcon(Icons.image_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
