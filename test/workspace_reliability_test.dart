import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutlink/shared/widgets/unsaved_changes_guard.dart';
import 'package:cutlink/shared/widgets/workspace_back_button.dart';
import 'package:cutlink/shared/widgets/workspace_request_error.dart';

void main() {
  testWidgets('Dashboard back cannot bypass dirty form protection', (
    tester,
  ) async {
    var left = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceBackScope(
          onBack: () => left++,
          child: UnsavedChangesGuard(
            isDirty: () => true,
            isBusy: () => false,
            child: Scaffold(
              appBar: AppBar(leading: const WorkspaceBackButton()),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(WorkspaceBackButton));
    await tester.pumpAndSettle();
    expect(left, 0);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(left, 0);
    await tester.tap(find.byType(WorkspaceBackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard and leave'));
    await tester.pumpAndSettle();
    expect(left, 1);
  });

  testWidgets('Saving blocks dashboard navigation', (tester) async {
    var left = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceBackScope(
          onBack: () => left++,
          child: UnsavedChangesGuard(
            isDirty: () => false,
            isBusy: () => true,
            child: Scaffold(
              appBar: AppBar(leading: const WorkspaceBackButton()),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(WorkspaceBackButton));
    await tester.pump();
    expect(left, 0);
    expect(find.text('Please wait for saving to finish.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Support warning explains draft scope', (tester) async {
    const message = 'Unsent messages will be discarded.';
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceBackScope(
          onBack: () {},
          child: UnsavedChangesGuard(
            isDirty: () => true,
            isBusy: () => false,
            message: message,
            child: Scaffold(
              appBar: AppBar(leading: const WorkspaceBackButton()),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(WorkspaceBackButton));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('Failed load offers a working retry button', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkspaceRequestError(onRetry: () => retried++)),
      ),
    );
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
