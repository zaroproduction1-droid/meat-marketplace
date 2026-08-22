import 'package:flutter/material.dart';

import 'interactive_beef_cuts_map.dart';

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

  static const all = <CutLinkAnimalOption>[
    CutLinkAnimalOption(
      code: beef,
      name: 'Beef',
      svgAssetPath: 'assets/images/CutLink-Beef-Cuts.svg',
    ),
    CutLinkAnimalOption(code: veal, name: 'Veal'),
    CutLinkAnimalOption(code: lamb, name: 'Lamb'),
    CutLinkAnimalOption(code: mutton, name: 'Mutton'),
    CutLinkAnimalOption(code: goat, name: 'Goat'),
    CutLinkAnimalOption(code: chicken, name: 'Chicken'),
  ];
}

/// Reusable CutLink animal browser shell.
///
/// Sales, Inventory and Butcher Browse can all use this same component.
/// Beef is interactive now. Other animals are already navigable and can be
/// given their own SVG asset later without changing the surrounding pages.
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
    return CutLinkAnimals.all.firstWhere(
      (animal) => animal.code == selectedAnimalCode,
      orElse: () => CutLinkAnimals.all.first,
    );
  }

  int get _selectedIndex {
    final index = CutLinkAnimals.all.indexWhere(
      (animal) => animal.code == selectedAnimalCode,
    );
    return index < 0 ? 0 : index;
  }

  void _moveAnimal(int direction) {
    final nextIndex =
        (_selectedIndex + direction + CutLinkAnimals.all.length) %
        CutLinkAnimals.all.length;
    onAnimalChanged(CutLinkAnimals.all[nextIndex].code);
  }

  @override
  Widget build(BuildContext context) {
    final animal = _selectedAnimal;
    final isBeef = animal.code == CutLinkAnimals.beef;

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
