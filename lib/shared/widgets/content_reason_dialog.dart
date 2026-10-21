import 'cutlink_review_theme.dart';
import 'review_response_field.dart';

import 'package:flutter/material.dart';

Future<String?> requestContentReason(
  BuildContext context, {
  required String title,
  required String description,
  required String submitLabel,
  int maxLength = 1000,
  bool productReview = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _ContentReasonDialog(
    title: title,
    description: description,
    submitLabel: submitLabel,
    maxLength: maxLength,
    productReview: productReview,
  ),
);

class _ContentReasonDialog extends StatefulWidget {
  const _ContentReasonDialog({
    required this.title,
    required this.description,
    required this.submitLabel,
    required this.maxLength,
    required this.productReview,
  });
  final String title, description, submitLabel;
  final int maxLength;
  final bool productReview;
  @override
  State<_ContentReasonDialog> createState() => _ContentReasonDialogState();
}

class _ContentReasonDialogState extends State<_ContentReasonDialog> {
  String? _choice;
  static const _choices = <String, String>{
    'corrected': 'The concern has been reviewed and the correction accepted.',
    'followup':
        'CutLink has reviewed the concern and is following up with the supplier.',
    'no_action':
        'CutLink reviewed this report and no product action is required.',
  };
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CutLinkReviewTheme(
    child: AlertDialog(
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
                if (widget.productReview)
                  ReviewResponseField(
                    label: 'Outcome / reason',
                    options: _choices,
                    value: _choice,
                    controller: _controller,
                    onChanged: (v) => setState(() => _choice = v),
                  )
                else
                  TextFormField(
                    controller: _controller,
                    maxLength: widget.maxLength,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Reason / concern',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 10
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
              Navigator.pop(
                context,
                !widget.productReview || _choice == 'other'
                    ? _controller.text.trim()
                    : _choices[_choice],
              );
            }
          },
          child: Text(widget.submitLabel),
        ),
      ],
    ),
  );
}
