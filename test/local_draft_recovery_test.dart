import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cutlink/shared/drafts/local_draft_store.dart';
import 'package:cutlink/shared/widgets/local_draft_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Draft scopes separate users, businesses, products and support roles',
    () {
      final scopes = {
        LocalDraftStore.scope('u1', 'b1', 'product', 'p1'),
        LocalDraftStore.scope('u2', 'b1', 'product', 'p1'),
        LocalDraftStore.scope('u1', 'b2', 'product', 'p1'),
        LocalDraftStore.scope('u1', 'b1', 'product', 'p2'),
        LocalDraftStore.scope('u1', 'b1', 'support', 'p1'),
        LocalDraftStore.scope('u1', 'b1', 'admin-support', 'p1'),
      };
      expect(scopes.length, 6);
    },
  );

  test(
    'Write/read survives a new consumer and clear removes the backup',
    () async {
      final scope = LocalDraftStore.scope('u', 'b', 'product', 'persist');
      await LocalDraftStore.write(scope, {
        'text': {'name': 'Draft name'},
        'values': {'active': false},
      });
      expect((await LocalDraftStore.read(scope))?['text'], {
        'name': 'Draft name',
      });
      await LocalDraftStore.clear(scope);
      expect(await LocalDraftStore.read(scope), isNull);
    },
  );

  test(
    'Clearing invalidates writes already queued before a committed save',
    () async {
      final scope = LocalDraftStore.scope('u', 'b', 'product', 'race');
      final first = LocalDraftStore.write(scope, {
        'text': {'name': 'old'},
        'values': {},
      });
      final second = LocalDraftStore.write(scope, {
        'text': {'name': 'new'},
        'values': {},
      });
      final clear = LocalDraftStore.clear(scope);
      await Future.wait([first, second, clear]);
      expect(await LocalDraftStore.read(scope), isNull);
      await LocalDraftStore.write(scope, {
        'text': {'name': 'next edit'},
        'values': {},
      });
      expect((await LocalDraftStore.read(scope))?['text'], {
        'name': 'next edit',
      });
    },
  );

  test('Expired and corrupt records are removed', () async {
    final scope = LocalDraftStore.scope('u', 'b', 'support', 'expired');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      scope,
      jsonEncode({
        'version': 1,
        'saved_at': DateTime.now()
            .subtract(const Duration(days: 8))
            .toIso8601String(),
        'data': {
          'text': {'message': 'old'},
          'values': {},
        },
      }),
    );
    expect(await LocalDraftStore.read(scope), isNull);
    expect(prefs.getString(scope), isNull);
    await prefs.setString(scope, 'broken json');
    expect(await LocalDraftStore.read(scope), isNull);
  });

  testWidgets('Draft requires Restore before replacing current form text', (
    tester,
  ) async {
    final scope = LocalDraftStore.scope('u', 'b', 'product', 'restore');
    await LocalDraftStore.write(scope, {
      'text': {'name': 'Recovered name'},
      'values': {},
    });
    final controller = TextEditingController(text: 'Server name');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalDraftRecovery(
            scope: scope,
            controllers: {'name': controller},
            values: () => {},
            restoreValues: (_) async {},
            isBusy: () => false,
            isCurrentUser: () => true,
            child: TextField(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.text, 'Server name');
    await tester.tap(find.text('Restore draft'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Recovered name');
  });

  testWidgets('Discard leaves server text intact and removes the backup', (
    tester,
  ) async {
    final scope = LocalDraftStore.scope('u', 'b', 'product', 'discard');
    await LocalDraftStore.write(scope, {
      'text': {'name': 'Old draft'},
      'values': {},
    });
    final controller = TextEditingController(text: 'Server name');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalDraftRecovery(
            scope: scope,
            controllers: {'name': controller},
            values: () => {},
            restoreValues: (_) async {},
            isBusy: () => false,
            isCurrentUser: () => true,
            child: TextField(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Server name');
    expect(await LocalDraftStore.read(scope), isNull);
  });
}
