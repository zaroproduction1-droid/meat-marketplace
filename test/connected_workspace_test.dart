import 'package:cutlink/features/customers/presentation/customer_directory.dart';
import 'package:cutlink/features/notifications/models/activity_group.dart';
import 'package:cutlink/features/notifications/presentation/activity_inbox.dart';
import 'package:cutlink/features/landing/presentation/cutlink_landing_content.dart';
import 'package:cutlink/shared/animal_catalogues/catalogue_search.dart';
import 'package:cutlink/shared/theme/cutlink_app_theme.dart';
import 'package:cutlink/shared/theme/cutlink_appearance.dart';
import 'package:cutlink/shared/widgets/ios_cut_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget host(Widget child, {bool dark = false, double scale = 1}) =>
    AppearanceScope(
      child: MaterialApp(
        theme: cutLinkAppTheme(dark ? Brightness.dark : Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );
final entries = [
  CustomerDirectoryEntry(
    id: 'a',
    name: 'A5 Butchers',
    external: false,
    terms: '30 day account',
    status: 'Approved',
    active: true,
    outstanding: 11458.67,
    overdue: 3437,
    details: (_) => const Text('A5 account controls'),
  ),
  CustomerDirectoryEntry(
    id: 'b',
    name: 'Fresh Cut Meats',
    external: true,
    terms: 'COD',
    status: 'Active',
    active: true,
    outstanding: 0,
    overdue: 0,
    details: (_) => const Text('Fresh Cut account controls'),
  ),
];
Map<String, dynamic> event(
  String id,
  String category,
  String ref,
  String title,
  int minute, {
  bool read = false,
}) => {
  'id': id,
  'category': category,
  'reference_type': category == 'messages' ? 'issue' : 'order',
  'reference_id': ref,
  'title': title,
  'detail': 'Australian Wholesale Meats',
  'created_at': DateTime.now()
      .subtract(Duration(minutes: minute))
      .toIso8601String(),
  'read_at': read ? '2026-11-01' : null,
};
List<Map<String, dynamic>> events() => [
  event('a', 'orders', 'order1', 'Order #1169 delivered', 1, read: true),
  event('b', 'delivery', 'order1', 'Out for delivery', 3),
  event('c', 'messages', 'issue1', 'New message', 2),
];
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => CutLinkAppearance.instance.setMode(ThemeMode.system));
  test(
    'Keywords require every word, work in any order, and normalize aliases',
    () {
      const fields = [
        'BEEF',
        'Rib Eye',
        'Scotch Fillet',
        'Angus',
        'grain-fed',
        'boneless',
        'Australian Wholesale Meats',
        'C',
      ];
      for (final query in [
        'beef angus scotch',
        'ANGUS  beef  fillet',
        'ribeye grainfed',
        'grain fed rib eye',
        'scotchfillet beef',
        'beef c',
      ]) {
        expect(matchesCatalogueSearch(query, fields), isTrue, reason: query);
      }
      for (final query in [
        'beef lamb',
        'beef pr',
        'grassfed ribeye',
        'beef missing',
      ]) {
        expect(matchesCatalogueSearch(query, fields), isFalse, reason: query);
      }
      expect(
        matchesCatalogueSearch('halal beef', fields, halalStatus: 'not_halal'),
        isFalse,
      );
      expect(
        matchesCatalogueSearch(
          'non-halal beef',
          fields,
          halalStatus: 'not_halal',
        ),
        isTrue,
      );
    },
  );
  test(
    'Related status events group without swallowing messages or unread state',
    () {
      final groups = groupActivities(events());
      expect(groups.length, 2);
      expect(groups.first.events.length, 2);
      expect(groups.first.latest['id'], 'a');
      expect(groups.first.unread, isTrue);
      expect(groups.last.latest['id'], 'c');
    },
  );
  for (final dark in [false, true]) {
    for (final width in [375.0, 1440.0]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('Customer directory $width scale $scale dark $dark', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await CutLinkAppearance.instance.setMode(
            dark ? ThemeMode.dark : ThemeMode.light,
          );
          await tester.pumpWidget(
            host(
              CustomerDirectory(
                entries: entries,
                onAdd: () {},
                onVip: () {},
                pendingVip: 2,
                onRefresh: () async {},
              ),
              dark: dark,
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.enterText(find.byType(TextField), 'butchers 30');
          await tester.pumpAndSettle();
          expect(find.text('Fresh Cut Meats'), findsNothing);
          await tester.ensureVisible(find.text('A5 Butchers'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('A5 Butchers'));
          await tester.pumpAndSettle();
          expect(find.text('A5 account controls'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
        testWidgets('Notification inbox $width scale $scale dark $dark', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var read = 0;
          var opened = false;
          await tester.pumpWidget(
            host(
              ActivityInbox(
                rows: events(),
                loading: false,
                unreadOnly: false,
                category: null,
                onFilter: (_, _) {},
                onOpen: (_) => opened = true,
                onRead: (e) async {
                  read = e.length;
                },
                onDismiss: (_) {},
                onRefresh: () async {},
                hasMore: false,
                onMore: () {},
              ),
              dark: dark,
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Out for delivery'), findsNothing);
          await tester.tap(find.text('Order #1169 delivered'));
          await tester.pumpAndSettle();
          expect(read, 2);
          expect(find.text('Out for delivery'), findsOneWidget);
          await tester.ensureVisible(find.text('View order'));
          await tester.tap(find.text('View order'));
          expect(opened, isTrue);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('Open customer account updates when the directory refreshes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final revision = ValueNotifier<bool>(false);
    addTearDown(revision.dispose);
    await tester.pumpWidget(
      host(
        ValueListenableBuilder<bool>(
          valueListenable: revision,
          builder: (context, updated, _) => CustomerDirectory(
            entries: [
              CustomerDirectoryEntry(
                id: 'a',
                name: 'A5 Butchers',
                external: false,
                terms: '30 day account',
                status: 'Approved',
                active: true,
                details: (_) =>
                    Text(updated ? 'Updated balance' : 'Original balance'),
              ),
            ],
            onAdd: () {},
            onVip: () {},
            pendingVip: 0,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('A5 Butchers'));
    await tester.tap(find.text('A5 Butchers'));
    await tester.pumpAndSettle();
    expect(find.text('Original balance'), findsOneWidget);
    revision.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Updated balance'), findsOneWidget);
    expect(find.text('Original balance'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Guided catalogue shows asynchronously loaded subcuts', (
    tester,
  ) async {
    final revision = ValueNotifier<int>(0);
    addTearDown(revision.dispose);
    var loading = true;
    String? cut;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            child: const Text('Browse'),
            onPressed: () => showIosCutBrowser(
              context: context,
              animal: () => 'BEEF',
              sectionId: () => cut,
              specificationId: () => null,
              sections: () => [
                {'id': 'rib', 'name': 'Rib Eye'},
              ],
              specifications: () => loading
                  ? []
                  : [
                      {'id': 'scotch', 'name': 'Scotch Fillet'},
                    ],
              onAnimal: (_) {},
              onSection: (v) => cut = v['id'],
              onSpecification: (_) {},
              onAllCuts: () {},
              onGuide: () {},
              catalogueChanges: revision,
              isLoading: () => loading,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Browse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Rib Eye'));
    await tester.tap(find.text('Rib Eye'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    loading = false;
    revision.value++;
    await tester.pumpAndSettle();
    expect(find.text('Scotch Fillet'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final reduce in [false, true]) {
    testWidgets(
      'Main cut immediately opens subcuts; back and selection work, reduce motion $reduce',
      (tester) async {
        String? section, spec;
        var animal = 'BEEF';
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduce),
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showIosCutBrowser(
                      context: context,
                      animal: () => animal,
                      sectionId: () => section,
                      specificationId: () => spec,
                      sections: () => [
                        {'id': 'rib', 'name': 'Rib Eye'},
                      ],
                      specifications: () => section == 'rib'
                          ? [
                              {'id': 'scotch', 'name': 'Scotch Fillet'},
                            ]
                          : [],
                      onAnimal: (v) => animal = v,
                      onSection: (v) {
                        section = v['id'];
                        spec = null;
                      },
                      onSpecification: (v) => spec = v['id'],
                      onAllCuts: () => section = null,
                      onGuide: () {},
                    ),
                    child: const Text('Browse'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Browse'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rib Eye'));
        await tester.pumpAndSettle();
        expect(find.text('Scotch Fillet'), findsOneWidget);
        await tester.tap(find.byTooltip('Back to main cuts'));
        await tester.pumpAndSettle();
        expect(find.text('Scotch Fillet'), findsNothing);
        await tester.tap(find.text('Rib Eye'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Scotch Fillet'));
        await tester.pumpAndSettle();
        expect(spec, 'scotch');
        expect(find.text('Browse cuts'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Prelogin appearance toggle persists light and dark', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await CutLinkAppearance.instance.setMode(ThemeMode.light);
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: CutLinkAppearance.instance,
        builder: (_, _) => host(
          CutLinkLandingContent(onSignIn: () {}, onRegister: (_) {}),
          dark: CutLinkAppearance.instance.isDark,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    expect(CutLinkAppearance.instance.isDark, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getString('cutlink.appearance'),
      'dark',
    );
    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();
    expect(CutLinkAppearance.instance.isDark, isFalse);
    expect(tester.takeException(), isNull);
  });
}
