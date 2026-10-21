import 'cutlink_review_theme.dart';

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'catalogue_product_image.dart';

const productReportReasons = <String, String>{
  'wrong_photo': 'Photo does not match the product',
  'copyright': 'Copyright or permission concern',
  'misleading': 'Misleading product information',
  'inappropriate': 'Inappropriate photo',
  'other': 'Other — describe the concern',
};

class ProductReportDialog extends StatefulWidget {
  const ProductReportDialog({
    super.key,
    required this.product,
    required this.businessId,
  });
  final Map<String, dynamic> product;
  final String businessId;
  @override
  State<ProductReportDialog> createState() => _ProductReportDialogState();
}

class _ProductReportDialogState extends State<ProductReportDialog> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _reference = TextEditingController();
  String _reason = 'wrong_photo';
  String? _error, _requestKey, _sentPayload;
  bool _sending = false;
  @override
  void dispose() {
    _description.dispose();
    _reference.dispose();
    super.dispose();
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _submit() async {
    if (_sending || !_form.currentState!.validate()) {
      return;
    }
    final body = <String, dynamic>{
      'business_id': widget.businessId,
      'product_id': widget.product['id'],
      'reason': _reason,
      'description': _reason == 'other'
          ? _description.text.trim()
          : "${productReportReasons[_reason]!}.",
      'reference_url': _reference.text.trim(),
      'photo_path': widget.product['photo_path'],
    };
    final payload = jsonEncode(body);
    if (_requestKey == null || _sentPayload != payload) {
      _requestKey = _uuid();
      _sentPayload = payload;
    }
    body['request_key'] = _requestKey;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.functions
          .invoke('submit-product-report', body: body)
          .timeout(const Duration(seconds: 30));
      final result = Map<String, dynamic>.from(response.data as Map);
      if (result['ticket_id'] == null) {
        throw StateError('The report could not be confirmed. Please retry.');
      }
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (error) {
      var message =
          'Could not confirm the report. Retry to check and finish it.';
      if (error is FunctionException && error.details is Map) {
        message = (error.details as Map)['message']?.toString() ?? message;
      }
      if (mounted) {
        setState(() {
          _sending = false;
          _error = message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final supplier = p['businesses'] is Map ? p['businesses'] as Map : const {};
    final specification = p['meat_specifications'] is Map
        ? p['meat_specifications'] as Map
        : const {};
    final supplierName =
        (supplier['trading_name'] ?? supplier['legal_name'] ?? 'Supplier')
            .toString();
    final productName =
        (specification['name'] ?? p['product_name'] ?? 'Product').toString();
    final preview = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CatalogueProductImage(product: p, imageHeight: 190),
          const SizedBox(height: 12),
          Text(
            productName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            supplierName,
            style: const TextStyle(
              color: Color(0xFF741C1C),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (p['sku']?.toString().isNotEmpty == true)
            Text(
              'SKU ${p['sku']}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
          const SizedBox(height: 12),
          const Text(
            'This is the product and photo your report will refer to.',
            style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
    final form = Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'What is the concern?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: [
              for (final entry in productReportReasons.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _sending ? null : (v) => setState(() => _reason = v!),
          ),
          const SizedBox(height: 18),
          if (_reason == 'other')
            TextFormField(
              controller: _description,
              enabled: !_sending,
              minLines: 4,
              maxLines: 7,
              maxLength: 4000,
              decoration: InputDecoration(
                labelText: 'Tell us what is wrong',
                alignLabelWithHint: true,
                hintText: _reason == 'copyright'
                    ? 'Explain your connection to the photo and any permission or ownership concern.'
                    : 'Explain what you noticed and what you expected to see.',
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? 'Please give at least 10 characters of detail.'
                  : null,
            ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _reference,
            enabled: !_sending,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Supporting link (optional)',
              hintText: 'https://…',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) {
                return null;
              }
              final uri = Uri.tryParse(text);
              return uri?.scheme == 'https' && uri?.host.isNotEmpty == true
                  ? null
                  : 'Enter an https link or leave this empty.';
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'CutLink Support will review this report. Reporting does not automatically remove a photo or notify the supplier. A private copy of the reported photo may be saved with your support case.',
            style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFF9C2626)),
              ),
            ),
        ],
      ),
    );
    return CutLinkReviewTheme(
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFF5E8E8),
                      child: Icon(
                        Icons.flag_outlined,
                        color: Color(0xFF741C1C),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report a product or photo',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Help us understand the concern',
                            style: TextStyle(color: Color(0xFF666666)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      tooltip: 'Close report',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: LayoutBuilder(
                    builder: (context, box) => box.maxWidth < 650
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              preview,
                              const SizedBox(height: 18),
                              form,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 275, child: preview),
                              const SizedBox(width: 24),
                              Expanded(child: form),
                            ],
                          ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _sending ? null : _submit,
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined, size: 18),
                      label: Text(_sending ? 'Submitting…' : 'Send report'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
