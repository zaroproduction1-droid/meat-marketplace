import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/support/presentation/support_center_page.dart';
import 'product_report_dialog.dart';

class ProductContentReportButton extends StatefulWidget {
  const ProductContentReportButton({
    super.key,
    required this.product,
    this.businessId,
  });
  final Map<String, dynamic> product;
  final String? businessId;
  @override
  State<ProductContentReportButton> createState() =>
      _ProductContentReportButtonState();
}

class _ProductContentReportButtonState
    extends State<ProductContentReportButton> {
  bool _opening = false;
  Future<void> _report() async {
    setState(() => _opening = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw const FormatException('Sign in to report content.');
      }
      var businessId = widget.businessId;
      if (businessId == null) {
        final membership = await client
            .from('business_memberships')
            .select('business_id,businesses!inner(business_type)')
            .eq('user_id', user.id)
            .eq('status', 'active')
            .eq('businesses.business_type', 'butcher')
            .limit(1)
            .maybeSingle();
        businessId = membership?['business_id']?.toString();
      }
      if (businessId == null) {
        throw const FormatException(
          'Open Support Centre to report this content.',
        );
      }
      final reportBusiness = businessId;
      final product = await client
          .rpc(
            'catalogue_products',
            params: {
              'p_product_ids': [widget.product['id']],
            },
          )
          .select(
            'id,product_name,sku,photo_path,hide_catalogue_photo,supplier_business_id,businesses(trading_name,legal_name),meat_specifications(name)',
          )
          .maybeSingle();
      if (product == null) {
        throw const FormatException(
          'This product is no longer available. Refresh and try again.',
        );
      }
      if (!mounted) {
        return;
      }
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            ProductReportDialog(product: product, businessId: reportBusiness),
      );
      if (result == null || !mounted) {
        return;
      }
      final archived =
          result['evidence_status'] == 'captured' ||
          result['evidence_status'] == 'not_applicable';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['ticket_number'] ?? 'Report'} submitted.${archived ? '' : ' The photo copy could not be confirmed; Support can retry it.'}',
          ),
          action: SnackBarAction(
            label: 'Open report',
            onPressed: () {
              if (!mounted) {
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SupportCenterPage(
                    businessId: reportBusiness,
                    adminMode: false,
                    initialTicketId: result['ticket_id']?.toString(),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The report form could not be opened. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _opening ? null : _report,
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF6E5656),
      side: const BorderSide(color: Color(0xFFE1D5D5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    icon: const Icon(Icons.flag_outlined, size: 17),
    label: Text(_opening ? 'Opening report…' : 'Report photo or product'),
  );
}
