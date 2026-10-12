import 'dart:async';
import 'package:cutlink/features/support/presentation/missing_item_request_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester, MissingItemSubmit submit) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => MissingItemRequestDialog(
                  businessId: 'test-business',
                  pageName: 'Supplier sales',
                  catalogueContext: const {'Animal': 'BEEF'},
                  submit: submit,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  final name = find.byKey(const ValueKey('missing-item-name'));
  final send = find.byKey(const ValueKey('missing-item-send'));
  testWidgets('Empty requests never submit', (tester) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
      return 'ticket';
    });
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Enter the item you need.'), findsOneWidget);
  });
  testWidgets(
    'Request carries business, page and catalogue context into support',
    (tester) async {
      Map<String, dynamic>? captured;
      await open(tester, (params) async {
        captured = params;
        return 'ticket';
      });
      await tester.enterText(name, 'Missing beef cut');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(captured!['p_business_id'], 'test-business');
      expect(captured!['p_category'], 'products');
      expect(captured!['p_subject'], 'Missing item: Missing beef cut');
      expect(captured!['p_message'], contains('Page: Supplier sales'));
      expect(captured!['p_message'], contains('Animal: BEEF'));
      expect(find.byType(MissingItemRequestDialog), findsNothing);
    },
  );
  testWidgets('Pending request blocks duplicates and failure keeps the draft', (
    tester,
  ) async {
    final pending = Completer<String>();
    var calls = 0;
    await open(tester, (_) {
      calls++;
      return pending.future;
    });
    await tester.enterText(name, 'Missing grade');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pump();
    await tester.tap(send);
    expect(calls, 1);
    expect(tester.widget<ButtonStyleButton>(send).onPressed, isNull);
    pending.completeError(StateError('Connection failed'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('We could not confirm submission.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(name).controller!.text,
      'Missing grade',
    );
  });
  testWidgets('Phone request form remains usable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, (_) async => 'ticket');
    await tester.enterText(name, 'Missing specification');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.byType(MissingItemRequestDialog), findsNothing);
  });
}
