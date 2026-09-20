import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/catalogue_product_image.dart';
import '../../marketplace/presentation/marketplace_product_details_page.dart';
import '../../marketplace/services/butcher_favourites_store.dart';

/// A bounded dashboard preview; the full list is managed in Favourites.
class ButcherFavouriteProductsPanel extends StatefulWidget {
  const ButcherFavouriteProductsPanel({
    super.key,
    required this.businessId,
    required this.onManage,
  });

  final String businessId;
  final VoidCallback onManage;

  @override
  State<ButcherFavouriteProductsPanel> createState() =>
      _ButcherFavouriteProductsPanelState();
}

class _ButcherFavouriteProductsPanelState
    extends State<ButcherFavouriteProductsPanel> {
  static const _productSelect =
      '*, meat_animals(id,code,name), meat_sections(id,name), '
      'meat_specifications(id,name), meat_grades(id,code,name), '
      'businesses(id,trading_name,legal_name,logo_path), '
      'product_prices(*,price_lists(*))';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String? _opening;

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
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw StateError('Sign in required');
      }
      final rows = await client
          .from('butcher_favourite_products')
          .select(
            'id,product_id,product_name,supplier_name,dashboard_slot,products('
            'id,active,photo_path,hide_catalogue_photo,'
            'meat_animals(code,name),meat_sections(name),'
            'meat_specifications(name),meat_grades(code,name),'
            'businesses(trading_name,legal_name))',
          )
          .eq('business_id', widget.businessId)
          .eq('user_id', user.id)
          .gte('dashboard_slot', 1)
          .lte('dashboard_slot', 4)
          .order('dashboard_slot')
          .limit(4);
      if (mounted) {
        setState(() => _rows = List<Map<String, dynamic>>.from(rows));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load favourite products.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (_opening != null || row['product_id'] == null) {
      return;
    }
    setState(() => _opening = row['id'].toString());
    final favourites = ButcherFavouritesStore(businessId: widget.businessId);
    try {
      final product = await Supabase.instance.client
          .from('products')
          .select(_productSelect)
          .eq('id', row['product_id'])
          .eq('active', true)
          .maybeSingle();
      if (product == null) {
        throw StateError('Product unavailable');
      }
      await favourites.load();
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MarketplaceProductDetailsPage(
            product: product,
            favourites: favourites,
          ),
        ),
      );
      if (mounted) {
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This product is unavailable or could not be loaded. Please try again.',
            ),
          ),
        );
      }
    } finally {
      favourites.dispose();
      if (mounted) {
        setState(() => _opening = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width >= 720
            ? (width - 30) / 4
            : width >= 430
            ? (width - 10) / 2
            : width;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var slot = 1; slot <= 4; slot++)
              SizedBox(width: itemWidth, child: _slot(slot)),
          ],
        );
      },
    );
  }

  Widget _slot(int slot) {
    final matches = _rows.where((row) => row['dashboard_slot'] == slot);
    if (matches.isNotEmpty) {
      return _tile(matches.first);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E7E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: InkWell(
              onTap: widget.onManage,
              borderRadius: BorderRadius.circular(10),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 36,
                color: Color(0xFF8B1E2D),
              ),
            ),
          ),
          Text('Favourite $slot', textAlign: TextAlign.center),
          TextButton(
            onPressed: widget.onManage,
            child: const Text('Choose product'),
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> row) {
    final product = favouriteMap(row['products']);
    final business = favouriteMap(product['businesses']);
    final grade = favouriteMap(product['meat_grades']);
    final name =
        favouriteMap(product['meat_specifications'])['name'] ??
        row['product_name'] ??
        'Product';
    final supplier =
        business['trading_name'] ??
        business['legal_name'] ??
        row['supplier_name'] ??
        'Supplier';
    final available = product.isNotEmpty && product['active'] == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E7E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth;
              return CatalogueProductImage(
                product: product,
                thumbnail: true,
                imageHeight: size - 2,
                imageWidth: size,
                fit: BoxFit.cover,
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            name.toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            supplier.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6E7278)),
          ),
          if (grade.isNotEmpty)
            Text(
              (grade['code'] ?? grade['name'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (!available) const Text('Currently unavailable'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: available && _opening == null ? () => _open(row) : null,
            icon: const Icon(
              Icons.favorite,
              size: 16,
              color: Color(0xFFB32632),
            ),
            label: Text(_opening == row['id'] ? 'Opening…' : 'View / order'),
          ),
        ],
      ),
    );
  }
}
