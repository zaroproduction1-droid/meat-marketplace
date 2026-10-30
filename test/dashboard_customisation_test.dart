import 'package:cutlink/shared/widgets/ios_dashboard_home.dart';
import 'package:cutlink/shared/widgets/ios_dashboard_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final supplier in [false, true]) {
    testWidgets(
      '${supplier ? 'Supplier' : 'Butcher'} home applies hidden sections, order and optional shortcuts',
      (tester) async {
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IosDashboardHome(
                supplier: supplier,
                businessName: 'Test business',
                greeting: 'Good morning',
                avatar: const CircleAvatar(child: Text('T')),
                unread: 0,
                onNotifications: () {},
                onAccount: () {},
                onSearch: () {},
                onAnimal: (_) {},
                onOrders: () {},
                onRefresh: () async {},
                onSaved: () {},
                metrics: [
                  DashboardMetric(
                    7,
                    'Active orders',
                    Icons.receipt_long,
                    () {},
                  ),
                ],
                attention: const [],
                recent: const [],
                buyAgain: const [],
                sections: [
                  const IosDashboardSection('ios_analytics'),
                  for (final section in IosDashboardSection.defaults(supplier))
                    if (section.id != 'ios_analytics')
                      IosDashboardSection(
                        section.id,
                        visible: section.id == 'ios_metrics',
                      ),
                ],
                shortcuts: {
                  'ios_analytics': DashboardActionRow(
                    'Analytics',
                    'Business performance',
                    Icons.insights,
                    () => opened++,
                  ),
                },
              ),
            ),
          ),
        );
        expect(find.text('Analytics'), findsOneWidget);
        expect(find.text('Buy again'), findsNothing);
        expect(find.text('Recent orders'), findsNothing);
        expect(find.text('Needs your attention'), findsNothing);
        expect(find.byKey(const ValueKey('category-art-Beef')), findsNothing);
        expect(
          tester.getTopLeft(find.text('Analytics')).dy,
          lessThan(tester.getTopLeft(find.text('Active orders')).dy),
        );
        await tester.tap(find.text('Analytics'));
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
