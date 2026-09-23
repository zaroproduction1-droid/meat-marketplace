import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../animal_catalogues/product_variant.dart';
import 'cutlink_picker.dart';

class ProductBrandField extends StatefulWidget {
  const ProductBrandField({
    super.key,
    required this.controller,
    this.supplierBusinessId,
    this.animalCode,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String? supplierBusinessId;
  final String? animalCode;
  final bool enabled;
  @override
  State<ProductBrandField> createState() => _ProductBrandFieldState();
}

class _ProductBrandFieldState extends State<ProductBrandField> {
  List<String> _brands = ['Unbranded', 'Mixed brands'];
  bool _custom = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<dynamic> rows = await Supabase.instance.client.rpc(
        'list_supplier_product_brands',
        params: {
          'p_supplier_business_id': widget.supplierBusinessId,
          'p_animal_code': widget.animalCode,
        },
      );
      if (mounted) {
        setState(() {
          _brands = {
            ..._brands,
            ...rows.map((r) => r['name'].toString()),
          }.toList()..sort();
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant ProductBrandField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animalCode != widget.animalCode ||
        oldWidget.supplierBusinessId != widget.supplierBusinessId) {
      _brands = ['Unbranded', 'Mixed brands'];
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.controller.text.trim();
    final choices = {..._brands, if (current.isNotEmpty) current}.toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CutLinkPickerField<String>(
          label: 'Brand',
          value: _custom
              ? '__other__'
              : current.isEmpty
              ? null
              : current,
          enabled: widget.enabled,
          searchHint: 'Search brands',
          options: [
            for (final brand in choices)
              CutLinkPickerOption(value: brand, label: brand),
            const CutLinkPickerOption(
              value: '__other__',
              label: 'Other — enter a brand',
            ),
          ],
          validator: (_) => widget.controller.text.trim().isEmpty
              ? 'Choose a brand or Unbranded.'
              : null,
          onChanged: (value) => setState(() {
            _custom = value == '__other__';
            widget.controller.text = _custom ? '' : value ?? '';
          }),
        ),
        if (_custom)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              controller: widget.controller,
              enabled: widget.enabled,
              decoration: const InputDecoration(
                labelText: 'Your brand name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter the brand name.'
                  : null,
            ),
          ),
        if (_failed)
          TextButton(
            onPressed: _load,
            child: const Text('Brand list unavailable — retry'),
          ),
      ],
    );
  }
}

/// Standard choices with a custom entry, preserving existing supplier wording.
class ProductAttributeField extends StatefulWidget {
  const ProductAttributeField({
    super.key,
    required this.controller,
    required this.label,
    required this.choices,
    this.enabled = true,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final List<String> choices;
  final bool enabled;
  final VoidCallback? onChanged;
  @override
  State<ProductAttributeField> createState() => _ProductAttributeFieldState();
}

class _ProductAttributeFieldState extends State<ProductAttributeField> {
  bool _custom = false;
  @override
  Widget build(BuildContext context) {
    final current = widget.controller.text.trim();
    return Column(
      children: [
        CutLinkPickerField<String>(
          label: widget.label,
          enabled: widget.enabled,
          value: _custom ? '__other__' : current,
          options: [
            const CutLinkPickerOption(value: '', label: 'Not specified'),
            for (final value in {
              ...widget.choices,
              if (current.isNotEmpty) current,
            })
              CutLinkPickerOption(value: value, label: value),
            const CutLinkPickerOption(
              value: '__other__',
              label: 'Other — enter specification',
            ),
          ],
          onChanged: (value) {
            setState(() {
              _custom = value == '__other__';
              widget.controller.text = _custom ? '' : value ?? '';
            });
            widget.onChanged?.call();
          },
        ),
        if (_custom)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              controller: widget.controller,
              enabled: widget.enabled,
              decoration: InputDecoration(
                labelText: widget.label,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => widget.onChanged?.call(),
            ),
          ),
      ],
    );
  }
}

const productPrograms = [
  'Wagyu',
  'Angus',
  'Hereford',
  'Other breed',
  'Grass Fed',
  'Grain Fed',
];
const productLambPrograms = [
  'ANZAC Lamb',
  'Gundagai Lamb GLQ5+',
  'Thomas Foods Signature',
  'Thomas Foods Supreme',
  'Thomas Foods Classic',
  'Grass Fed Lamb',
];
const productMarblingScores = [
  noMarblingClassification,
  'MB1+',
  'MB2+',
  'MB3+',
  'MB4+',
  'MB4-5',
  'MB5+',
  'MB6+',
  'MB6-7',
  'MB7+',
  'MB8+',
  'MB8-9',
  'MB9+',
];

class ProductSizeFields extends StatelessWidget {
  const ProductSizeFields({
    super.key,
    required this.minimum,
    required this.maximum,
    required this.kind,
    required this.unit,
    required this.onKindChanged,
    required this.onUnitChanged,
    this.enabled = true,
  });
  final TextEditingController minimum;
  final TextEditingController maximum;
  final String kind;
  final String unit;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onUnitChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      CutLinkPickerField<String>(
        label: 'Size of each piece',
        value: kind,
        enabled: enabled,
        options: const [
          CutLinkPickerOption(
            value: 'none',
            label: 'Not specified / not applicable',
          ),
          CutLinkPickerOption(value: 'exact', label: 'Exact weight'),
          CutLinkPickerOption(value: 'range', label: 'Weight range'),
          CutLinkPickerOption(value: 'at_least', label: 'Minimum weight (+)'),
          CutLinkPickerOption(value: 'under', label: 'Under a weight'),
          CutLinkPickerOption(value: 'up_to', label: 'Up to a weight'),
        ],
        onChanged: (v) {
          if (v != null) onKindChanged(v);
        },
      ),
      if (kind != 'none')
        CutLinkPickerField<String>(
          label: 'Weight unit',
          value: unit,
          enabled: enabled,
          options: const [
            CutLinkPickerOption(value: 'kg', label: 'kg'),
            CutLinkPickerOption(value: 'g', label: 'g'),
          ],
          onChanged: (v) {
            if (v != null) onUnitChanged(v);
          },
        ),
      if (['exact', 'range', 'at_least'].contains(kind))
        TextFormField(
          controller: minimum,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: kind == 'exact'
                ? 'Piece weight'
                : 'Minimum piece weight',
            suffixText: unit,
            border: const OutlineInputBorder(),
          ),
          validator: (_) => ProductPieceSize(
            kind,
            double.tryParse(minimum.text.trim()),
            double.tryParse(maximum.text.trim()),
            unit,
          ).error,
        ),
      if (['range', 'under', 'up_to'].contains(kind))
        TextFormField(
          controller: maximum,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: kind == 'under'
                ? 'Piece weight below'
                : 'Maximum piece weight',
            suffixText: unit,
            border: const OutlineInputBorder(),
          ),
          validator: (_) => ProductPieceSize(
            kind,
            double.tryParse(minimum.text.trim()),
            double.tryParse(maximum.text.trim()),
            unit,
          ).error,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Piece size', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
          'Weight of each cut or portion inside the carton. Carton weight and price per kg stay separate.',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final field in fields)
                SizedBox(
                  width: constraints.maxWidth < 600
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 14) / 2,
                  child: field,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
