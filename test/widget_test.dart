import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutlink/features/landing/presentation/cutlink_landing_content.dart';
import 'package:cutlink/features/authentication/presentation/registration_type_page.dart';

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('Landing page routes both registration roles at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      BusinessType? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: CutLinkLandingContent(
            onSignIn: () {},
            onRegister: (role) => selected = role,
          ),
        ),
      );
      expect(find.text('CutLink'), findsWidgets);
      expect(tester.takeException(), isNull);
      final supplier = find.text('Join as a supplier').first;
      await tester.ensureVisible(supplier);
      await tester.tap(supplier);
      expect(selected, BusinessType.supplier);
      final butcher = find.text('Join as a butcher').first;
      await tester.ensureVisible(butcher);
      await tester.tap(butcher);
      expect(selected, BusinessType.butcher);
      expect(tester.takeException(), isNull);
    });
  }
}
