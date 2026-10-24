import 'package:flutter/material.dart';

import '../animal_catalogues/supplier_variant_options.dart';
import 'cutlink_picker.dart';

/// Shared cut choices describe the cut; this field describes one supplier's item.
class SupplierSpecificationField extends StatelessWidget {
  const SupplierSpecificationField({
    super.key,
    required this.values,
    required this.onChanged,
    required this.animalCode,
    required this.cutRules,
    this.previousDetails = '',
    this.enabled = true,
  });
  final Map<String, String> values;
  final void Function(String field, String value) onChanged;
  final String previousDetails;
  final String? animalCode;
  final Map<String, dynamic> cutRules;
  final bool enabled;

  static bool usesGeneralSubcuts(String? code) =>
      const {'CHICKEN', 'LAMB', 'MUTTON', 'GOAT', 'VEAL'}.contains(code);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose the specifications for this sub-cut. Butchers use the same options to filter products.',
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final field in SupplierVariantOptions.fieldsForCut(
              cutRules,
              values: values,
            ))
              SizedBox(
                width: constraints.maxWidth < 600
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 14) / 2,
                child: CutLinkPickerField<String>(
                  label: SupplierVariantOptions.labels[field]!,
                  value: values[field] ?? '',
                  enabled: enabled,
                  options: [
                    const CutLinkPickerOption(
                      value: '',
                      label: 'Not specified',
                    ),
                    for (final option in SupplierVariantOptions.cutOptions(
                      cutRules,
                      field,
                    ).entries)
                      CutLinkPickerOption(
                        value: option.key,
                        label: option.value,
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(field, value);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
      if (cutRules.isEmpty)
        const Text(
          'Select a sub-cut to see its specifications. If no options load, refresh the catalogue before saving.',
        ),
      if (previousDetails.trim().isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Previous written details'),
          subtitle: const Text(
            'Kept for reference. Select the matching dropdown options above.',
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(previousDetails),
            ),
          ],
        ),
    ],
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
