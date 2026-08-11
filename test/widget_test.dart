import 'package:flutter_test/flutter_test.dart';
import 'package:meat_marketplace/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MeatMarketplaceApp());

    expect(find.text('NSW Meat Marketplace'), findsWidgets);
  });
}
