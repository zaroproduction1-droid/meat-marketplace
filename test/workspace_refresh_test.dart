import 'package:cutlink/shared/theme/cutlink_app_theme.dart';
import 'package:cutlink/shared/theme/cutlink_appearance.dart';
import 'package:cutlink/shared/widgets/compact_workspace_tile.dart';
import 'package:cutlink/shared/widgets/interactive_animal_browser.dart';
import 'package:cutlink/shared/widgets/ios_dashboard_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async => CutLinkAppearance.instance.setMode(ThemeMode.system));

  for (final dark in [false, true]) {
    test(
      'Shared ${dark ? 'dark' : 'light'} surfaces and actions have contrast',
      () {
        final theme = cutLinkAppTheme(
          dark ? Brightness.dark : Brightness.light,
        );
        final scheme = theme.colorScheme;
        expect(
          contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(7),
        );
        expect(
          contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(theme.dialogTheme.backgroundColor, scheme.surface);
        expect(theme.bottomSheetTheme.modalBackgroundColor, scheme.surface);
        expect(theme.popupMenuTheme.color, scheme.surface);
        expect(
          theme.inputDecorationTheme.fillColor,
          scheme.surfaceContainerHigh,
        );
        final style = theme.filledButtonTheme.style!;
        expect(
          contrast(
            style.foregroundColor!.resolve({})!,
            style.backgroundColor!.resolve({})!,
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
    for (final scale in [1.0, 1.6]) {
      testWidgets('Compact tile at 375px, scale $scale, dark $dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: cutLinkAppTheme(dark ? Brightness.dark : Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(375, 812),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: CompactWorkspaceTile(
                  title: 'Australian Wholesale Meats',
                  subtitle: 'Order #1164 · Delivery · 3 products',
                  leading: const SizedBox(
                    width: 66,
                    height: 72,
                    child: Icon(Icons.local_shipping_outlined),
                  ),
                  detail: const Text('Awaiting supplier approval'),
                  trailing: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz),
                  ),
                  onTap: () => opened = true,
                ),
              ),
            ),
          ),
        );
        final card = tester.widget<Card>(find.byType(Card));
        expect(
          card.color,
          cutLinkAppTheme(dark ? Brightness.dark : Brightness.light)
              .colorScheme
              .surface,
        );
        await tester.tap(find.text('Australian Wholesale Meats'));
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Phone catalogue scroll moves diagram and reaches final subcut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimalCatalogueLayout(
            diagram: const ColoredBox(
              key: ValueKey('diagram'),
              color: Colors.blue,
            ),
            choices: Column(
              children: [
                for (var i = 0; i < 20; i++)
                  SizedBox(height: 60, child: Text('Subcut $i')),
              ],
            ),
          ),
        ),
      ),
    );
    final before = tester.getTopLeft(find.byKey(const ValueKey('diagram'))).dy;
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('diagram'))).dy,
      lessThan(before),
    );
    await tester.scrollUntilVisible(find.text('Subcut 19'), 350);
    expect(find.text('Subcut 19').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Favourites mode shows all four selected products without Buy again',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IosDashboardHome(
              supplier: false,
              favouritesMode: true,
              businessName: 'A5 Butchers',
              greeting: 'Good morning',
              avatar: const CircleAvatar(child: Text('A')),
              unread: 0,
              onNotifications: () {},
              onAccount: () {},
              onSearch: () {},
              onAnimal: (_) {},
              onOrders: () {},
              onSaved: () {},
              onRefresh: () async {},
              metrics: const [],
              attention: const [],
              recent: const [],
              buyAgain: [
                for (var i = 1; i <= 4; i++)
                  DashboardActionRow(
                    'Favourite $i',
                    'Supplier',
                    Icons.favorite,
                    () {},
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Favourite products'), findsOneWidget);
      expect(find.text('Favourite 4'), findsOneWidget);
      expect(find.text('Buy again'), findsNothing);
      expect(find.text('Last paid'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
