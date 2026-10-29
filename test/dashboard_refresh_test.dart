import 'package:cutlink/shared/animal_catalogues/marketplace_search_intent.dart';
import 'package:cutlink/shared/theme/cutlink_appearance.dart';
import 'package:cutlink/shared/widgets/retained_ios_workspace.dart';
import 'package:cutlink/shared/widgets/ios_dashboard_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoadProbe extends StatefulWidget {
  const LoadProbe({super.key, required this.onLoad});
  final VoidCallback onLoad;
  @override
  State<LoadProbe> createState() => _LoadProbeState();
}

class _LoadProbeState extends State<LoadProbe> {
  int count = 0;
  @override
  void initState() {
    super.initState();
    widget.onLoad();
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('Retained count $count'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CutLinkAppearance.instance.setMode(ThemeMode.light);
  });

  test('opening Search does not request all stock', () {
    expect(
      hasMarketplaceSearchIntent(
        cutSelected: false,
        query: '',
        supplierQuery: '',
        halalOnly: false,
      ),
      isFalse,
    );
    expect(
      hasMarketplaceSearchIntent(
        cutSelected: false,
        query: 'b',
        supplierQuery: '',
        halalOnly: false,
      ),
      isFalse,
    );
    expect(
      hasMarketplaceSearchIntent(
        cutSelected: false,
        query: 'beef',
        supplierQuery: '',
        halalOnly: false,
      ),
      isTrue,
    );
    expect(
      hasMarketplaceSearchIntent(
        cutSelected: true,
        query: '',
        supplierQuery: '',
        halalOnly: false,
      ),
      isTrue,
    );
    expect(
      hasMarketplaceSearchIntent(
        cutSelected: false,
        query: '',
        supplierQuery: 'A5',
        halalOnly: false,
      ),
      isTrue,
    );
    expect(
      hasMarketplaceSearchIntent(
        cutSelected: false,
        query: '',
        supplierQuery: '',
        halalOnly: true,
      ),
      isTrue,
    );
  });

  test(
    'appearance persists the selected mode and preserves light colours',
    () async {
      expect(CutLinkPalette.color(0xFF202830), const Color(0xFF202830));
      await CutLinkAppearance.instance.setMode(ThemeMode.dark);
      expect(CutLinkPalette.surface, const Color(0xFF1C1C1E));
      expect(CutLinkPalette.color(0xFF202830), const Color(0xFFF2F2F7));
      expect(
        (await SharedPreferences.getInstance()).getString('cutlink.appearance'),
        'dark',
      );
      await CutLinkAppearance.instance.load();
      expect(CutLinkAppearance.instance.mode, ThemeMode.dark);
    },
  );

  testWidgets('returning to a visited workspace preserves its state and load', (
    tester,
  ) async {
    final selected = ValueNotifier('orders');
    addTearDown(selected.dispose);
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: selected,
            builder: (_, value, _) => RetainedIosWorkspace(
              child: KeyedSubtree(
                key: ValueKey(value),
                child: value == 'orders'
                    ? LoadProbe(onLoad: () => loads++)
                    : const Text('Home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Retained count 0'));
    await tester.pump();
    selected.value = 'dashboard';
    await tester.pumpAndSettle();
    expect(find.text('Retained count 1'), findsNothing);
    selected.value = 'orders';
    await tester.pumpAndSettle();
    expect(find.text('Retained count 1'), findsOneWidget);
    expect(loads, 1);
  });

  for (final supplier in [false, true]) {
    testWidgets(
      '${supplier ? 'Supplier' : 'Butcher'} home fits a narrow phone with large text',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.5)),
                child: Scaffold(
                  body: IosDashboardHome(
                    supplier: supplier,
                    businessName: 'Australian Wholesale Meats',
                    greeting: 'Good morning',
                    avatar: const CircleAvatar(child: Text('A')),
                    unread: 2,
                    onNotifications: () {},
                    onAccount: () {},
                    onSearch: () {},
                    onAnimal: (_) {},
                    onOrders: () {},
                    onSaved: () {},
                    onRefresh: () async {},
                    metrics: [
                      DashboardMetric(3, 'Active orders', Icons.receipt, () {}),
                    ],
                    attention: const [],
                    recent: const [],
                    buyAgain: const [],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            supplier ? 'Your business today' : 'What do you need today?',
          ),
          findsOneWidget,
        );
      },
    );
  }
}
