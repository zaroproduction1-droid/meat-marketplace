import 'dart:async';

import 'package:cutlink/shared/widgets/launch_page_ready.dart';

import 'package:cutlink/shared/widgets/cutlink_launch_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'Launch cover waits for the usable destination, Reduce Motion $reduced',
      (tester) async {
        VoidCallback? pageReady;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: CutLinkLaunchGate(
              initialise: () async {},
              waitForFirstPage: true,
              child: Builder(
                builder: (context) {
                  pageReady = () => LaunchPageReady.signal(context);
                  return const Text('Destination mounted');
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Destination mounted'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('cutlink-launch-cover')),
          findsOneWidget,
        );
        pageReady!();
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('cutlink-launch-cover')),
          findsNothing,
        );
        expect(find.text('Destination mounted'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Startup runs during the animation and the ready app mounts once',
    (tester) async {
      final ready = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CutLinkLaunchGate(
            initialise: () {
              calls++;
              return ready.future;
            },
            child: const Text('Ready workspace'),
          ),
        ),
      );
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Ready workspace'), findsNothing);
      ready.complete();
      await tester.pump();
      expect(find.text('Ready workspace'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cutlink-launch-cover')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cutlink-launch-cover')), findsNothing);
      expect(find.text('Ready workspace'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Slow startup waits safely then reveals the app', (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: CutLinkLaunchGate(
          initialise: () => ready.future,
          child: const Text('Ready workspace'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ready workspace'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    ready.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cutlink-launch-cover')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Failed startup offers retry without exposing the error details',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CutLinkLaunchGate(
            initialise: () async {
              if (++calls == 1) {
                throw StateError('private config');
              }
            },
            child: const Text('Ready workspace'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('private config'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Ready workspace'), findsOneWidget);
      expect(find.byKey(const ValueKey('cutlink-launch-cover')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Reduce Motion skips the animation wait', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: CutLinkLaunchGate(
          initialise: () async {},
          child: const Text('Ready workspace'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cutlink-launch-cover')), findsNothing);
    expect(find.text('Ready workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
