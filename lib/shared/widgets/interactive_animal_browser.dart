import 'package:flutter/material.dart';

import '../animal_catalogues/animal_catalogue_registry.dart';
import 'phone_layout.dart';

import 'interactive_beef_cuts_map.dart';
import 'interactive_chicken_cuts_map.dart';
import 'interactive_goat_cuts_map.dart';
import 'interactive_lamb_cuts_map.dart';
import 'interactive_mutton_cuts_map.dart';
import 'interactive_veal_cuts_map.dart';

class CutLinkAnimalOption {
  const CutLinkAnimalOption({
    required this.code,
    required this.name,
    this.svgAssetPath,
  });

  final String code;
  final String name;
  final String? svgAssetPath;
}

abstract final class CutLinkAnimals {
  static const beef = 'BEEF';
  static const veal = 'VEAL';
  static const lamb = 'LAMB';
  static const mutton = 'MUTTON';
  static const goat = 'GOAT';
  static const chicken = 'CHICKEN';

  static List<CutLinkAnimalOption> get all {
    CutLinkAnimalOption supported(String code, String fallbackName) {
      final catalogue = AnimalCatalogueRegistry.forCode(code);
      return CutLinkAnimalOption(
        code: code,
        name: catalogue?.animalName ?? fallbackName,
        svgAssetPath: catalogue?.svgAssetPath,
      );
    }

    return <CutLinkAnimalOption>[
      supported(beef, 'Beef'),
      supported(veal, 'Veal'),
      supported(lamb, 'Lamb'),
      supported(mutton, 'Mutton'),
      supported(goat, 'Goat'),
      supported(chicken, 'Chicken'),
    ];
  }

  static String? defaultRegionKey(String animalCode) =>
      AnimalCatalogueRegistry.forCode(animalCode)?.defaultRegionKey;
}

/// Reusable CutLink animal browser shell.
///
/// Sales, Inventory and Butcher Browse can all use this same component.
/// Beef, Veal, Goat and Chicken are interactive. Other animals are already navigable
/// and can be given their own SVG asset later without changing surrounding pages.
class InteractiveAnimalBrowser extends StatelessWidget {
  const InteractiveAnimalBrowser({
    super.key,
    required this.selectedAnimalCode,
    required this.onAnimalChanged,
    required this.onRegionSelected,
    this.selectedRegionKey,
    this.maxWidth = 760,
  });

  final String selectedAnimalCode;
  final ValueChanged<String> onAnimalChanged;
  final ValueChanged<String> onRegionSelected;
  final String? selectedRegionKey;
  final double maxWidth;

  CutLinkAnimalOption get _selectedAnimal {
    final animals = CutLinkAnimals.all;
    return animals.firstWhere(
      (animal) => animal.code == selectedAnimalCode,
      orElse: () => animals.first,
    );
  }

  int get _selectedIndex {
    final animals = CutLinkAnimals.all;
    final index = animals.indexWhere(
      (animal) => animal.code == selectedAnimalCode,
    );
    return index < 0 ? 0 : index;
  }

  void _moveAnimal(int direction) {
    final animals = CutLinkAnimals.all;
    final nextIndex =
        (_selectedIndex + direction + animals.length) % animals.length;
    onAnimalChanged(animals[nextIndex].code);
  }

