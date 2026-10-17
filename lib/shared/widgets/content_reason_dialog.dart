import 'package:flutter/material.dart';

Future<String?> requestContentReason(
  BuildContext context, {
  required String title,
  required String description,
  required String submitLabel,
  int maxLength = 1000,
}) => showDialog<String>(
  context: context,
  builder: (_) => _ContentReasonDialog(
    title: title,
    description: description,
    submitLabel: submitLabel,
    maxLength: maxLength,
  ),
);

class _ContentReasonDialog extends StatefulWidget {
  const _ContentReasonDialog({
    required this.title,
    required this.description,
    required this.submitLabel,
    required this.maxLength,
  });
  final String title, description, submitLabel;
  final int maxLength;
  @override
  State<_ContentReasonDialog> createState() => _ContentReasonDialogState();
}

class _ContentReasonDialogState extends State<_ContentReasonDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.description),
              const SizedBox(height: 12),
              TextFormField(
                controller: _controller,
                maxLength: widget.maxLength,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Reason / concern',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 10
                    ? 'Enter at least 10 characters.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: Text(widget.submitLabel),
      ),
    ],
  );
}
