import '../../../shared/widgets/content_reason_dialog.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductPhotoModerationControls extends StatefulWidget {
  const ProductPhotoModerationControls({
    super.key,
    required this.productId,
    this.ticketId,
    this.onChanged,
  });
  final String productId;
  final String? ticketId;
  final VoidCallback? onChanged;
  @override
  State<ProductPhotoModerationControls> createState() =>
      _ProductPhotoModerationControlsState();
}

class _ProductPhotoModerationControlsState
    extends State<ProductPhotoModerationControls> {
  bool _busy = false;
  Future<void> _moderate(bool restrict) async {
    final reason = await requestContentReason(
      context,
      title: restrict
          ? 'Block and remove product photo'
          : 'Allow a new product photo',
      description: restrict
          ? 'Review the support report and evidence first. This removes the current photo '
                'and prevents replacement uploads until you allow them again. Your reason is audited.'
          : 'Allow the supplier to upload a new photo after review. This does not restore any removed image.',
      submitLabel: restrict ? 'Block and remove' : 'Allow new photo',
      maxLength: widget.ticketId == null ? 1000 : 700,
    );
    if (reason == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final client = Supabase.instance.client;
      final result = Map<String, dynamic>.from(
        await client.rpc(
              widget.ticketId == null
                  ? 'moderate_product_photo'
                  : 'moderate_reported_product_photo',
              params: {
                if (widget.ticketId == null)
                  'p_product_id': widget.productId
                else
                  'p_ticket_id': widget.ticketId,
                'p_reason': reason,
                'p_restrict': restrict,
              },
            )
            as Map,
      );
      final path = result['removed_path']?.toString();
      var message = restrict
          ? 'Photo blocked and removed from the catalogue.'
          : 'New photo uploads allowed.';
      if (restrict && path != null && path.isNotEmpty) {
        try {
          await client.storage.from('product-photos').remove([path]);
          message =
              'Photo blocked and storage file removed. Previously cached copies may take time to expire.';
        } catch (_) {
          message =
              'Photo is blocked, but storage deletion failed. Use Block and remove again '
              'to retry; the old public file URL may still work.';
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) {
        final message = error is PostgrestException && error.code == 'P0001'
            ? error.message
            : 'Moderation action failed. Refresh and try again.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      TextButton.icon(
        onPressed: _busy ? null : () => _moderate(true),
        icon: const Icon(Icons.hide_image_outlined, size: 18),
        label: const Text('Block / remove photo'),
      ),
      TextButton(
        onPressed: _busy ? null : () => _moderate(false),
        child: const Text('Allow new photo'),
      ),
    ],
  );
}
