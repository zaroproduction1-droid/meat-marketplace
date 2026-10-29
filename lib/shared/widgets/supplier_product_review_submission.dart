import '../theme/cutlink_appearance.dart';
import 'cutlink_review_theme.dart';
import 'review_response_field.dart';

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String supplierCorrectionFieldLabel(Object? field) {
  final value = field?.toString() ?? '';
  const labels = {
    'supplier_attributes': 'Product specification options',
    'photo_path': 'Photo',
    'hide_catalogue_photo': 'Photo',
    'meat_animal_id': 'Animal',
    'meat_section_id': 'Main cut',
    'meat_specification_id': 'Cut / specification',
    'meat_grade_id': 'Grade',
    'sku': 'SKU',
    'active': 'Listing status',
  };
  if (labels.containsKey(value)) {
    return labels[value]!;
  }
  return value
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String supplierCorrectionStatus(Map review) {
  if (review['workflow_state'] == 'removed') {
    return 'Product taken down';
  }
  if (review['workflow_state'] == 'resolved') {
    return 'Case closed';
  }
  final changed = (review['change_revision'] as num? ?? 0).toInt();
  final submitted = (review['submitted_revision'] as num? ?? 0).toInt();
  if (changed > submitted) {
    return 'Changes saved — confirm when ready';
  }
  if (review['last_submitted_at'] != null) {
    return 'Ready for CutLink review';
  }
  return 'Waiting for supplier corrections';
}

Future<bool> submitSupplierProductChanges(
  BuildContext context, {
  required String productId,
  bool quietIfNone = false,
}) async {
  final raw = await Supabase.instance.client.rpc(
    'supplier_product_review_status',
    params: {'p_product_id': productId},
  );
  if (!context.mounted) {
    return false;
  }
  if (raw is! Map || raw['has_unsubmitted_changes'] != true) {
    if (!quietIfNone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Save a new product correction before submitting it for review.',
          ),
        ),
      );
    }
    return false;
  }
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _SubmitProductChangesDialog(status: Map<String, dynamic>.from(raw)),
      ) ??
      false;
}

class _SubmitProductChangesDialog extends StatefulWidget {
  const _SubmitProductChangesDialog({required this.status});
  final Map<String, dynamic> status;
  @override
  State<_SubmitProductChangesDialog> createState() =>
      _SubmitProductChangesDialogState();
}

class _SubmitProductChangesDialogState
    extends State<_SubmitProductChangesDialog> {
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _correction;
  static const _choices = <String, String>{
    'photo': 'I replaced the product photo.',
    'details': 'I corrected the product information.',
    'prices': 'I corrected the product pricing.',
    'both': 'I corrected the photo and product information.',
  };
  bool _saving = false;
  String? _error, _requestKey, _payload;
  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    final params = <String, dynamic>{
      'p_ticket_id': widget.status['ticket_id'],
      'p_note': _correction == 'other'
          ? _note.text.trim()
          : _choices[_correction],
      'p_product_version': widget.status['product_version'],
    };
    final payload = jsonEncode(params);
    if (_requestKey == null || payload != _payload) {
      _requestKey = _uuid();
      _payload = payload;
    }
    params['p_request_key'] = _requestKey;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'submit_supplier_product_review',
        params: params,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.code == 'P0001'
              ? e.message
              : 'The confirmation could not be saved. Retry with the same details.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'The confirmation could not be saved. Retry with the same details.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    final fields = (widget.status['changed_fields'] as List? ?? [])
        .map(supplierCorrectionFieldLabel)
        .toSet()
        .join(', ');
    return CutLinkReviewTheme(
      child: AlertDialog(
        title: const Text('Submit saved changes for review'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Your product changes are saved. Confirm what you fixed so CutLink knows it is ready to review.',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Saved changes: $fields',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  ReviewResponseField(
                    label: 'What did you fix?',
                    options: _choices,
                    value: _correction,
                    controller: _note,
                    enabled: !_saving,
                    onChanged: (v) => setState(() => _correction = v),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Only saved changes are submitted. This does not remove any restriction or automatically approve the product. CutLink must review it.',
                    style: TextStyle(
                      fontSize: 12,
                      color: CutLinkPalette.color(0xFF666666),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Submit later'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(
              _saving ? 'Submitting…' : 'Confirm & submit for review',
            ),
          ),
        ],
      ),
    );
  }
}
