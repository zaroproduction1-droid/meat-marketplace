import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutlink/features/authentication/presentation/registration_type_page.dart';
import 'package:cutlink/features/landing/presentation/cutlink_landing_content.dart';
import 'package:cutlink/features/landing/presentation/cutlink_explainer_video.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('Video-first landing and registration at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      BusinessType? role;
      var signedIn = false;
      await tester.pumpWidget(
        MaterialApp(
          home: CutLinkLandingContent(
            onSignIn: () => signedIn = true,
            onRegister: (value) => role = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CutLinkExplainerVideo), findsOneWidget);
      expect(find.textContaining('Animal catalogue'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Sign in'));
      expect(signedIn, isTrue);
      final supplier = find.text('Join as a supplier').first;
      await tester.ensureVisible(supplier);
      await tester.pumpAndSettle();
      await tester.tap(supplier);
      expect(role, BusinessType.supplier);
      final butcher = find.text('Join as a butcher').first;
      await tester.ensureVisible(butcher);
      await tester.pumpAndSettle();
      await tester.tap(butcher);
      expect(role, BusinessType.butcher);
      await tester.ensureVisible(find.text('For suppliers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('For suppliers'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/cutlink_supplier_preview.webp',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('For butchers'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/cutlink_butcher_preview.webp',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
