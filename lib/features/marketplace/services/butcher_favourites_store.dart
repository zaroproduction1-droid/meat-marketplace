import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// UI-only state does not change the identity of a saved search.
String favouriteSearchKey(Map<String, dynamic> filters) {
  dynamic canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) {
      return value.map(canonical).toList();
    }
    return value;
  }

  final values = {...filters}
    ..remove('stock_view')
    ..remove('version');
  return jsonEncode(canonical(values));
}

Map<String, dynamic> favouriteMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class ButcherFavouritesStore extends ChangeNotifier {
  ButcherFavouritesStore({this.businessId});
  String? businessId;
  List<Map<String, dynamic>> searches = [];
  List<Map<String, dynamic>> products = [];
  final Set<String> busyProducts = {};
  bool loading = false;
  bool ready = false;
  String? error;
  bool _disposed = false;
  void _changed() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _read(String table, String userId) async {
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 500) {
      final batch = await Supabase.instance.client
          .from(table)
          .select()
          .eq('business_id', businessId!)
          .eq('user_id', userId)
          .order('id')
          .range(offset, offset + 499);
      rows.addAll(List<Map<String, dynamic>>.from(batch));
      if (batch.length < 500) {
        return rows;
      }
    }
  }

  Future<void> load() async {
    if (loading || _disposed) {
      return;
    }
    loading = true;
    error = null;
    _changed();
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw StateError('Please sign in.');
      }
      if (businessId == null) {
        final membership = await client
            .from('business_memberships')
            .select('business_id, businesses!inner(business_type)')
            .eq('user_id', user.id)
            .eq('status', 'active')
            .eq('businesses.business_type', 'butcher')
            .order('created_at')
            .limit(1)
            .single();
        businessId = membership['business_id'].toString();
      }
      final data = await Future.wait([
        _read('butcher_saved_searches', user.id),
        _read('butcher_favourite_products', user.id),
      ]);
      searches = data[0];
      products = data[1];
      ready = true;
    } catch (_) {
      error = 'Could not load favourites. Please retry.';
      ready = false;
    } finally {
      loading = false;
      _changed();
    }
  }

  bool hasSearch(Map<String, dynamic> filters) => searches.any(
    (row) =>
        favouriteSearchKey(favouriteMap(row['filters'])) ==
        favouriteSearchKey(filters),
  );
  bool hasProduct(String id) => products.any((row) => row['product_id'] == id);

  void rememberSearch(Map<String, dynamic> row) {
    searches.removeWhere((existing) => existing['id'] == row['id']);
    searches.add(row);
    _changed();
  }

  Future<void> removeSearch(Map<String, dynamic> filters) async {
    if (!ready) {
      throw StateError('Favourites unavailable. Please retry.');
    }
    final ids = searches
        .where(
          (row) =>
              favouriteSearchKey(favouriteMap(row['filters'])) ==
              favouriteSearchKey(filters),
        )
        .map((row) => row['id'].toString())
        .toList();
    if (ids.isEmpty) {
      return;
    }
    final deleted = await Supabase.instance.client
        .from('butcher_saved_searches')
        .delete()
        .eq('business_id', businessId!)
        .inFilter('id', ids)
        .select('id');
    if (deleted.length != ids.length) {
      throw StateError(
        'Saved search could not be removed. Refresh favourites.',
      );
    }
    searches.removeWhere((row) => ids.contains(row['id']));
    _changed();
  }

  Future<void> removeProductRow(String id) async {
    await Supabase.instance.client
        .from('butcher_favourite_products')
        .delete()
        .eq('business_id', businessId!)
        .eq('id', id)
        .select('id')
        .single();
    products.removeWhere((row) => row['id'] == id);
    _changed();
  }

  Future<void> toggleProduct(Map<String, dynamic> product) async {
    final id = product['id']?.toString();
    if (!ready || id == null) {
      throw StateError('Favourites unavailable. Please retry.');
    }
    if (!busyProducts.add(id)) {
      return;
    }
    _changed();
    try {
      final existing = products
          .where((row) => row['product_id'] == id)
          .toList();
      if (existing.isNotEmpty) {
        await removeProductRow(existing.first['id'].toString());
      } else {
        String text(dynamic value) {
          final s = value?.toString() ?? '';
          return s.length > 250 ? s.substring(0, 250) : s;
        }

        final business = favouriteMap(product['businesses']);
        final row = await Supabase.instance.client
            .from('butcher_favourite_products')
            .insert({
              'business_id': businessId,
              'product_id': id,
              'product_name': text(
                product['product_name'] ??
                    favouriteMap(product['meat_specifications'])['name'],
              ),
              'supplier_name': text(
                business['trading_name'] ?? business['legal_name'],
              ),
              'animal_code':
                  favouriteMap(product['meat_animals'])['code'] ?? '',
            })
            .select()
            .single();
        products.add(Map<String, dynamic>.from(row));
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        await load();
      } else {
        rethrow;
      }
    } finally {
      busyProducts.remove(id);
      _changed();
    }
  }
}

class ProductFavouriteHeart extends StatelessWidget {
  const ProductFavouriteHeart({
    super.key,
    required this.store,
    required this.product,
  });
  final ButcherFavouritesStore store;
  final Map<String, dynamic> product;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final id = product['id']?.toString() ?? '';
      final saved = store.hasProduct(id);
      return IconButton(
        tooltip: store.error != null
            ? 'Retry favourites'
            : saved
            ? 'Remove product favourite'
            : 'Favourite this supplier product',
        onPressed: store.loading || store.busyProducts.contains(id)
            ? null
            : () async {
                try {
                  if (!store.ready) {
                    await store.load();
                    return;
                  }
                  await store.toggleProduct(product);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not update product favourite. Please try again.',
                        ),
                      ),
                    );
                  }
                }
              },
        icon: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          color: saved ? const Color(0xFFB32632) : const Color(0xFF747980),
        ),
      );
    },
  );
}
