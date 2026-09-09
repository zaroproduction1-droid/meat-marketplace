import 'package:flutter/material.dart';

import '../animal_catalogues/animal_catalogue_registry.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        AnimatedSwitcher(
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
                            style: TextStyle(
                              color: Color(0xFF666666),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
