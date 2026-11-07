import '../theme/cutlink_appearance.dart';

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
    AppearanceScope.watch(context);
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
      color: CutLinkPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: CutLinkPalette.color(0xFFE3E5E8)),
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
  bool initialSubcuts = false,
  Listenable? catalogueChanges,
  bool Function()? isLoading,
  String? Function()? error,
}) {
  var subcuts = initialSubcuts;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, update) => ListenableBuilder(
        listenable: catalogueChanges ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) {
          final cs = Theme.of(context).colorScheme;
          final chosen = sections()
              .where((s) => s['id']?.toString() == sectionId())
              .firstOrNull;
          void back() => update(() => subcuts = false);
          void chooseCut(Map<String, dynamic> section) {
            onSection(section);
            update(() => subcuts = true);
          }

          void showProducts() => Navigator.pop(sheetContext);
          return PopScope(
            canPop: !subcuts,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) back();
            },
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .84,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: subcuts ? 'Back to main cuts' : 'Close',
                          onPressed: subcuts ? back : showProducts,
                          icon: Icon(
                            subcuts ? Icons.arrow_back_ios_new : Icons.close,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subcuts
                                    ? (chosen?['name']?.toString() ??
                                          'Sub-cuts')
                                    : 'Browse cuts',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                subcuts
                                    ? '${animal()} · Choose a sub-cut'
                                    : 'Choose an animal, then a main cut',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (subcuts)
                          IconButton(
                            tooltip: 'Close catalogue',
                            onPressed: showProducts,
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(.08, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: subcuts
                          ? ListView(
                              key: ValueKey('subcuts-${sectionId()}'),
                              padding: const EdgeInsets.all(16),
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    if (chosen != null) onSection(chosen);
                                    showProducts();
                                  },
                                  icon: const Icon(Icons.grid_view),
                                  label: const Text(
                                    'View all products in this cut',
                                  ),
                                ),
                                if (isLoading?.call() == true)
                                  const LinearProgressIndicator(),
                                if (error?.call() != null)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(error!.call()!),
                                  ),
                                if (specifications().isEmpty &&
                                    isLoading?.call() != true &&
                                    error?.call() == null)
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'No sub-cuts available. View all products in this cut.',
                                    ),
                                  ),
                                for (final spec
                                    in isLoading?.call() == true
                                        ? <Map<String, dynamic>>[]
                                        : specifications())
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Material(
                                      color: cs.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(14),
                                      clipBehavior: Clip.antiAlias,
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 5,
                                            ),
                                        title: Text(
                                          spec['name']?.toString() ?? 'Sub-cut',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        trailing: Icon(
                                          specificationId() ==
                                                  spec['id']?.toString()
                                              ? Icons.check_circle
                                              : Icons.chevron_right,
                                          color: cs.primary,
                                        ),
                                        onTap: () {
                                          onSpecification(spec);
                                          showProducts();
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : ListView(
                              key: const ValueKey('main-cuts'),
                              padding: const EdgeInsets.all(16),
                              children: [
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
                                            animal().toUpperCase() ==
                                            name.toUpperCase(),
                                        onSelected: (_) {
                                          onAnimal(name.toUpperCase());
                                          update(() {});
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Main cuts',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                for (final section in sections())
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Material(
                                      color: cs.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(14),
                                      clipBehavior: Clip.antiAlias,
                                      child: ListTile(
                                        title: Text(
                                          section['name']?.toString() ?? 'Cut',
                                        ),
                                        subtitle: const Text(
                                          'Choose sub-cut',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                        onTap: () => chooseCut(section),
                                      ),
                                    ),
                                  ),
                                TextButton(
                                  onPressed: () {
                                    onAllCuts();
                                    showProducts();
                                  },
                                  child: const Text('All cuts'),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (!subcuts)
                    SafeArea(
                      top: false,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          onGuide();
                        },
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Explore the animal diagram'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
