import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meat_marketplace/shared/widgets/interactive_beef_cuts_map.dart';
import 'package:meat_marketplace/shared/widgets/chicken_cut_catalogue.dart';
import 'package:meat_marketplace/shared/widgets/interactive_cuts_map.dart';

void main() {
  testWidgets('beef still loads through the shared map renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InteractiveBeefCutsMap(onCutSelected: (_) {})),
      ),
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  test('chicken selectors resolve catalogue codes and display names', () {
    for (final entry in ChickenCutCatalogue.sectionAliases.entries) {
      for (final alias in entry.value) {
        final row = <String, dynamic>{'id': entry.key, 'code': alias};
        expect(ChickenCutCatalogue.sectionForRegion(entry.key, [row]), row);
        final namedRow = <String, dynamic>{'id': entry.key, 'name': alias};
        expect(
          ChickenCutCatalogue.sectionForRegion(entry.key, [namedRow]),
          namedRow,
        );
      }
    }
    expect(
      ChickenCutCatalogue.sectionForRegion('breast', [
        {'code': 'THIGH'},
      ]),
      isNull,
    );
  });

  testWidgets('chicken artwork renders and every selector responds at scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveCutsMap(
            assetPath: 'assets/images/CutLink-Chicken-Cuts.svg',
            viewBoxWidth: 1536,
            viewBoxHeight: 1250,
            renderSvg: true,
            maxWidth: 760,
            onCutSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final target = find.byType(GestureDetector).first;
    final rect = tester.getRect(target);
    const points = <String, Offset>{
      'neck': Offset(474, 306),
      'tail': Offset(1154, 313),
      'back-frame': Offset(873, 338),
      'breast': Offset(491, 504),
      'maryland': Offset(1018, 617),
      'thigh': Offset(960, 678),
      'drumstick': Offset(873, 750),
      'wing': Offset(779, 460),
      'tenderloin': Offset(538, 565),
      'whole-chicken': Offset(851, 140),
      'chicken-chop-cutlet': Offset(1059, 1087),
      'mince-manufacturing': Offset(505, 1187),
      'misc-offal-other': Offset(1059, 1187),
    };
    for (final entry in points.entries) {
      await tester.tapAt(
        rect.topLeft +
            Offset(
              entry.value.dx * rect.width / 1536,
              entry.value.dy * rect.height / 1250,
            ),
      );
      expect(selected, entry.key, reason: '${entry.key} hit area');
    }
    await tester.tapAt(
      rect.topLeft + Offset(505 * rect.width / 1536, 1087 * rect.height / 1250),
    );
    expect(selected, 'back-frame');
    selected = null;
    await tester.tapAt(rect.topLeft + const Offset(5, 5));
    expect(selected, isNull);
  });
}
