import 'package:cutlink/shared/widgets/ios_dashboard_home.dart';
import 'package:cutlink/shared/widgets/ios_dashboard_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reference palette stays neutral rather than inheriting pink seed surfaces',
    () {
      const light = IosDashboardPalette(false);
      const dark = IosDashboardPalette(true);
      expect(light.canvas, const Color(0xFFFCFAF7));
      expect(light.card, const Color(0xFFFCFAF7));
      expect(light.search, const Color(0xFFF1EFEC));
      expect(dark.canvas, const Color(0xFF111113));
      expect(dark.card, const Color(0xFF1C1D1F));
    },
  );

  for (final dark in [false, true]) {
    for (final supplier in [false, true]) {
      testWidgets(
        '${supplier ? 'Supplier' : 'Butcher'} ${dark ? 'dark' : 'light'} uses reference cards and images',
        (tester) async {
          tester.view.physicalSize = const Size(375, 812);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          String? animal;
          var orders = 0;
          var product = 0;
          final data = IosDashboardHome(
            supplier: supplier,
            businessName: 'Australian Wholesale Meats',
            greeting: 'Good morning, Amro',
            avatar: const CircleAvatar(child: Text('A')),
            unread: 3,
            onNotifications: () {},
            onAccount: () {},
            onSearch: () {},
            onAnimal: (value) => animal = value,
            onOrders: () => orders++,
            onSaved: () {},
            onRefresh: () async {},
            metrics: supplier
                ? [
                    DashboardMetric(
                      8,
                      'New orders',
                      Icons.receipt_long_outlined,
                      () {},
                    ),
                    DashboardMetric(
                      4,
                      'Work orders',
                      Icons.scale_outlined,
                      () {},
                    ),
                    DashboardMetric(2, 'Low stock', Icons.warning_amber, () {}),
                  ]
                : [
                    DashboardMetric(
                      3,
                      'Active orders',
                      Icons.receipt_long_outlined,
                      () {},
                    ),
                    DashboardMetric(
                      1,
                      'Ready for pickup',
                      Icons.inventory_2_outlined,
                      () {},
                    ),
                  ],
            attention: [
              DashboardActionRow(
                '4 open work orders',
                '',
                Icons.scale_outlined,
                () {},
              ),
            ],
            recent: [
              DashboardActionRow(
                'Australian Wholesale Meats',
                'Order #1164',
                Icons.local_shipping_outlined,
                () => orders++,
                detail: 'Scheduled tomorrow',
              ),
            ],
            buyAgain: [
              DashboardActionRow(
                'Striploin',
                'Australian Wholesale Meats',
                Icons.replay,
                () {},
                historicalPrice: r'$26.89',
                onOrder: () async {
                  product++;
                },
              ),
            ],
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.red,
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
              ),
              home: Scaffold(body: data),
            ),
          );
          await tester.pumpAndSettle();
          final stat = tester.widget<Material>(
            find.byKey(const ValueKey('dashboard-stat-0')),
          );
          expect(stat.color, IosDashboardPalette(dark).card);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('dashboard-stat-0')))
                .height,
            supplier ? greaterThanOrEqualTo(100) : lessThanOrEqualTo(80),
          );
          expect(tester.takeException(), isNull);
          if (!supplier) {
            for (final name in ['Beef', 'Lamb', 'Chicken']) {
              expect(
                find.byKey(ValueKey('category-art-$name')),
                findsOneWidget,
              );
            }
            final tile = tester.getSize(
              find.byKey(const ValueKey('category-Beef')),
            );
            expect(tile.height, inInclusiveRange(70, 105));
            await tester.tap(find.byKey(const ValueKey('category-Beef')));
            expect(animal, 'Beef');
            await tester.ensureVisible(find.byIcon(Icons.add));
            await tester.tap(find.byIcon(Icons.add));
            await tester.pumpAndSettle();
            expect(product, 1);
          } else {
            expect(find.text('View work orders'), findsOneWidget);
          }
          expect(orders, 0);
        },
      );
    }
  }
}
