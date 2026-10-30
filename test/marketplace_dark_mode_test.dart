import 'package:cutlink/shared/theme/cutlink_appearance.dart';
import 'package:cutlink/shared/widgets/interactive_animal_browser.dart';
import 'package:cutlink/shared/widgets/ios_cut_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Animal choices and selection bar remain readable in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await CutLinkAppearance.instance.setMode(
          dark ? ThemeMode.dark : ThemeMode.light,
        );
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: Column(
                children: [
                  PhoneAnimalSelector(
                    selectedCode: 'BEEF',
                    onChanged: (value) => selected = value,
                  ),
                  IosCutSelectionBar(
                    animal: 'BEEF',
                    sectionId: null,
                    sections: const [],
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        final label = find.text('Lamb');
        final text = tester.widget<Text>(label);
        final material = tester.widget<Material>(
          find.ancestor(of: label, matching: find.byType(Material)).first,
        );
        expect(material.color, CutLinkPalette.surface);
        final foreground = text.style!.color!.computeLuminance();
        final background = material.color!.computeLuminance();
        final contrast = foreground > background
            ? (foreground + .05) / (background + .05)
            : (background + .05) / (foreground + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        await tester.tap(label);
        expect(selected, 'LAMB');
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('Red labels retain contrast in both modes', () async {
    for (final dark in [false, true]) {
      await CutLinkAppearance.instance.setMode(
        dark ? ThemeMode.dark : ThemeMode.light,
      );
      final a = CutLinkPalette.actionRed.computeLuminance();
      final b = CutLinkPalette.surface.computeLuminance();
      expect(
        (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
