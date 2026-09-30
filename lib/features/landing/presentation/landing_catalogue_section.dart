import 'package:flutter/material.dart';
import 'public_page_palette.dart';
import '../../../shared/animal_catalogues/animal_catalogue_registry.dart';
import '../../../shared/widgets/interactive_beef_cuts_map.dart';
import '../../../shared/widgets/interactive_chicken_cuts_map.dart';
import '../../../shared/widgets/interactive_goat_cuts_map.dart';
import '../../../shared/widgets/interactive_lamb_cuts_map.dart';
import '../../../shared/widgets/interactive_mutton_cuts_map.dart';
import '../../../shared/widgets/interactive_veal_cuts_map.dart';

class LandingCatalogueSection extends StatefulWidget {
  const LandingCatalogueSection({super.key, required this.onBrowse});
  final VoidCallback onBrowse;
  @override
  State<LandingCatalogueSection> createState() =>
      _LandingCatalogueSectionState();
}

class _LandingCatalogueSectionState extends State<LandingCatalogueSection> {
  String _animal = 'BEEF';
  String? _cut;
  static const _animals = ['BEEF', 'VEAL', 'LAMB', 'MUTTON', 'GOAT', 'CHICKEN'];
  static const _names = ['Beef', 'Veal', 'Lamb', 'Mutton', 'Goat', 'Chicken'];
  static const _ink = PublicPagePalette.background,
      _surface = PublicPagePalette.surface,
      _muted = PublicPagePalette.muted;
  final _transform = TransformationController();
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _change(String animal) => setState(() {
    _animal = animal;
    _cut = null;
    _transform.value = Matrix4.identity();
  });
  Widget _diagram(double maxWidth, {VoidCallback? onChange}) =>
      switch (_animal) {
        'VEAL' => InteractiveVealCutsMap(
          assetPath: 'assets/images/CutLink-Veal-Public.svg',
          maxWidth: maxWidth,
          selectedCut: _cut,
          onCutSelected: (cut) {
            setState(() => _cut = cut);
            onChange?.call();
          },
        ),
        'LAMB' => InteractiveLambCutsMap(
          assetPath: 'assets/images/CutLink-Lamb-Public.svg',
          maxWidth: maxWidth,
          selectedCut: _cut,
          onCutSelected: (cut) {
            setState(() => _cut = cut);
            onChange?.call();
          },
        ),
        'MUTTON' => InteractiveMuttonCutsMap(
          assetPath: 'assets/images/CutLink-Mutton-Public.svg',
          maxWidth: maxWidth,
          selectedCut: _cut,
          onCutSelected: (cut) {
            setState(() => _cut = cut);
            onChange?.call();
          },
        ),
        'GOAT' => InteractiveGoatCutsMap(
          assetPath: 'assets/images/CutLink-Goat-Public.svg',
          maxWidth: maxWidth,
          selectedCut: _cut,
          onCutSelected: (cut) {
            setState(() => _cut = cut);
            onChange?.call();
          },
        ),
        'CHICKEN' => InteractiveChickenCutsMap(
          assetPath: 'assets/images/CutLink-Chicken-Public.svg',
          maxWidth: maxWidth,
          selectedCut: _cut,
          onCutSelected: (cut) {
            setState(() => _cut = cut);
            onChange?.call();
          },
        ),
        _ => InteractiveBeefCutsMap(
          assetPath: 'assets/images/CutLink-Beef-Public.svg',
          maxWidth: maxWidth,
          selectedCut: _cut,
          onCutSelected: (cut) {
            setState(() => _cut = cut);
            onChange?.call();
          },
        ),
      };
  Widget _tabs() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < _animals.length; i++)
        ChoiceChip(
          label: Text(_names[i]),
          selected: _animal == _animals[i],
          showCheckmark: false,
          backgroundColor: _surface,
          selectedColor: PublicPagePalette.primary,
          side: BorderSide(
            color: _animal == _animals[i]
                ? PublicPagePalette.accent
                : PublicPagePalette.border,
          ),
          labelStyle: TextStyle(
            color: _animal == _animals[i]
                ? Colors.white
                : PublicPagePalette.text,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onSelected: (_) => _change(_animals[i]),
        ),
    ],
  );
  Widget _map(double height) => Container(
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3F5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LayoutBuilder(
        builder: (context, box) => Theme(
          data: ThemeData.light(),
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 3,
            constrained: true,
            child: SizedBox(
              width: box.maxWidth,
              height: box.maxHeight,
              child: Center(child: _diagram(box.maxWidth - 12)),
            ),
          ),
        ),
      ),
    ),
  );
  String get _label => _cut == null
      ? 'Choose a cut on the diagram'
      : AnimalCatalogueRegistry.forCode(_animal)?.regionLabel(_cut!) ?? _cut!;
  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'FROM CUT TO ORDER',
        style: TextStyle(
          color: PublicPagePalette.accent,
          fontSize: 11,
          letterSpacing: 1.7,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 18),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Text(
          _label,
          key: ValueKey(_label),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: PublicPagePalette.text,
          ),
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'The same visual catalogue is used inside CutLink. Start with the animal and cut, then narrow down exactly what you need.',
        style: TextStyle(color: _muted, height: 1.6),
      ),
      const SizedBox(height: 22),
      for (final step in [
        ('01', 'Choose the cut', 'Select the main section, then the sub-cut.'),
        (
          '02',
          'Check the details',
          'Refine size, grade and preparation where relevant.',
        ),
        (
          '03',
          'Compare and order',
          'See supplier products and available prices.',
        ),
      ]) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.$1,
              style: const TextStyle(
                color: PublicPagePalette.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.$2,
                    style: const TextStyle(
                      color: PublicPagePalette.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    step.$3,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
      FilledButton.icon(
        onPressed: widget.onBrowse,
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: const Text('Start buying with CutLink'),
        style: FilledButton.styleFrom(
          backgroundColor: PublicPagePalette.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(18),
        ),
      ),
    ],
  );
  Future<void> _expand() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => Dialog.fullscreen(
          backgroundColor: _ink,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_animal cut catalogue',
                          style: const TextStyle(
                            color: PublicPagePalette.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close catalogue',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close,
                          color: PublicPagePalette.text,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Theme(
                    data: ThemeData.light(),
                    child: Container(
                      color: const Color(0xFFF1F3F5),
                      child: LayoutBuilder(
                        builder: (context, box) => InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: SizedBox(
                            width: box.maxWidth,
                            height: box.maxHeight,
                            child: Center(
                              child: _diagram(
                                box.maxWidth,
                                onChange: () => refresh(() {}),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '$_label • Pinch or use your trackpad to zoom.',
                    style: const TextStyle(color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final desktop = box.maxWidth >= 900;
      final mapHeight = desktop
          ? (MediaQuery.sizeOf(context).height - 240).clamp(420.0, 650.0)
          : (box.maxWidth * .75).clamp(260.0, 510.0);
      final header = Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 14,
        children: [
          _tabs(),
          OutlinedButton.icon(
            onPressed: _expand,
            icon: const Icon(Icons.open_in_full, size: 16),
            label: const Text('Full screen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: PublicPagePalette.primary,
              side: const BorderSide(color: PublicPagePalette.border),
            ),
          ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 18),
          if (desktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 8, child: _map(mapHeight)),
                const SizedBox(width: 30),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _details(),
                  ),
                ),
              ],
            )
          else ...[
            _map(mapHeight),
            const SizedBox(height: 16),
            Text(
              _label,
              style: const TextStyle(
                color: PublicPagePalette.text,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a cut, then refine its specification and compare suppliers inside CutLink.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Interactive preview • Six animal catalogues',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: () => _transform.value = Matrix4.identity(),
                icon: const Icon(Icons.center_focus_strong, size: 16),
                label: const Text('Reset view'),
                style: TextButton.styleFrom(
                  foregroundColor: PublicPagePalette.accent,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
