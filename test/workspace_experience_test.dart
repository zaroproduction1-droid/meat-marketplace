import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutlink/shared/widgets/unsaved_changes_guard.dart';
import 'package:cutlink/shared/widgets/workspace_loading.dart';

void main() {
  testWidgets('Loading placeholders fit a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WorkspaceLoading(label: 'Loading products…')),
      ),
    );
    expect(find.text('Loading products…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back protects unsaved edits and permits explicit discard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UnsavedChangesGuard(
                    isDirty: () => true,
                    isBusy: () => false,
                    child: Scaffold(
                      appBar: AppBar(title: const Text('Editor')),
                    ),
                  ),
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
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard and leave'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}
