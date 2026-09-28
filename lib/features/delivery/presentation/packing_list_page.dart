import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/zoomable_pdf_preview.dart';
import '../services/packing_list_pdf.dart';

class PackingListPage extends StatefulWidget {
  const PackingListPage({super.key, this.orderId, this.runId})
    : assert((orderId == null) != (runId == null));
  final String? orderId;
  final String? runId;
  @override
  State<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends State<PackingListPage> {
  Uint8List? _bytes;
  String? _error;
  bool _exporting = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _bytes = null;
    });
    try {
      final client = Supabase.instance.client;
      final raw = await client.rpc(
        'supplier_delivery_packing_list',
        params: {'p_order_id': widget.orderId, 'p_run_id': widget.runId},
      );
      final data = Map<String, dynamic>.from(raw as Map);
      final supplier = Map<String, dynamic>.from(
        data['supplier'] as Map? ?? {},
      );
      Uint8List? logo;
      final path = supplier['logo_path']?.toString() ?? '';
      if (path.isNotEmpty) {
        try {
          logo = await client.storage.from('business-branding').download(path);
        } catch (_) {
          /* Packing details remain printable without branding. */
        }
      }
      final bytes = await PackingListPdf.build(data, logo: logo);
      if (mounted) {
        setState(() => _bytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _export(bool print) async {
    if (_bytes == null || _exporting) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final bytes = Uint8List.fromList(_bytes!);
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'packing-list-${widget.runId ?? widget.orderId}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to export packing list: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Packing list'),
      actions: [
        IconButton(
          tooltip: 'Download PDF',
          onPressed: _bytes == null || _exporting ? null : () => _export(false),
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          tooltip: 'Print packing list',
          onPressed: _bytes == null || _exporting ? null : () => _export(true),
          icon: const Icon(Icons.print_outlined),
        ),
      ],
    ),
    body: _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          )
        : _bytes == null
        ? const Center(child: CircularProgressIndicator())
        : ZoomablePdfPreview(
            documentKey: 'packing-${widget.runId ?? widget.orderId}',
            buildPdf: () async => Uint8List.fromList(_bytes!),
          ),
  );
}