  @override
  Widget build(BuildContext context) {
    final animal = _selectedAnimal;
    final isBeef = animal.code == CutLinkAnimals.beef;
    final isGoat = animal.code == CutLinkAnimals.goat;
    final isLamb = animal.code == CutLinkAnimals.lamb;
    final isMutton = animal.code == CutLinkAnimals.mutton;
    final isVeal = animal.code == CutLinkAnimals.veal;
    final isChicken = animal.code == CutLinkAnimals.chicken;

    final diagram = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: isBeef
          ? InteractiveBeefCutsMap(
              key: const ValueKey('BEEF_MAP'),
              selectedCut: selectedRegionKey,
              onCutSelected: onRegionSelected,
              maxWidth: maxWidth,
            )
          : isGoat
          ? InteractiveGoatCutsMap(
              key: const ValueKey('GOAT_MAP'),
              selectedCut: selectedRegionKey,
              onCutSelected: onRegionSelected,
              maxWidth: maxWidth,
            )
          : isLamb
          ? InteractiveLambCutsMap(
              key: const ValueKey('LAMB_MAP'),
              selectedCut: selectedRegionKey,
              onCutSelected: onRegionSelected,
              maxWidth: maxWidth,
            )
          : isMutton
          ? InteractiveMuttonCutsMap(
              key: const ValueKey('MUTTON_MAP'),
              selectedCut: selectedRegionKey,
              onCutSelected: onRegionSelected,
              maxWidth: maxWidth,
            )
          : isVeal
          ? InteractiveVealCutsMap(
              key: const ValueKey('VEAL_MAP'),
              selectedCut: selectedRegionKey,
              onCutSelected: onRegionSelected,
              maxWidth: maxWidth,
            )
          : isChicken
          ? InteractiveChickenCutsMap(
              key: const ValueKey('CHICKEN_MAP'),
              selectedCut: selectedRegionKey,
              onCutSelected: onRegionSelected,
              maxWidth: maxWidth,
            )
          : Container(
              key: ValueKey(animal.code),
              constraints: const BoxConstraints(minHeight: 360),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E0DD)),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pets_outlined,
                        size: 58,
                        color: Color(0xFF741C1C),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${animal.name} cut map',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The catalogue is ready. Its interactive SVG will '
                        'plug into this same browser when added.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF666666), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPhoneLayout(context))
          PhoneAnimalSelector(
            selectedCode: selectedAnimalCode,
            onChanged: onAnimalChanged,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in CutLinkAnimals.all) ...[
                  _AnimalTab(
                    label: option.name,
                    selected: option.code == selectedAnimalCode,
                    onTap: () => onAnimalChanged(option.code),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous animal',
              onPressed: () => _moveAnimal(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    animal.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedIndex + 1} of ${CutLinkAnimals.all.length}',
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Next animal',
              onPressed: () => _moveAnimal(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isPhoneLayout(context))
          _PhoneCatalogueZoom(key: ValueKey(animal.code), child: diagram)
        else
          diagram,
      ],
    );
  }
}

class _AnimalTab extends StatelessWidget {
  const _AnimalTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _darkRed = Color(0xFF741C1C);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _darkRed : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: EdgeInsets.symmetric(
            horizontal: isPhoneLayout(context) ? 6 : 18,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? _darkRed : const Color(0xFFD8D8D4),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF333333),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal-width choices shared by the phone catalogue and Browse controls.
class PhoneAnimalSelector extends StatelessWidget {
  const PhoneAnimalSelector({
    super.key,
    required this.selectedCode,
    required this.onChanged,
  });

  final String selectedCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth < 250 ? 2 : 3;
        final width = (box.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final animal in CutLinkAnimals.all)
              SizedBox(
                width: width,
                child: Semantics(
                  selected: animal.code == selectedCode,
                  child: _AnimalTab(
                    label: animal.name,
                    selected: animal.code == selectedCode,
                    onTap: () => onChanged(animal.code),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Transform the entire map, including its hit targets, as a single surface.
/// Animal choices and zoom buttons remain outside the transformed surface.
class _PhoneCatalogueZoom extends StatefulWidget {
  const _PhoneCatalogueZoom({super.key, required this.child});

  final Widget child;

  @override
  State<_PhoneCatalogueZoom> createState() => _PhoneCatalogueZoomState();
}

class _PhoneCatalogueZoomState extends State<_PhoneCatalogueZoom> {
  final _transform = TransformationController();

  void _zoom(double factor, Size viewport) {
    final current = _transform.value.getMaxScaleOnAxis();
    final scale = (current * factor).clamp(1.0, 5.0).toDouble();
    if (scale == 1) {
      _reset();
      return;
    }
    final centre = viewport.center(Offset.zero);
    final scene = _transform.toScene(centre);
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, centre.dx - scene.dx * scale)
      ..setEntry(1, 3, centre.dy - scene.dy * scale);
  }

  void _reset() {
    _transform.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final viewport = Size(box.maxWidth, box.maxWidth * 0.85);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: viewport.height,
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 5,
                  boundaryMargin: const EdgeInsets.all(40),
                  child: SizedBox(
                    width: viewport.width,
                    height: viewport.height,
                    child: Center(child: widget.child),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Zoom out',
                  onPressed: () => _zoom(1 / 1.4, viewport),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.center_focus_strong, size: 18),
                  label: const Text('Reset'),
                ),
                IconButton(
                  tooltip: 'Zoom in',
                  onPressed: () => _zoom(1.4, viewport),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const Text(
              'Pinch to zoom • Drag to move • Tap a cut to select',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
          ],
        );
      },
    );
  }
}
