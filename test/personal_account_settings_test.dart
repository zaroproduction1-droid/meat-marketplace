import 'dart:async';
import 'package:cutlink/features/authentication/presentation/personal_account_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const row = {'first_name': 'Old name', 'last_name': '', 'phone': ''};
  Future<void> open(WidgetTester tester, AccountProfileSaver save) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalAccountSettingsPage(
          loadProfile: () async => Map<String, dynamic>.from(row),
          saveProfile: save,
          signInEmail: 'account@example.invalid',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final first = find.byKey(const ValueKey('account-first-name'));
  final save = find.byKey(const ValueKey('account-save'));
  testWidgets(
    'Existing identity is visible and save sends only personal fields',
    (tester) async {
      Map<String, dynamic>? captured;
      await open(tester, (values) async {
        captured = values;
        return values;
      });
      expect(tester.widget<TextFormField>(first).controller!.text, 'Old name');
      expect(find.text('account@example.invalid'), findsOneWidget);
      await tester.enterText(first, 'New name');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(captured, {
        'first_name': 'New name',
        'last_name': '',
        'phone': '',
      });
      expect(
        find.text('Your account details have been saved.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('Blank first name is rejected', (tester) async {
    var calls = 0;
    await open(tester, (values) async {
      calls++;
      return values;
    });
    await tester.enterText(first, ' ');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Enter your first name.'), findsOneWidget);
  });
  testWidgets('Saving blocks duplicates and error retains edits', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    await open(tester, (_) {
      calls++;
      return pending.future;
    });
    await tester.enterText(first, 'New name');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.tap(save);
    expect(calls, 1);
    expect(tester.widget<ButtonStyleButton>(save).onPressed, isNull);
    pending.completeError(StateError('Unavailable'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(first).controller!.text, 'New name');
    expect(find.textContaining('Could not save your details.'), findsOneWidget);
  });
  testWidgets('Phone account screen scrolls to save without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, (values) async => values);
    await tester.enterText(first, 'Updated name');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Your account details have been saved.'), findsOneWidget);
  });
}
