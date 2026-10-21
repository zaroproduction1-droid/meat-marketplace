import 'package:flutter/material.dart';

/// Shared cut choices describe the cut; this field describes one supplier's item.
class SupplierSpecificationField extends StatelessWidget {
  const SupplierSpecificationField({
    super.key,
    required this.controller,
    required this.animalCode,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String? animalCode;
  final bool enabled;

  static bool usesGeneralSubcuts(String? code) =>
      const {'CHICKEN', 'LAMB', 'MUTTON', 'GOAT', 'VEAL'}.contains(code);

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    minLines: 2,
    maxLines: 5,
    maxLength: 2000,
    decoration: InputDecoration(
      labelText: 'Your specification (optional)',
      helperText:
          'Describe this item for buyers. This does not create another sub-cut.',
      helperMaxLines: 3,
      hintText: animalCode == 'CHICKEN'
          ? 'For example: skinless, tender off, sliced 10 mm, fresh.'
          : 'For example: boneless, cap off, 8 ribs, rolled and netted, chilled.',
      alignLabelWithHint: true,
    ),
  );
}

class ChickenProductAttributes extends StatelessWidget {
  const ChickenProductAttributes({
    super.key,
    required this.values,
    required this.onChanged,
    this.enabled = true,
  });
  final Map<String, String> values;
  final void Function(String key, String value) onChanged;
  final bool enabled;
  static const choices = <String, List<String>>{
    'chicken_skin': ['not_applicable', 'skin_on', 'skin_off'],
    'chicken_bone': ['not_applicable', 'bone_in', 'boneless'],
    'chicken_production_type': [
      'conventional',
      'free_range',
      'organic',
      'other',
    ],
    'chicken_preparation': [
      'not_applicable',
      'whole',
      'fillet',
      'diced',
      'strips',
      'sliced',
      'minced',
      'butterflied',
      'schnitzel',
      'portion_controlled',
      'other',
    ],
  };
  static String value(String key, dynamic raw) =>
      choices[key]!.contains(raw) ? raw as String : choices[key]!.first;
  static String label(String raw) =>
      raw == 'not_applicable' ? 'Not specified' : raw.replaceAll('_', ' ');
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('Optional chicken details'),
    children: [
      for (final entry in choices.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            key: ValueKey('${entry.key}-${values[entry.key]}'),
            initialValue: value(entry.key, values[entry.key]),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: {
                'chicken_skin': 'Skin',
                'chicken_bone': 'Bone',
                'chicken_production_type': 'Production type',
                'chicken_preparation': 'Preparation',
              }[entry.key],
            ),
            items: entry.value
                .map((v) => DropdownMenuItem(value: v, child: Text(label(v))))
                .toList(),
            onChanged: enabled
                ? (v) {
                    if (v != null) {
                      onChanged(entry.key, v);
                    }
                  }
                : null,
          ),
        ),
    ],
  );
}
