import 'package:flutter/material.dart';

class IosCutSelectionBar extends StatelessWidget {
  const IosCutSelectionBar({
    super.key,
    required this.animal,
    required this.sectionId,
    required this.sections,
    required this.onTap,
  });
  final String animal;
  final String? sectionId;
  final List<Map<String, dynamic>> sections;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    var cut = 'All cuts';
    for (final section in sections) {
      if (section['id']?.toString() == sectionId) {
        cut = section['name']?.toString() ?? cut;
      }
    }
    final name = animal.isEmpty
        ? ''
        : '${animal[0]}${animal.substring(1).toLowerCase()}';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3E5E8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(
          '$name · $cut',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.expand_more),
        onTap: onTap,
      ),
    );
  }
}

/// Uses each screen's existing catalogue and selection callbacks.
Future<void> showIosCutBrowser({
  required BuildContext context,
  required String Function() animal,
  required String? Function() sectionId,
  required String? Function() specificationId,
  required List<Map<String, dynamic>> Function() sections,
  required List<Map<String, dynamic>> Function() specifications,
  required ValueChanged<String> onAnimal,
  required ValueChanged<Map<String, dynamic>> onSection,
  required ValueChanged<Map<String, dynamic>> onSpecification,
  required VoidCallback onAllCuts,
  required VoidCallback onGuide,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
  ),
  builder: (sheetContext) => StatefulBuilder(
    builder: (context, update) {
      void choose(VoidCallback action) {
        action();
        update(() {});
      }

      Widget heading(String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      );
      Widget option(String title, bool selected, VoidCallback action) =>
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            selected: selected,
            selectedTileColor: const Color(0xFFF7ECEF),
            leading: selected ? const Icon(Icons.check_circle, size: 20) : null,
            title: Text(title),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => choose(action),
          );
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
                const Expanded(
                  child: Text(
                    'Browse cuts',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => choose(onAllCuts),
                  child: const Text('Reset'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  heading('Animal'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final name in const [
                        'Beef',
                        'Veal',
                        'Lamb',
                        'Mutton',
                        'Goat',
                        'Chicken',
                      ])
                        ChoiceChip(
                          label: Text(name),
                          selected:
                              animal().toUpperCase() == name.toUpperCase(),
                          onSelected: (_) =>
                              choose(() => onAnimal(name.toUpperCase())),
                        ),
                    ],
                  ),
                  heading('Main cut'),
                  option('All cuts', sectionId() == null, onAllCuts),
                  for (final section in sections())
                    option(
                      section['name']?.toString() ?? 'Cut',
                      sectionId() == section['id']?.toString(),
                      () => onSection(section),
                    ),
                  if (sectionId() != null) ...[
                    heading('Sub-cut'),
                    for (final specification in specifications())
                      option(
                        specification['name']?.toString() ?? 'Sub-cut',
                        specificationId() == specification['id']?.toString(),
                        () => onSpecification(specification),
                      ),
                    if (specifications().isEmpty)
                      const Text('No sub-cuts available for this cut.'),
                  ],
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onGuide();
                    },
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('View cut guide'),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Show products'),
              ),
            ),
          ],
        ),
      );
    },
  ),
);
