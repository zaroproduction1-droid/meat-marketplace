import 'package:cutlink/shared/theme/cutlink_appearance.dart';
import 'package:cutlink/shared/theme/workspace_message_theme.dart';
import 'package:cutlink/shared/widgets/ios_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  for (final dark in [false, true]) {
    for (final ios in [false, true]) {
      testWidgets(
        '${ios ? 'iOS' : 'web'} ${dark ? 'dark' : 'light'} confirmations have readable text and controls',
        (tester) async {
          await CutLinkAppearance.instance.setMode(
            dark ? ThemeMode.dark : ThemeMode.light,
          );
          final brightness = dark ? Brightness.dark : Brightness.light;
          final base = ThemeData(
            brightness: brightness,
            snackBarTheme: workspaceMessageTheme(brightness),
          );
          final theme = ios ? IosWorkspaceStyle.theme(base) : base;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dashboard layout saved')),
                    ),
                    child: const Text('Show confirmation'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Show confirmation'));
          await tester.pumpAndSettle();
          final text = find.text('Dashboard layout saved');
          final style = DefaultTextStyle.of(tester.element(text)).style;
          final panel = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(SnackBar),
                  matching: find.byType(Material),
                )
                .first,
          );
          double contrast(Color a, Color b) {
            final x = a.computeLuminance(), y = b.computeLuminance();
            return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
          }

          expect(
            contrast(style.color!, panel.color!),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(theme.snackBarTheme.closeIconColor!, panel.color!),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(theme.snackBarTheme.actionTextColor!, panel.color!),
            greaterThanOrEqualTo(4.5),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
