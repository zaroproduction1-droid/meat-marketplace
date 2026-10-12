import 'dart:async';

import 'package:cutlink/features/pricing/presentation/vip_customer_prices_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const empty = VipCustomerPriceDraft(
    amountText: '',
    priceBasis: 'kilogram',
    minimumText: '',
  );
  const rows = [
    VipCustomerPriceEntry(
      customerId: 'harbour',
      name: 'Harbour Butchers',
      saved: empty,
      initial: empty,
    ),
    VipCustomerPriceEntry(
      customerId: 'valley',
      name: 'Valley Butchers',
      saved: empty,
      initial: empty,
    ),
  ];
  Future<void> open(
    WidgetTester tester,
    Map<String, VipCustomerPriceDraft> changes,
    Future<bool> Function() save, {
    bool catchWeight = true,
    List<VipCustomerPriceEntry> customers = rows,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => VipCustomerPricesDialog(
                  productName: 'Beef Scotch Fillet',
                  customers: customers,
                  catchWeight: catchWeight,
                  pendingCount: () => changes.length,
                  onDraftChanged: (id, draft) {
                    if (draft == null) {
                      changes.remove(id);
                    } else {
                      changes[id] = draft;
                    }
                  },
                  onSaveAll: save,
                ),
              ),
              child: const Text('Open VIP'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open VIP'));
    await tester.pumpAndSettle();
  }

  testWidgets('Order options validate whole cartons without another popup', (
    tester,
  ) async {
    final changes = <String, VipCustomerPriceDraft>{};
    var calls = 0;
    await open(tester, changes, () async {
      calls++;
      changes.clear();
      return true;
    });
    await tester.enterText(
      find.byKey(const ValueKey('vip-price-harbour')),
      '18',
    );
    await tester.tap(find.byKey(const ValueKey('vip-options-harbour')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('vip-minimum-harbour')),
      '1.5',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vip-save-all')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Use a whole number of cartons.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('vip-minimum-harbour')),
      '2.0',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vip-save-all')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(changes, isEmpty);
  });

  testWidgets('An invalid offscreen draft is brought into view before saving', (
    tester,
  ) async {
    const invalid = VipCustomerPriceDraft(
      amountText: '-1',
      priceBasis: 'kilogram',
      minimumText: '',
    );
    final changes = <String, VipCustomerPriceDraft>{'test19': invalid};
    var calls = 0;
    final customers = List.generate(
      20,
      (index) => VipCustomerPriceEntry(
        customerId: 'test$index',
        name: 'Test Butcher ${index.toString().padLeft(2, '0')}',
        saved: empty,
        initial: index == 19 ? invalid : empty,
      ),
    );
    await open(tester, changes, () async {
      calls++;
      changes.clear();
      return true;
    }, customers: customers);
    expect(find.byKey(const ValueKey('vip-price-test19')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('vip-save-all')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byKey(const ValueKey('vip-price-test19')), findsOneWidget);
    expect(find.text('Enter a valid price of 0 or more.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('vip-price-test19')),
      '12',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vip-save-all')));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('Phone keyboard does not hide the fixed save control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final changes = <String, VipCustomerPriceDraft>{};
    await open(tester, changes, () async {
      changes.clear();
      return true;
    });
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('vip-price-harbour')),
      '25',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('vip-save-all')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Edit two prices directly, preserve hidden draft, save once and stay open',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final changes = <String, VipCustomerPriceDraft>{};
      var saves = 0;
      await open(tester, changes, () async {
        saves++;
        expect(changes.length, 2);
        changes.clear();
        return true;
      });
      expect(find.text('Set Price'), findsNothing);
      expect(find.byKey(const ValueKey('vip-logo-harbour')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('vip-price-harbour')),
        '12.50',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vip-price-valley')),
        '13.75',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vip-customer-search')),
        'Valley',
      );
      await tester.pumpAndSettle();
      expect(find.text('Harbour Butchers'), findsNothing);
      expect(changes['harbour']!.amountText, '12.50');
      await tester.enterText(
        find.byKey(const ValueKey('vip-customer-search')),
        '',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('vip-price-harbour')))
            .controller!
            .text,
        '12.50',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('vip-save-all')));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(changes, isEmpty);
      expect(find.text('All price changes saved.'), findsOneWidget);
      expect(find.text('VIP customer prices'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Save failure keeps edits and permits retry', (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final changes = <String, VipCustomerPriceDraft>{};
    var succeed = false;
    var calls = 0;
    await open(tester, changes, () async {
      calls++;
      if (succeed) {
        changes.clear();
      }
      return succeed;
    });
    await tester.enterText(
      find.byKey(const ValueKey('vip-price-harbour')),
      '17',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vip-save-all')));
    await tester.pumpAndSettle();
    expect(changes['harbour']!.amountText, '17');
    expect(find.textContaining('Your edits are kept'), findsOneWidget);
    succeed = true;
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vip-save-all')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(changes, isEmpty);
  });

  testWidgets('Invalid prices prevent the save callback', (tester) async {
    final changes = <String, VipCustomerPriceDraft>{};
    var calls = 0;
    await open(tester, changes, () async {
      calls++;
      return true;
    });
    await tester.enterText(
      find.byKey(const ValueKey('vip-price-harbour')),
      '-2',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vip-save-all')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(changes.length, 1);
    expect(find.text('Enter a valid price of 0 or more.'), findsOneWidget);
  });

  testWidgets('Phone layout keeps the price box and save button accessible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final changes = <String, VipCustomerPriceDraft>{};
    await open(tester, changes, () async {
      changes.clear();
      return true;
    });
    await tester.enterText(
      find.byKey(const ValueKey('vip-price-harbour')),
      '19.99',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vip-save-all')));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Closing keeps drafts for the inventory Save all action', (
    tester,
  ) async {
    final changes = <String, VipCustomerPriceDraft>{};
    await open(tester, changes, () async => true);
    await tester.enterText(
      find.byKey(const ValueKey('vip-price-harbour')),
      '21',
    );
    await tester.tap(find.byKey(const ValueKey('vip-close')));
    await tester.pumpAndSettle();
    expect(changes['harbour']!.amountText, '21');
    expect(find.text('VIP customer prices'), findsNothing);
  });

  testWidgets('Saving disables repeat submission and closing', (tester) async {
    final changes = <String, VipCustomerPriceDraft>{};
    final completer = Completer<bool>();
    var calls = 0;
    await open(tester, changes, () {
      calls++;
      return completer.future;
    });
    await tester.enterText(
      find.byKey(const ValueKey('vip-price-harbour')),
      '22',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vip-save-all')));
    await tester.pump();
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const ValueKey('vip-save-all')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('vip-close')))
          .onPressed,
      isNull,
    );
    expect(calls, 1);
    completer.complete(false);
    await tester.pumpAndSettle();
    expect(changes.length, 1);
  });

  testWidgets('Reverting an existing amount removes the queued change', (
    tester,
  ) async {
    const original = VipCustomerPriceDraft(
      amountText: '12.5',
      priceBasis: 'kilogram',
      minimumText: '1.0',
    );
    final changes = <String, VipCustomerPriceDraft>{};
    await open(
      tester,
      changes,
      () async => true,
      customers: const [
        VipCustomerPriceEntry(
          customerId: 'harbour',
          name: 'Harbour Butchers',
          saved: original,
          initial: original,
        ),
      ],
    );
    await tester.enterText(
      find.byKey(const ValueKey('vip-price-harbour')),
      '13',
    );
    expect(changes.length, 1);
    await tester.enterText(
      find.byKey(const ValueKey('vip-price-harbour')),
      '12.50',
    );
    expect(changes, isEmpty);
    expect(original.minimumError(true), isNull);
  });
}
