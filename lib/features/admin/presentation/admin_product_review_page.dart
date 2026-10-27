import '../../../shared/widgets/ios_density.dart';
import '../../../shared/widgets/cutlink_review_theme.dart';

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/product_report_dialog.dart';
import '../../../shared/widgets/product_review_details.dart';
import '../../../shared/widgets/review_response_field.dart';
import '../../../shared/widgets/supplier_product_review_submission.dart';
import '../../support/presentation/support_center_page.dart';
import 'admin_theme.dart';

class AdminProductReviewPage extends StatefulWidget {
  const AdminProductReviewPage({
    super.key,
    this.ticketId,
    this.productId,
    this.accessReason,
  });
  final String? ticketId, productId, accessReason;
  @override
  State<AdminProductReviewPage> createState() => _AdminProductReviewPageState();
}

class _AdminProductReviewPageState extends State<AdminProductReviewPage> {
  final _client = Supabase.instance.client;
  Map<String, dynamic>? _data;
  final Map<String, String> _reportedPhotos = {};
  bool _loading = true, _saving = false, _changed = false;
  String? _error, _watchedCase, _requestKey, _payload;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _client.rpc(
        'admin_product_review',
        params: {
          'p_ticket_id': widget.ticketId,
          'p_product_id': widget.productId,
          'p_access_reason': widget.accessReason,
        },
      );
      final data = Map<String, dynamic>.from(raw as Map);
      final photos = <String, String>{};
      for (final report
          in (data['review_reports'] as List? ?? []).whereType<Map>()) {
        final path = report['evidence_path']?.toString();
        if (path != null && report['evidence_status'] == 'captured') {
          try {
            photos[report['ticket_id'].toString()] = await _client.storage
                .from('support-attachments')
                .createSignedUrl(path, 300);
          } catch (_) {
            /* The report text remains available; refresh can retry its photo. */
          }
        } else if (report['original_photo_path'] != null &&
            report['evidence_status'] != 'purged') {
          photos[report['ticket_id'].toString()] = _client.storage
              .from('product-photos')
              .getPublicUrl(report['original_photo_path'].toString());
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _reportedPhotos
          ..clear()
          ..addAll(photos);
        _loading = false;
        _changed = false;
      });
      _watchCase(data['supplier_ticket_id']?.toString());
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.code == 'P0001'
              ? e.message
              : 'The product review could not be loaded.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'The product review could not be loaded. Please retry.';
        });
      }
    }
  }

  void _watchCase(String? id) {
    if (_watchedCase == id) {
      return;
    }
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    _watchedCase = id;
    if (id == null) {
      _channel = null;
      return;
    }
    _channel = _client
        .channel('simple-product-review-$id-$hashCode')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'support_tickets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id,
          ),
          callback: (_) {
            if (mounted && !_saving) {
              setState(() => _changed = true);
            }
          },
        )
        .subscribe();
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _deletePhoto(String path) async {
    try {
      await _client.storage.from('product-photos').remove([path]);
    } catch (_) {
      _notice('The action is saved. Photo file deletion needs a retry below.');
    }
  }

  Future<void> _retryPhoto(String path) async {
    setState(() => _saving = true);
    await _deletePhoto(path);
    if (mounted) {
      await _load();
    }
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _decide(String decision) async {
    if (_saving || _changed) {
      return;
    }
    final response = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _DecisionDialog(decision: decision),
    );
    if (response == null || !mounted || _changed) {
      return;
    }
    final data = _data!;
    final params = <String, dynamic>{
      'p_product_id': (data['product'] as Map)['id'],
      'p_ticket_id': widget.ticketId,
      'p_decision': decision,
      'p_reason_code': response['reason'],
      'p_note': response['note'],
      'p_review_token': data['review_token'],
    };
    final payload = jsonEncode(params);
    if (_requestKey == null || payload != _payload) {
      _requestKey = _uuid();
      _payload = payload;
    }
    params['p_request_key'] = _requestKey;
    setState(() => _saving = true);
    try {
      if (decision == 'remove' ||
          (decision == 'request_fix' &&
              [
                'wrong_photo',
                'copyright',
                'inappropriate',
              ].contains(response['reason']))) {
        for (final report
            in (data['review_reports'] as List? ?? []).whereType<Map>()) {
          if (report['original_photo_path'] != null &&
              report['evidence_status'] != 'captured' &&
              report['evidence_status'] != 'purged') {
            try {
              await _client.functions.invoke(
                'submit-product-report',
                body: {
                  'action': 'capture_evidence',
                  'ticket_id': report['ticket_id'],
                },
              );
            } catch (_) {
              _notice(
                'The reported photo copy could not be saved. The review action will still proceed.',
              );
            }
          }
        }
      }
      final raw = await _client.rpc(
        'admin_decide_product_review',
        params: params,
      );
      final result = Map<String, dynamic>.from(raw as Map);
      final removed = result['removed_path']?.toString();
      if (removed != null && removed.isNotEmpty) {
        await _deletePhoto(removed);
      }
      _requestKey = null;
      _payload = null;
      _notice(switch (decision) {
        'waive' => 'Report waived and closed.',
        'request_fix' => 'Supplier notified. Waiting for their correction.',
        'approve' => 'Correction approved. Case closed.',
        _ => 'Product taken down. The supplier must create a new listing.',
      });
      if (mounted) {
        await _load();
      }
    } on PostgrestException catch (e) {
      _notice(
        e.code == 'P0001'
            ? e.message
            : 'The decision could not be confirmed. Retry with the same response.',
      );
    } catch (_) {
      _notice(
        'The decision could not be confirmed. Retry with the same response.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _chat() async {
    final id = _data?['supplier_ticket_id']?.toString();
    if (id == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportCenterPage(
          businessId: '',
          adminMode: true,
          initialTicketId: id,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  void _zoom(String url) {
    showDialog<void>(
      context: context,
      builder: (c) => CutLinkReviewTheme(
        child: Dialog(
          child: SizedBox(
            width: 900,
            height: MediaQuery.sizeOf(c).height * .8,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Photo reported by the butcher'),
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(c),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 6,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stack) => const Center(
                        child: Text(
                          'Photo unavailable. Close and refresh to retry.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final state = data?['workflow_state']?.toString() ?? 'reported';
    final review = data?['supplier_review'] as Map? ?? const {};
    final closed = state == 'resolved' || state == 'removed';
    final pendingPhoto =
        data?['decision_photo_pending'] ?? data?['photo_file_pending'];
    return AdminTheme(
      child: CutLinkReviewTheme(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Review reported product'),
            actions: [
              if (data?['supplier_ticket_id'] != null)
                IconButton(
                  onPressed: _saving ? null : _chat,
                  tooltip: 'Supplier chat',
                  icon: const Icon(Icons.chat_outlined),
                ),
              IconButton(
                onPressed: _saving ? null : _load,
                tooltip: 'Refresh review',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : data == null
              ? const SizedBox.shrink()
              : AbsorbPointer(
                  absorbing: _saving,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1050),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: ListTile(
                                leading: Icon(
                                  closed
                                      ? Icons.task_alt
                                      : state == 'ready_for_review'
                                      ? Icons.fact_check_outlined
                                      : Icons.pending_actions,
                                  color: closed
                                      ? Colors.green
                                      : const Color(0xFF741C1C),
                                ),
                                title: Text(switch (state) {
                                  'waiting_supplier' =>
                                    'Waiting for supplier to fix the product',
                                  'ready_for_review' =>
                                    'Supplier fixed the product — review it below',
                                  'resolved' => 'Case closed',
                                  'removed' =>
                                    'Product taken down — case closed',
                                  _ => 'New report — assess the product',
                                }),
                                subtitle: closed
                                    ? Text(
                                        data['final_note']?.toString() ??
                                            'The report has been reviewed and closed.',
                                      )
                                    : null,
                              ),
                            ),
                            if (_changed)
                              Card(
                                color: const Color(0xFFFFF2E5),
                                child: ListTile(
                                  title: const Text('Supplier update received'),
                                  trailing: TextButton(
                                    onPressed: _load,
                                    child: const Text('Refresh'),
                                  ),
                                ),
                              ),
                            for (final report
                                in (data['review_reports'] as List? ?? [])
                                    .whereType<Map>())
                              Card(
                                child: IosPadding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reported by: ${report['butcher_name'] ?? 'Butcher'}',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (report['reporter_name'] != null)
                                        Text(
                                          'Contact: ${report['reporter_name']}',
                                        ),
                                      const IosGap(height: 10),
                                      Text(
                                        productReportReasons[report['reason']] ??
                                            'Product concern',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (report['description'] != null &&
                                          report['description'] !=
                                              '${productReportReasons[report['reason']]}.')
                                        SelectableText(
                                          report['description'].toString(),
                                        ),
                                      if (report['reference_url'] != null)
                                        SelectableText(
                                          'Supporting link: ${report['reference_url']}',
                                        ),
                                      if (_reportedPhotos[report['ticket_id']
                                                  .toString()] !=
                                              null &&
                                          report['original_photo_path'] !=
                                              (data['product']
                                                  as Map)['photo_path'])
                                        IosPadding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: TextButton.icon(
                                            onPressed: () => _zoom(
                                              _reportedPhotos[report['ticket_id']
                                                  .toString()]!,
                                            ),
                                            icon: const Icon(
                                              Icons.image_outlined,
                                            ),
                                            label: const Text(
                                              'See the photo they reported',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            if ((data['review_reports'] as List? ?? []).isEmpty)
                              const IosPadding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'This review was opened directly by CutLink; no butcher report is linked.',
                                ),
                              ),
                            if (!closed &&
                                ((review['changed_fields'] as List? ?? [])
                                        .isNotEmpty ||
                                    state == 'ready_for_review'))
                              Card(
                                child: IosPadding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Supplier changed: ${(review['changed_fields'] as List? ?? []).map(supplierCorrectionFieldLabel).toSet().join(', ')}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (state == 'ready_for_review' &&
                                          review['confirmation_note'] != null)
                                        Text(
                                          review['confirmation_note']
                                              .toString(),
                                        ),
                                      if (state == 'waiting_supplier')
                                        const Text(
                                          'Changes are saved. Waiting for the supplier to confirm they are ready.',
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ProductReviewDetails(
                              product: Map<String, dynamic>.from(
                                data['product'] as Map,
                              ),
                              prices: data['prices'] as List? ?? const [],
                            ),
                            if (pendingPhoto != null)
                              TextButton.icon(
                                onPressed: () =>
                                    _retryPhoto(pendingPhoto.toString()),
                                icon: const Icon(Icons.warning_amber),
                                label: const Text(
                                  'Retry deleting the removed photo file',
                                ),
                              ),
                            if (!closed)
                              IosPadding(
                                padding: const EdgeInsets.all(12),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    if (state == 'reported')
                                      OutlinedButton(
                                        onPressed: _saving || _changed
                                            ? null
                                            : () => _decide('waive'),
                                        child: const Text(
                                          'Waive report · no issue',
                                        ),
                                      ),
                                    if (state == 'reported' ||
                                        state == 'ready_for_review')
                                      FilledButton(
                                        onPressed: _saving || _changed
                                            ? null
                                            : () => _decide(
                                                state == 'ready_for_review'
                                                    ? 'approve'
                                                    : 'request_fix',
                                              ),
                                        child: Text(
                                          state == 'ready_for_review'
                                              ? 'Approve fix & close case'
                                              : 'Request a fix',
                                        ),
                                      ),
                                    if (state == 'ready_for_review')
                                      OutlinedButton(
                                        onPressed: _saving || _changed
                                            ? null
                                            : () => _decide('request_fix'),
                                        child: const Text('Still needs fixing'),
                                      ),
                                    TextButton.icon(
                                      onPressed: _saving || _changed
                                          ? null
                                          : () => _decide('remove'),
                                      icon: const Icon(
                                        Icons.block,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        'Take down product',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_saving) const LinearProgressIndicator(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({required this.decision});
  final String decision;
  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _form = GlobalKey<FormState>();
  final _other = TextEditingController();
  String? _choice;
  Map<String, String> get _options => switch (widget.decision) {
    'waive' => {
      'no_issue': 'Reviewed: no issue found.',
      'accurate_photo': 'The product photo is accurate.',
      'accurate_details': 'The product information is accurate.',
    },
    'approve' => {
      'corrected': 'The correction has been reviewed and accepted.',
    },
    'remove' => {
      'unfixed': 'The supplier has not fixed the reported issue.',
      'repeated':
          'The product still contains incorrect or misleading information.',
      'food_safety': 'The product has a serious safety or compliance concern.',
    },
    _ => {
      'wrong_photo':
          'Replace the photo with a clear photo of the correct stock.',
      'product_details':
          'Correct the product information and submit it for review.',
      'copyright':
          'Replace the photo with one you own or have permission to use.',
      'inappropriate':
          'Replace the inappropriate photo with a suitable product photo.',
      'food_safety':
          'Correct the food safety or compliance information before submitting for review.',
    },
  };
  String get _title => switch (widget.decision) {
    'waive' => 'Waive report',
    'approve' => 'Approve fix and close',
    'remove' => 'Take down product',
    _ => 'Request a fix',
  };
  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CutLinkReviewTheme(
    child: AlertDialog(
      title: Text(_title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(switch (widget.decision) {
                  'waive' => 'Close this report without changing the product.',
                  'approve' =>
                    'Confirm the saved product is now correct. The supplier case will close.',
                  'remove' =>
                    'This listing will be removed and cannot be restored. The supplier must add a new product from the start with a new SKU. Existing orders and invoices are retained.',
                  _ =>
                    'The supplier will receive this request and can save and confirm their correction. For a photo issue, the reported photo is removed and replacement uploads are allowed.',
                }),
                const IosGap(height: 14),
                ReviewResponseField(
                  label: 'Reason / response',
                  options: _options,
                  value: _choice,
                  controller: _other,
                  onChanged: (v) => setState(() => _choice = v),
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
            if (!_form.currentState!.validate()) {
              return;
            }
            final reason = _choice == 'other'
                ? 'other'
                : widget.decision == 'request_fix'
                ? _choice!
                : widget.decision == 'remove'
                ? (_choice == 'food_safety' ? 'food_safety' : 'product_details')
                : 'corrected';
            Navigator.pop(context, <String, String>{
              'reason': reason,
              'note': _choice == 'other'
                  ? _other.text.trim()
                  : _options[_choice]!,
            });
          },
          child: Text(_title),
        ),
      ],
    ),
  );
}
