import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../animal_catalogues/product_variant.dart';
import '../animal_catalogues/lamb_product_details.dart';

/// Supplier-only filter metadata, shared by Inventory and Pricing. Never caches
/// prices, and never shares a cache across signed-in users or businesses.
class SupplierStockCatalogue {
  static final Map<String, ({DateTime at, List<Map<String, dynamic>> rows})>
  _cache = {};
  static final Map<String, Future<List<Map<String, dynamic>>>> _pending = {};
  static String _key(String businessId) =>
      '${Supabase.instance.client.auth.currentUser?.id}:$businessId';

  static void invalidate(String businessId) => _cache.remove(_key(businessId));

  static Future<List<Map<String, dynamic>>> load(String businessId) async {
    final key = _key(businessId);
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 2)) {
      return cached.rows;
    }
    if (_pending[key] case final request?) {
      return request;
    }
    final request = _fetch(businessId);
    _pending[key] = request;
    try {
      final rows = await request;
      _cache[key] = (at: DateTime.now(), rows: rows);
      return rows;
    } finally {
      _pending.remove(key);
    }
  }

  static Future<List<Map<String, dynamic>>> _fetch(String businessId) async {
    final response = await Supabase.instance.client
        .rpc(
          'supplier_stock_options',
          params: {'p_supplier_business_id': businessId},
        )
        .timeout(const Duration(seconds: 25));
    final data = Map<String, dynamic>.from(response as Map);
    Map<String, Map<String, dynamic>> index(String key) => {
      for (final row in List<Map<String, dynamic>>.from(data[key] as List))
        row['id'].toString(): row,
    };
    final columns = List<String>.from(data['columns'] as List);
    final variants = [
      for (final values in data['variants'] as List)
        <String, dynamic>{
          for (var i = 0; i < columns.length; i++)
            if (values[i] != null) columns[i]: values[i],
        },
    ];
    final animals = index('animals');
    final sections = index('sections');
    final specifications = index('specifications');
    final grades = index('grades');
    return [
      for (final row in variants)
        {
          ...row,
          'meat_animals': animals[row['meat_animal_id']],
          'meat_sections': sections[row['meat_section_id']],
          'meat_specifications': specifications[row['meat_specification_id']],
          'meat_grades': grades[row['meat_grade_id']],
        },
    ];
  }
}

class SupplierStockFilters {
  final Map<String, String> values = {};
  String status = 'all';
  String sort = 'name';

  static String value(Map<String, dynamic> row, String field) =>
      switch (field) {
        'size' => productSizeLabel(row),
        'program' => productProgram(row),
        'fat_class' => LambProductDetails.fatClass(row),
        'grade' => row['meat_grade_id']?.toString() ?? '',
        _ => row[field]?.toString().trim() ?? '',
      };

  bool matches(Map<String, dynamic> row) =>
      values.entries.every((entry) => value(row, entry.key) == entry.value);
  void clear() {
    values.clear();
    status = 'all';
    sort = 'name';
  }

  String get signature =>
      '${values.entries.map((e) => '${e.key}=${e.value}').join('|')}:$status:$sort';
}

class SupplierStockFilterBar extends StatelessWidget {
  const SupplierStockFilterBar({
    super.key,
    required this.rows,
    required this.filters,
    required this.onChanged,
    this.showGrade = true,
  });
  final List<Map<String, dynamic>> rows;
  final SupplierStockFilters filters;
  final VoidCallback onChanged;
  final bool showGrade;

  @override
  Widget build(BuildContext context) {
    Widget choice(
      String field,
      String label,
      Map<String, String> choices, {
      String? selected,
      void Function(String?)? update,
    }) {
      final current = selected ?? filters.values[field];
      final options = {...choices};
      if (current != null && !options.containsKey(current)) {
        options[current] = current;
      }
      final entries = options.entries.toList()
        ..sort(
          (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
        );
      return SizedBox(
        width: 174,
        child: DropdownButtonFormField<String>(
          key: ValueKey('$field:$current:${entries.length}'),
          initialValue: current,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
          ),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('All')),
            ...entries.map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(
                  e.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (value) {
            if (update != null) {
              update(value);
            } else if (value == null) {
              filters.values.remove(field);
            } else {
              filters.values[field] = value;
            }
            onChanged();
          },
        ),
      );
    }

    final fields = <String, String>{
      'brand': 'Brand',
      'size': 'Piece size',
      'program': 'Program',
      'fat_class': 'Fat Class',
      'bone_state': 'Bone',
      'marbling_score': 'Marbling',
      if (showGrade) 'grade': 'Category / grade',
      'halal_status': 'Halal',
      'temperature_state': 'Temperature',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final field in fields.entries)
          if (rows.any(
                (r) => SupplierStockFilters.value(r, field.key).isNotEmpty,
              ) ||
              filters.values.containsKey(field.key))
            choice(field.key, field.value, {
              for (final row in rows)
                if (SupplierStockFilters.value(row, field.key).isNotEmpty)
                  SupplierStockFilters.value(
                    row,
                    field.key,
                  ): field.key == 'grade'
                      ? [
                              row['meat_grades']?['code'],
                              row['meat_grades']?['name'],
                            ]
                            .where((v) => v != null && v.toString().isNotEmpty)
                            .join(' – ')
                      : SupplierStockFilters.value(row, field.key),
            }),
        choice(
          'status',
          'Stock / visibility',
          const {
            'active': 'Active listings',
            'inactive': 'Inactive listings',
            'in_stock': 'In stock',
            'out_of_stock': 'Out of stock',
          },
          selected: filters.status == 'all' ? null : filters.status,
          update: (v) => filters.status = v ?? 'all',
        ),
        choice(
          'sort',
          'Sort by',
          const {
            'name': 'Product name',
            'newest': 'Newest first',
            'stock_low': 'Lowest stock',
            'price_low': 'Standard price: low',
            'price_high': 'Standard price: high',
          },
          selected: filters.sort,
          update: (v) => filters.sort = v ?? 'name',
        ),
        TextButton.icon(
          onPressed: () {
            filters.clear();
            onChanged();
          },
          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: const Text('Reset filters'),
        ),
      ],
    );
  }
}

class SupplierStockPager extends StatelessWidget {
  const SupplierStockPager({
    super.key,
    required this.offset,
    required this.total,
    required this.loading,
    required this.onPage,
    this.pageSize = 40,
  });
  final int offset, total, pageSize;
  final bool loading;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            total == 0
                ? 'No matching products'
                : '${offset + 1}–${(offset + pageSize).clamp(0, total)} of $total products',
            style: const TextStyle(fontSize: 12, color: Color(0xFF666A70)),
          ),
        ),
        IconButton(
          tooltip: 'Previous page',
          onPressed: loading || offset == 0
              ? null
              : () => onPage((offset - pageSize).clamp(0, total)),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: loading || offset + pageSize >= total
              ? null
              : () => onPage(offset + pageSize),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}
