import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../admin/presentation/admin_business_page.dart';
import '../../admin/presentation/product_photo_moderation_controls.dart';
import '../../../shared/widgets/product_report_dialog.dart';

class ProductReportContextPanel extends StatefulWidget {
  const ProductReportContextPanel({
    super.key,
    required this.ticketId,
    required this.adminMode,
  });
  final String ticketId;
  final bool adminMode;
  @override
  State<ProductReportContextPanel> createState() =>
      _ProductReportContextPanelState();
}

class _ProductReportContextPanelState extends State<ProductReportContextPanel> {
  Map<String, dynamic>? _context;
  String? _imageUrl, _error;
  bool _loading = true, _copying = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final raw = await client.rpc(
        'product_report_review_context',
        params: {'p_ticket_id': widget.ticketId},
      );
      if (raw == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _context = null;
          });
        }
        return;
      }
      final data = Map<String, dynamic>.from(raw as Map);
      String? url;
      final path = data['evidence_path']?.toString();
      if (path != null && data['evidence_status'] == 'captured') {
        try {
          url = await client.storage
              .from('support-attachments')
              .createSignedUrl(path, 300);
        } catch (_) {
          /* Show a retry state, never substitute a different current photo. */
        }
      } else if (data['source_path'] != null &&
          data['evidence_status'] != 'purged') {
        url = client.storage
            .from('product-photos')
            .getPublicUrl(data['source_path'].toString());
      }
      if (mounted) {
        setState(() {
          _context = data;
          _imageUrl = url;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Report details could not be loaded.';
        });
      }
    }
  }

  Future<void> _retryCopy() async {
    setState(() => _copying = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'submit-product-report',
        body: {'action': 'capture_evidence', 'ticket_id': widget.ticketId},
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The photo copy could not be saved. The original may no longer be available.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _copying = false);
      }
    }
  }

  void _zoom(String url, String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 950,
          height: MediaQuery.sizeOf(dialogContext).height * .8,
          child: Column(
            children: [
              ListTile(
                title: Text(title),
                trailing: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 6,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stack) => const Text(
                        'The photo could not be loaded. Close and refresh the report details.',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    if (_error != null) {
      return TextButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: Text('$_error Retry'),
      );
    }
    final data = _context;
    if (data == null) {
      return const SizedBox.shrink();
    }
    final report = Map<String, dynamic>.from(data['report'] as Map);
    if (report['purged_at'] != null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'The report details and photo evidence have expired under the support retention policy.',
          ),
        ),
      );
    }
    final snapshot = Map<String, dynamic>.from(report['snapshot'] as Map);
    final captured = data['evidence_status'] == 'captured';
    final currentPath = data['current_photo_path']?.toString();
    final reason =
        productReportReasons[report['reason']] ?? 'Product or photo concern';
    final grade = [
      snapshot['grade_code'],
      snapshot['grade_name'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(' — ');
    final photo = SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: const Color(0xFFF1F2F3),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _imageUrl == null
                  ? null
                  : () => _zoom(
                      _imageUrl!,
                      captured
                          ? 'Photo saved with this report'
                          : 'Original photo — no saved copy',
                    ),
              child: SizedBox(
                height: 145,
                child: _imageUrl == null
                    ? const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                          size: 36,
                        ),
                      )
                    : Image.network(
                        _imageUrl!,
                        fit: BoxFit.contain,
                        semanticLabel: 'Reported product photo',
                        errorBuilder: (_, error, stack) => const Center(
                          child: Text(
                            'Photo unavailable',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            captured
                ? 'Private copy saved with this report'
                : data['source_path'] == null
                ? 'No supplier photo was attached when reported'
                : 'Original photo; a saved copy is not confirmed',
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          snapshot['specification']?.toString() ??
              snapshot['product_name']?.toString() ??
              'Reported product',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          snapshot['supplier_name']?.toString() ?? 'Supplier',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF741C1C),
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            if (snapshot['sku'] != null)
              Text(
                'SKU ${snapshot['sku']}',
                style: const TextStyle(fontSize: 12),
              ),
            Text(
              [
                snapshot['animal'],
                snapshot['section'],
              ].where((v) => v != null).join(' • '),
              style: const TextStyle(fontSize: 12),
            ),
            if (grade.isNotEmpty)
              Text(grade, style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Text(reason, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        SelectableText(report['description']?.toString() ?? ''),
        if (report['reference_url'] != null) ...[
          const SizedBox(height: 10),
          const Text(
            'Supporting link',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          SelectableText(
            report['reference_url'].toString(),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D0D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8EEEE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  color: Color(0xFF741C1C),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Product & photo report',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  tooltip: 'Refresh report details',
                  icon: const Icon(Icons.refresh, size: 19),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth < 540
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [photo, const SizedBox(height: 15), details],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        photo,
                        const SizedBox(width: 18),
                        Expanded(child: details),
                      ],
                    ),
            ),
          ),
          if (!captured && data['source_path'] != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const Text(
                    'The original may be replaced or deleted before a copy is saved.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF846326)),
                  ),
                  if (data['closed'] != true)
                    TextButton(
                      onPressed: _copying ? null : _retryCopy,
                      child: Text(
                        _copying ? 'Saving copy…' : 'Retry saving photo copy',
                      ),
                    ),
                ],
              ),
            ),
          if (widget.adminMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 4, 15, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['photo_changed'] == true)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'The supplier photo has changed or been removed since this report. Review the current photo before taking action.',
                        style: TextStyle(
                          color: Color(0xFF846326),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (data['restricted'] == true)
                    const Text(
                      'Photo uploads are currently blocked for this product.',
                      style: TextStyle(
                        color: Color(0xFF741C1C),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (currentPath != null)
                        TextButton.icon(
                          onPressed: () => _zoom(
                            Supabase.instance.client.storage
                                .from('product-photos')
                                .getPublicUrl(currentPath),
                            'Current supplier photo',
                          ),
                          icon: const Icon(Icons.photo_outlined, size: 18),
                          label: const Text('View current photo'),
                        ),
                      if (snapshot['supplier_business_id'] != null)
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AdminBusinessPage(
                                businessId: snapshot['supplier_business_id']
                                    .toString(),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.storefront_outlined, size: 18),
                          label: const Text('Open supplier'),
                        ),
                      TextButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(
                            text:
                                'Ticket ${data['ticket_number']}\nProduct ${snapshot['product_id']}\nSKU ${snapshot['sku'] ?? ''}\nSupplier ${snapshot['supplier_name']}',
                          ),
                        ),
                        icon: const Icon(Icons.copy_outlined, size: 17),
                        label: const Text('Copy case reference'),
                      ),
                    ],
                  ),
                  if (data['product_exists'] == true &&
                      report['original_photo_path'] != null)
                    ProductPhotoModerationControls(
                      productId: report['product_id'].toString(),
                      ticketId: widget.ticketId,
                      onChanged: _load,
                    ),
                  const Text(
                    'Record the review reason when taking action. Reply and update the ticket status below.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
