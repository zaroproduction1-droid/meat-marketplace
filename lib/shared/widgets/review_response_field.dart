import 'package:flutter/material.dart';

class ReviewResponseField extends StatelessWidget {
  const ReviewResponseField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
  });
  final String label;
  final Map<String, String> options;
  final String? value;
  final TextEditingController controller;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final entry in options.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text(
                entry.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const DropdownMenuItem(
            value: 'other',
            child: Text('Other — write a response'),
          ),
        ],
        onChanged: enabled ? onChanged : null,
        validator: (v) => v == null ? 'Choose an option.' : null,
      ),
      if (value == 'other')
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: 'Your response',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v?.trim().length ?? 0) < 10
                ? 'Enter at least 10 characters.'
                : null,
          ),
        ),
    ],
  );
}
