import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutlink/features/landing/presentation/trade_story_animation.dart';

void main() {
  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('Order story stages stay readable at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: TradeStoryAnimation()),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Pause story'));
      await tester.pump();
      for (final entry in [
        ('1. Send order', 'Send order'),
        ('2. Approve & prepare', 'Approve & prepare'),
        ('3. Pick & weigh', 'Pick & weigh'),
        ('4. Create invoice', 'Create invoice'),
        ('5. Dispatch delivery', 'Dispatch delivery'),
        ('6. Complete & review', 'Complete & review'),
      ]) {
        await tester.ensureVisible(find.text(entry.$1));
        await tester.tap(find.text(entry.$1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(entry.$2), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('9.4 kg actual'), findsOneWidget);
      expect(find.text('\$225.60 product value'), findsOneWidget);
    });
  }
  testWidgets('Reduced motion keeps the story manual', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(child: TradeStoryAnimation()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Send order'), findsOneWidget);
    await tester.ensureVisible(find.text('3. Pick & weigh'));
    await tester.tap(find.text('3. Pick & weigh'));
    await tester.pump();
    expect(find.text('Pick & weigh'), findsOneWidget);
    expect(find.text('9.4 kg actual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
