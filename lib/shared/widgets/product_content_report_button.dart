import '../theme/cutlink_appearance.dart';

import 'dart:async';

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
  bool _opening = false, _checking = true;
  String? _reportBusiness;
  Map<String, dynamic>? _active;
  Timer? _refresh;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _check();
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_opening) {
        _check();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProductContentReportButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product['id'] != widget.product['id'] ||
        oldWidget.businessId != widget.businessId) {
      _generation++;
      _reportBusiness = null;
      _active = null;
      _checking = true;
      _check();
    }
  }

  @override
  void dispose() {
    _generation++;
    _refresh?.cancel();
    super.dispose();
  }

  Future<String> _business() async {
    if (_reportBusiness != null) {
      return _reportBusiness!;
    }
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const FormatException('Sign in to report content.');
    }
    var id = widget.businessId;
    if (id == null) {
      final membership = await client
          .from('business_memberships')
          .select('business_id,businesses!inner(business_type)')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .inFilter('businesses.business_type', ['butcher', 'supplier'])
          .limit(1)
          .maybeSingle();
      id = membership?['business_id']?.toString();
    }
    if (id == null) {
      throw const FormatException(
        'Open Support Centre to report this content.',
      );
    }
    return id;
  }

  Future<void> _check() async {
    final generation = ++_generation;
    try {
      final business = await _business();
      final result = await Supabase.instance.client.rpc(
        'active_product_content_report',
        params: {
          'p_business_id': business,
          'p_product_id': widget.product['id'],
        },
      );
      if (mounted && generation == _generation) {
        setState(() {
          _reportBusiness = business;
          _active = result is Map ? Map<String, dynamic>.from(result) : null;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _openExisting(
    String business,
    Map<String, dynamic> report,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportCenterPage(
          businessId: business,
          adminMode: false,
          initialTicketId: report['ticket_id']?.toString(),
        ),
      ),
    );
    if (mounted) {
      await _check();
    }
  }

  Future<void> _report() async {
    setState(() => _opening = true);
    try {
      final client = Supabase.instance.client;
      final business = await _business();
      // Recheck before every attempt, even if another tab or admin changed the case.
      final existing = await client.rpc(
        'active_product_content_report',
        params: {
          'p_business_id': business,
          'p_product_id': widget.product['id'],
        },
      );
      if (!mounted) {
        return;
      }
      if (existing is Map) {
        final report = Map<String, dynamic>.from(existing);
        setState(() {
          _active = report;
          _reportBusiness = business;
        });
        await _openExisting(business, report);
        return;
      }
      setState(() => _active = null);
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
            ProductReportDialog(product: product, businessId: business),
      );
      if (result == null || !mounted) {
        return;
      }
      await _check();
      if (!mounted) {
        return;
      }
      final archived = [
        'captured',
        'not_applicable',
      ].contains(result['evidence_status']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['already_reported'] == true
                ? 'Already reported. Continue ${result['ticket_number']} in Support.'
                : '${result['ticket_number'] ?? 'Report'} submitted.${archived ? '' : ' The photo copy could not be confirmed; Support can retry it.'}',
          ),
          action: SnackBarAction(
            label: 'Open report',
            onPressed: () {
              if (mounted) {
                _openExisting(business, result);
              }
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
            content: Text(
              'The report status could not be checked. Please retry.',
            ),
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
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Tooltip(
      message: _active == null
          ? 'Report a concern about this product or photo'
          : 'Your business already reported this product. Open the ticket to add details. A new report is available after admin resolves or closes it.',
      child: OutlinedButton.icon(
        onPressed: _opening || _checking ? null : _report,
        style: OutlinedButton.styleFrom(
          foregroundColor: _active != null
              ? const Color(0xFF2E7D32)
              : CutLinkPalette.color(0xFF6E5656),
          side: BorderSide(color: CutLinkPalette.color(0xFFE1D5D5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: Icon(
          _active != null ? Icons.check_circle_outline : Icons.flag_outlined,
          size: 17,
        ),
        label: Text(
          _opening
              ? 'Opening…'
              : _checking
              ? 'Checking report…'
              : _active != null
              ? 'Reported · View ticket'
              : 'Report photo or product',
        ),
      ),
    );
  }
}
