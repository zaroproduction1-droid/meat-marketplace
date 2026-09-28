import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';
import '../../../shared/widgets/phone_layout.dart';
import '../../../shared/widgets/zoomable_pdf_preview.dart';
import '../../admin/services/platform_invoice_pdf.dart';

/// Owner/manager access to their own platform bill, including while suspended.
class SubscriptionBillingPage extends StatefulWidget {
  const SubscriptionBillingPage({super.key, required this.businessId});
  final String businessId;
  @override
  State<SubscriptionBillingPage> createState() =>
      _SubscriptionBillingPageState();
}

class _SubscriptionBillingPageState extends State<SubscriptionBillingPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Supabase.instance.client.rpc(
        'my_platform_billing_invoices',
        params: {'p_business_id': widget.businessId},
      );
      if (mounted) {
        setState(
          () => _rows = (result as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'Could not load subscription invoices. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    Future<Uint8List>? pdf;
    Future<Uint8List> bytes() => pdf ??= PlatformInvoicePdf.build(row);
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (pageContext) => CutLinkWorkspaceTheme(
          child: Scaffold(
            appBar: phoneAppBar(
              pageContext,
              AppBar(
                title: Text('${row['invoice_number']}'),
                actions: [
                  IconButton(
                    tooltip: 'Download invoice',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () async {
                      try {
                        await Printing.sharePdf(
                          bytes: await bytes(),
                          filename: '${row['invoice_number']}.pdf',
                        );
                      } catch (_) {
                        if (pageContext.mounted) {
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Download failed. Please try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Print invoice',
                    icon: const Icon(Icons.print_outlined),
                    onPressed: () async {
                      try {
                        await Printing.layoutPdf(onLayout: (_) => bytes());
                      } catch (_) {
                        if (pageContext.mounted) {
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            const SnackBar(
                              content: Text('Print failed. Please try again.'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            body: ZoomablePdfPreview(
              documentKey: 'subscription-${row['id']}',
              buildPdf: bytes,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CutLinkWorkspaceTheme(
    child: Scaffold(
      appBar: phoneAppBar(
        context,
        AppBar(
          title: const Text('CutLink subscription'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const CutLinkSectionHeading(
                  title: 'Outstanding subscription invoices',
                  subtitle:
                      'Pay using the invoice details, then contact CutLink with the payment reference. Account access is reviewed after payment verification.',
                  icon: Icons.receipt_long_outlined,
                ),
                if (_error != null) Text(_error!),
                if (_error == null && _rows.isEmpty)
                  const Text(
                    'No unpaid subscription invoices. Contact support if your account is still restricted.',
                  ),
                for (final row in _rows)
                  Card(
                    child: ListTile(
                      title: Text('${row['invoice_number']}'),
                      subtitle: Text(
                        'Due ${row['due_date']} · AUD ${(double.tryParse('${row['outstanding']}') ?? 0).toStringAsFixed(2)} remaining',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(row),
                    ),
                  ),
              ],
            ),
    ),
  );
}
