import '../../../shared/widgets/cutlink_review_theme.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/supplier_product_review_submission.dart';
import '../../admin/presentation/admin_product_review_page.dart';
import '../../products/presentation/add_product_page.dart';
import '../../products/presentation/edit_product_page.dart';

class SupplierProductModerationPanel extends StatefulWidget {
  const SupplierProductModerationPanel({
    super.key,
    required this.ticketId,
    required this.adminMode,
  });
  final String ticketId;
  final bool adminMode;
  @override
  State<SupplierProductModerationPanel> createState() =>
      _SupplierProductModerationPanelState();
}

class _SupplierProductModerationPanelState
    extends State<SupplierProductModerationPanel> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await Supabase.instance.client.rpc(
        'supplier_product_moderation_context',
        params: {'p_ticket_id': widget.ticketId},
      );
      if (mounted) {
        setState(() {
          _data = raw is Map ? Map<String, dynamic>.from(raw) : null;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'The product review could not be loaded.';
        });
      }
    }
  }

  Future<void> _submit(String id) async {
    try {
      await submitSupplierProductChanges(context, productId: id);
      if (mounted) {
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the correction confirmation. Retry.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LinearProgressIndicator();
    }
    if (_error != null) {
      return TextButton(onPressed: _load, child: Text('$_error Retry'));
    }
    final data = _data;
    if (data == null) {
      return const SizedBox.shrink();
    }
    final product = Map<String, dynamic>.from(data['product'] as Map);
    final review = data['review'] as Map? ?? const {};
    final state = data['workflow_state']?.toString() ?? 'waiting_supplier';
    final closed = data['case_closed'] == true;
    final retired = product['retired_by_cutlink'] == true || state == 'removed';
    final changed =
        (review['change_revision'] as num? ?? 0) >
        (review['submitted_revision'] as num? ?? 0);
    final actions = (data['actions'] as List? ?? []).whereType<Map>().toList();
    return CutLinkReviewTheme(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                retired
                    ? 'Product taken down'
                    : closed
                    ? 'Review complete'
                    : state == 'ready_for_review'
                    ? 'Waiting for CutLink to review your fix'
                    : 'Product needs fixing',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${product['product_name'] ?? 'Product'} · SKU ${product['sku'] ?? '—'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (data['final_note'] != null)
                Text(data['final_note'].toString())
              else if (!closed && actions.isNotEmpty)
                Text(
                  actions.first['supplier_message']?.toString() ??
                      'Review the product and correct the reported issue.',
                ),
              if (retired)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'This listing cannot be edited or restored. Add a new product from the start with a new SKU.',
                  ),
                ),
              if (!closed && changed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Saved changes: ${(review['changed_fields'] as List? ?? []).map(supplierCorrectionFieldLabel).toSet().join(', ')}',
                  ),
                ),
              if (!closed &&
                  state == 'ready_for_review' &&
                  review['confirmation_note'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('You confirmed: ${review['confirmation_note']}'),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.adminMode && data['product_exists'] == true)
                    FilledButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AdminProductReviewPage(
                              ticketId: widget.ticketId,
                            ),
                          ),
                        );
                        if (mounted) {
                          await _load();
                        }
                      },
                      child: const Text('Review this product'),
                    ),
                  if (!widget.adminMode &&
                      !retired &&
                      !closed &&
                      data['can_edit'] == true)
                    FilledButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EditProductPage(product: product),
                          ),
                        );
                        if (mounted) {
                          await _load();
                        }
                      },
                      child: const Text('Fix this product'),
                    ),
                  if (!widget.adminMode &&
                      !closed &&
                      !retired &&
                      data['can_edit'] == true &&
                      changed)
                    OutlinedButton(
                      onPressed: () => _submit(product['id'].toString()),
                      child: const Text('Confirm fix for review'),
                    ),
                  if (!widget.adminMode &&
                      retired &&
                      data['can_create'] == true)
                    FilledButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AddProductPage(
                              supplierBusinessId: data['supplier_business_id']
                                  .toString(),
                            ),
                          ),
                        );
                        if (mounted) {
                          await _load();
                        }
                      },
                      child: const Text('Add a new product'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
