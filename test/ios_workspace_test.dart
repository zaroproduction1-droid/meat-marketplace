import 'package:cutlink/shared/navigation/workspace_navigation.dart';
import 'package:cutlink/shared/widgets/ios_workspace.dart';
import 'package:cutlink/shared/widgets/ios_density.dart';
import 'package:cutlink/shared/widgets/phone_layout.dart';
import 'package:cutlink/shared/widgets/unsaved_changes_guard.dart';
import 'package:cutlink/features/admin/presentation/admin_theme.dart';
import 'package:cutlink/shared/widgets/public_auth_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  double scale = 1,
}) => MaterialApp(
  theme: ThemeData(platform: platform),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    ),
  ),
);

void main() {
  testWidgets('Compact supplier identity gets full width above its action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        Scaffold(
          body: IosAdaptiveRow(
            desktop: Row(
              children: [
                Container(width: 52, height: 52, color: Colors.transparent),
                const SizedBox(width: 15),
                const Expanded(child: Text('Australian Wholesale Meats')),
                FilledButton(
                  onPressed: () {},
                  child: const Text('VIP + Credit Active'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.text('Australian Wholesale Meats')).width,
      greaterThan(220),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Workspace navigation visibly transitions before settling', (
    tester,
  ) async {
    final page = ValueNotifier(false);
    addTearDown(page.dispose);
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: page,
            builder: (context, value, _) => IosWorkspaceTransition(
              child: SizedBox.expand(
                key: ValueKey(value),
                child: Text(value ? 'Next page' : 'First page'),
              ),
            ),
          ),
        ),
      ),
    );
    page.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('First page'), findsOneWidget);
    expect(find.text('Next page'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('First page'), findsNothing);
  });

  testWidgets(
    'Left-edge swipe requests workspace back without popping the route',
    (tester) async {
      var backs = 0;
      await tester.pumpWidget(
        host(
          Scaffold(
            body: IosBackSurface(
              onBack: () => backs++,
              child: const Center(child: Text('Signed in')),
            ),
          ),
        ),
      );
      await tester.dragFrom(const Offset(8, 150), const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(backs, 1);
      expect(find.text('Signed in'), findsOneWidget);
    },
  );

  testWidgets('A leftward edge gesture does not navigate back', (tester) async {
    var backs = 0;
    await tester.pumpWidget(
      host(
        Scaffold(
          body: IosBackSurface(
            onBack: () => backs++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.dragFrom(const Offset(18, 150), const Offset(-12, 0));
    await tester.pumpAndSettle();
    expect(backs, 0);
  });
  testWidgets('Admin More exposes sections outside the five primary tabs', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      host(
        Scaffold(
          body: AdminNavigation(
            items: const {
              'overview': 'Overview',
              'businesses': 'Businesses',
              'billing': 'Billing',
              'support': 'Support inbox',
              'audit': 'Audit history',
              'preferences': 'Settings',
              'homepage': 'Front page',
            },
            value: 'overview',
            onChanged: (value) => selected = value,
            child: const Text('Admin content'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Audit history'));
    await tester.tap(find.text('Audit history'));
    await tester.pumpAndSettle();
    expect(selected, 'audit');
    expect(find.text('Admin tools'), findsNothing);
  });

  testWidgets(
    'iOS registration frame remains scrollable with an open keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        host(
          const PublicAuthFrame(
            title: 'Register',
            description: 'Your account',
            step: 2,
            child: Column(
              children: [
                Text('Create account'),
                SizedBox(height: 500),
                TextField(decoration: InputDecoration(labelText: 'Email')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Email'));
      expect(tester.takeException(), isNull);
      expect(find.text('Step 2 of 3'), findsOneWidget);
    },
  );

  testWidgets('Five tabs remain usable on a narrow iPhone with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selection = -1;
    await tester.pumpWidget(
      host(
        Scaffold(
          bottomNavigationBar: IosBottomBar(
            tabs: const [
              IosTab('Home', Icons.home),
              IosTab('My CutLink', Icons.person),
              IosTab('Search', Icons.search),
              IosTab('Orders', Icons.receipt),
              IosTab('Saved', Icons.favorite),
            ],
            index: 0,
            onSelected: (value) => selection = value,
          ),
        ),
        scale: 1.8,
      ),
    );
    await tester.tap(find.text('Search'));
    expect(selection, 2);
    expect(tester.takeException(), isNull);
    expect(find.byType(InkWell), findsNWidgets(5));
  });

  testWidgets('Account shortcuts and grouped tools all remain reachable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        Scaffold(
          body: IosAccountHub(
            name: 'CutLink Test Supplier',
            role: 'Supplier account',
            shortcuts: [
              IosMenuLink('Accounts', Icons.wallet, () => taps++),
              IosMenuLink('Notifications', Icons.notifications, () => taps++),
              IosMenuLink('Messages', Icons.chat, () => taps++),
            ],
            groups: [
              IosMenuGroup('Selling', [
                IosMenuLink(
                  'Inventory & pricing',
                  Icons.inventory,
                  () => taps++,
                ),
              ]),
              IosMenuGroup('Business', [
                IosMenuLink('Settings', Icons.settings, () => taps++),
              ]),
            ],
            onSignOut: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Messages'));
    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    expect(taps, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'iOS overflow keeps every toolbar action and executes the chosen action',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var refreshed = false;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              appBar: phoneAppBar(
                context,
                AppBar(
                  title: const Text('Orders'),
                  actions: [
                    IconButton(
                      tooltip: 'Add',
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      tooltip: 'Search',
                      onPressed: () {},
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      tooltip: 'Refresh orders',
                      onPressed: () => refreshed = true,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh orders'));
      await tester.pumpAndSettle();
      expect(refreshed, isTrue);
      expect(find.text('Page actions'), findsNothing);
    },
  );

  testWidgets('Desktop retains the original app bar', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = AppBar(title: const Text('Desktop'));
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            expect(useIosWorkspace(context), isFalse);
            expect(identical(phoneAppBar(context, original), original), isTrue);
            return Scaffold(appBar: original);
          },
        ),
        platform: TargetPlatform.windows,
      ),
    );
  });

  testWidgets(
    'Tab switching respects keep editing and discard for unsaved forms',
    (tester) async {
      final navigation = WorkspaceNavigation();
      var left = false;
      var discarded = false;
      await tester.pumpWidget(
        host(
          WorkspaceNavigationScope(
            navigation: navigation,
            child: Scaffold(
              body: UnsavedChangesGuard(
                isDirty: () => !discarded,
                isBusy: () => false,
                onDiscard: () async => discarded = true,
                child: const Text('Product form'),
              ),
            ),
          ),
        ),
      );
      final first = navigation.navigate(() => left = true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await first;
      expect(left, isFalse);
      final second = navigation.navigate(() => left = true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard and leave'));
      await tester.pumpAndSettle();
      await second;
      expect(left && discarded, isTrue);
    },
  );

  testWidgets('A saving form blocks tab navigation without discarding', (
    tester,
  ) async {
    final navigation = WorkspaceNavigation();
    var left = false;
    await tester.pumpWidget(
      host(
        WorkspaceNavigationScope(
          navigation: navigation,
          child: Scaffold(
            body: UnsavedChangesGuard(
              isDirty: () => true,
              isBusy: () => true,
              child: const Text('Saving'),
            ),
          ),
        ),
      ),
    );
    await navigation.navigate(() => left = true);
    await tester.pump();
    expect(left, isFalse);
    expect(find.text('Please wait for saving to finish.'), findsOneWidget);
  });
}
