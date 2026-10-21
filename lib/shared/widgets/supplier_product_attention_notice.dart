import 'cutlink_review_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/support/presentation/support_center_page.dart';

class SupplierProductAttentionNotice extends StatefulWidget {
  const SupplierProductAttentionNotice({super.key, required this.businessId});
  final String? businessId;
  @override
  State<SupplierProductAttentionNotice> createState() =>
      _SupplierProductAttentionNoticeState();
}

class _SupplierProductAttentionNoticeState
    extends State<SupplierProductAttentionNotice> {
  List<Map<String, dynamic>> _rows = [];
  bool _error = false;
  Timer? _timer;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void didUpdateWidget(covariant SupplierProductAttentionNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _rows = [];
      _load();
    }
  }

  @override
  void dispose() {
    _request++;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final business = widget.businessId;
    final request = ++_request;
    if (business == null) {
      return;
    }
    try {
      final raw = await Supabase.instance.client.rpc(
        'supplier_product_attention',
        params: {'p_business_id': business},
      );
      if (mounted && request == _request) {
        setState(() {
          _rows = (raw as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          _error = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = true);
      }
    }
  }

  Future<void> _open() async {
    final business = widget.businessId;
    if (business == null) {
      return;
    }
    final chosen = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => CutLinkReviewTheme(
        child: AlertDialog(
          title: const Text('Products needing attention'),
          content: SizedBox(
            width: 650,
            height: 400,
            child: ListView(
              children: [
                for (final row in _rows)
                  ListTile(
                    leading: Icon(
                      row['listing_restricted'] == true
                          ? Icons.block
                          : Icons.warning_amber_rounded,
                      color: const Color(0xFF9C2626),
                    ),
                    title: Text(row['product_name']?.toString() ?? 'Product'),
                    subtitle: Text(
                      'SKU ${row['sku'] ?? '—'} · ${row['listing_restricted'] == true
                          ? 'Off marketplace'
                          : row['photo_restricted'] == true
                          ? 'Photo blocked'
                          : 'Review requested'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(c, row),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportCenterPage(
          businessId: business,
          adminMode: false,
          initialTicketId: chosen['ticket_id'].toString(),
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.businessId == null || (_rows.isEmpty && !_error)) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E5E8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF8D4F18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _rows.isNotEmpty
                  ? 'CutLink needs your attention on ${_rows.length == 100 ? '100+' : _rows.length} product${_rows.length == 1 ? '' : 's'}. Open the product to see the requested fix.'
                  : 'Product review alerts could not be refreshed.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: _rows.isNotEmpty ? _open : _load,
            child: Text(_rows.isNotEmpty ? 'Review products' : 'Retry'),
          ),
        ],
      ),
    );
  }
}
