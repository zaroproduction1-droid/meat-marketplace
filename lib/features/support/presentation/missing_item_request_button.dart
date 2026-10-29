import '../../../shared/theme/cutlink_appearance.dart';
import '../../../shared/widgets/ios_density.dart';
import '../../../shared/widgets/cutlink_review_theme.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_center_page.dart';

typedef MissingItemSubmit =
    Future<String> Function(Map<String, dynamic> params);

/// Sends catalogue requests through the existing business-scoped support chat.
class MissingItemRequestButton extends StatelessWidget {
  const MissingItemRequestButton({
    super.key,
    required this.businessId,
    required this.pageName,
    this.catalogueContext = const {},
  });

  final String? businessId;
  final String pageName;
  final Map<String, String?> catalogueContext;

  Future<void> _open(BuildContext context) async {
    final id = businessId;
    if (id == null) {
      return;
    }
    final ticketId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MissingItemRequestDialog(
        businessId: id,
        pageName: pageName,
        catalogueContext: catalogueContext,
      ),
    );
    if (!context.mounted || ticketId == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportCenterPage(
          businessId: id,
          adminMode: false,
          initialTicketId: ticketId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    final enabled = businessId != null;
    if (MediaQuery.sizeOf(context).width < 900) {
      return IconButton(
        tooltip: 'Request a missing item',
        onPressed: enabled ? () => _open(context) : null,
        icon: const Icon(Icons.playlist_add_rounded, color: Color(0xFF741C1C)),
      );
    }
    return IosPadding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: OutlinedButton.icon(
        onPressed: enabled ? () => _open(context) : null,
        icon: const Icon(Icons.playlist_add_rounded, size: 19),
        label: const Text('Request missing item'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF741C1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class MissingItemRequestDialog extends StatefulWidget {
  const MissingItemRequestDialog({
    super.key,
    required this.businessId,
    required this.pageName,
    this.catalogueContext = const {},
    this.submit,
  });

  final String businessId;
  final String pageName;
  final Map<String, String?> catalogueContext;
  final MissingItemSubmit? submit;

  @override
  State<MissingItemRequestDialog> createState() =>
      _MissingItemRequestDialogState();
}

class _MissingItemRequestDialogState extends State<MissingItemRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _details = TextEditingController();
  String _kind = 'Cut / section';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final params = <String, dynamic>{
      'p_business_id': widget.businessId,
      'p_category': 'products',
      'p_priority': 'normal',
      'p_subject': 'Missing item: ${_name.text.trim()}',
      'p_message': [
        'MISSING CATALOGUE ITEM REQUEST',
        'Page: ${widget.pageName}',
        'Request type: $_kind',
        'Requested item: ${_name.text.trim()}',
        for (final entry in widget.catalogueContext.entries)
          if (entry.value?.trim().isNotEmpty == true)
            '${entry.key}: ${entry.value}',
        if (_details.text.trim().isNotEmpty) 'Details: ${_details.text.trim()}',
        'Please review this catalogue request. It does not change stock or place an order.',
      ].join('\n'),
    };
    try {
      final submit = widget.submit;
      String ticketId;
      if (submit != null) {
        ticketId = await submit(params);
      } else {
        final response = await Supabase.instance.client.rpc(
          'create_support_ticket',
          params: params,
        );
        final row = response is List && response.isNotEmpty
            ? response.first
            : response;
        if (row is! Map || row['id'] == null) {
          throw StateError('The request response could not be confirmed.');
        }
        ticketId = row['id'].toString();
      }
      if (mounted) {
        Navigator.of(context).pop(ticketId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error =
              'We could not confirm submission. Your details are kept here. '
              'Check Support for this request before sending again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return CutLinkReviewTheme(
      child: PopScope(
        canPop: !_sending,
        child: Dialog(
          backgroundColor: CutLinkPalette.surface,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.playlist_add_rounded,
                      color: Color(0xFF741C1C),
                      size: 36,
                    ),
                    const IosGap(height: 12),
                    Text(
                      'Something missing?',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const IosGap(height: 8),
                    const Text(
                      'Tell CutLink what you need. We’ll follow up in your support chat.',
                      textAlign: TextAlign.center,
                    ),
                    const IosGap(height: 20),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _kind,
                      decoration: const InputDecoration(
                        labelText: 'What is missing?',
                      ),
                      items:
                          const [
                                'Cut / section',
                                'Specification / sub-cut',
                                'Grade / attribute',
                                'Product',
                                'Other catalogue option',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      onChanged: _sending
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _kind = value);
                              }
                            },
                    ),
                    const IosGap(height: 14),
                    TextFormField(
                      key: const ValueKey('missing-item-name'),
                      controller: _name,
                      enabled: !_sending,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Item name',
                        hintText: 'Name the cut, product or option you need',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter the item you need.'
                          : null,
                    ),
                    TextFormField(
                      key: const ValueKey('missing-item-details'),
                      controller: _details,
                      enabled: !_sending,
                      maxLength: 3000,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Extra details (optional)',
                        hintText:
                            'Describe the specification or option you expected.',
                      ),
                    ),
                    if (_error != null) ...[
                      const IosGap(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFF741C1C)),
                      ),
                    ],
                    const IosGap(height: 16),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _sending
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('missing-item-send'),
                          onPressed: _sending ? null : _send,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF741C1C),
                          ),
                          icon: _sending
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(_sending ? 'Sending…' : 'Send request'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
