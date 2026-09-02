import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_invoice_page.dart';
import 'supplier_marketplace_order_detail_page.dart';
import 'supplier_orders_page.dart';
import 'supplier_sales_page.dart';
import 'supplier_work_order_page.dart';

enum SupplierDocumentType { all, quotes, workOrders, invoices }

enum _DocumentDateRange { any, today, last7Days, last30Days, custom }

class SupplierUnifiedOrdersPage extends StatefulWidget {
  const SupplierUnifiedOrdersPage({
    super.key,
    this.embedded = false,
    this.initialType = SupplierDocumentType.all,
  });

  final bool embedded;
  final SupplierDocumentType initialType;

  @override
  State<SupplierUnifiedOrdersPage> createState() =>
      _SupplierUnifiedOrdersPageState();
}

class _SupplierUnifiedOrdersPageState extends State<SupplierUnifiedOrdersPage> {
  static const _darkRed = Color(0xFF741C1C);
  static const _pageSize = 200;

  final _searchController = TextEditingController();
  final _customerController = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _documentNumberController = TextEditingController();
  late SupplierDocumentType _selectedType;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _loadedOrderCount = 0;
  String? _errorMessage;
  _CustomerOption? _selectedCustomer;
  String? _selectedSource;
  String? _selectedStatus;
  _DocumentDateRange _dateRange = _DocumentDateRange.any;
  DateTimeRange? _customDateRange;
  List<_UnifiedDocument> _documents = [];
  List<_CustomerOption> _customerOptions = [];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _searchController.addListener(_refreshView);
    _documentNumberController.addListener(_refreshView);
    _loadAllDocuments();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refreshView);
    _documentNumberController.removeListener(_refreshView);
    _searchController.dispose();
    _customerController.dispose();
    _customerFocusNode.dispose();
    _documentNumberController.dispose();
    super.dispose();
  }

  void _refreshView() {
    if (mounted) setState(() {});
  }

  Future<String> _resolveSupplierBusinessId() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('No signed-in user was found.');

    final memberships = await client
        .from('business_memberships')
        .select('business_id')
        .eq('user_id', user.id)
        .eq('status', 'active');
    final businessIds = <String>[
      for (final row in memberships)
        if (row['business_id'] != null) row['business_id'].toString(),
    ];
    if (businessIds.isEmpty) {
      throw Exception('No active business membership was found.');
    }

    final businesses = await client
        .from('businesses')
        .select('id, business_type, active')
        .inFilter('id', businessIds)
        .eq('active', true);
    for (final business in businesses) {
      if (business['business_type']?.toString() == 'supplier') {
        return business['id'].toString();
      }
    }
    throw Exception('No active supplier business membership was found.');
  }

  Future<void> _loadAllDocuments({bool append = false}) async {
    if (append && (_isLoadingMore || !_hasMore)) return;
    setState(() {
      if (append) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _loadedOrderCount = 0;
        _hasMore = true;
        _errorMessage = null;
      }
    });

    try {
      final supplierBusinessId = await _resolveSupplierBusinessId();
      if (!append && _customerOptions.isEmpty) {
        final customerResponse = await Supabase.instance.client
            .from('supplier_customer_accounts')
            .select(
              'id, customer_name, legal_name, linked_butcher_business_id, account_source',
            )
            .eq('supplier_business_id', supplierBusinessId)
            .eq('active', true)
            .order('customer_name');
        _customerOptions = (customerResponse as List)
            .whereType<Map>()
            .map(
              (row) => _CustomerOption.fromMap(Map<String, dynamic>.from(row)),
            )
            .toList();
      }

      final offset = append ? _loadedOrderCount : 0;
      final orderRows =
          _selectedType == SupplierDocumentType.all ||
              _selectedType == SupplierDocumentType.quotes
          ? await _queryOrderRows(supplierBusinessId, offset)
          : const <Map<String, dynamic>>[];
      final workOrderRows =
          _selectedType == SupplierDocumentType.all ||
              _selectedType == SupplierDocumentType.workOrders
          ? await _queryWorkOrderRows(supplierBusinessId, offset)
          : const <Map<String, dynamic>>[];
      final invoiceRows =
          _selectedType == SupplierDocumentType.all ||
              _selectedType == SupplierDocumentType.invoices
          ? await _queryInvoiceRows(supplierBusinessId, offset)
          : const <Map<String, dynamic>>[];

      final documents = <_UnifiedDocument>[];
      for (final order in orderRows) {
        final isQuote = order['status']?.toString() == 'draft';
        if (_selectedType == SupplierDocumentType.all || isQuote) {
          documents.add(_UnifiedDocument.fromOrder(order, isQuote: isQuote));
        }
      }
      for (final workOrder in workOrderRows) {
        final order = _nestedMap(workOrder['orders']);
        if (order != null) {
          documents.add(_UnifiedDocument.fromWorkOrder(workOrder, order));
        }
      }
      for (final invoice in invoiceRows) {
        final order = _nestedMap(invoice['orders']);
        if (order != null) {
          documents.add(_UnifiedDocument.fromInvoice(invoice, order));
        }
      }
      documents.sort((a, b) => b.sortDate.compareTo(a.sortDate));

      final pageLengths = <int>[
        if (orderRows.isNotEmpty ||
            _selectedType == SupplierDocumentType.quotes)
          orderRows.length,
        if (workOrderRows.isNotEmpty ||
            _selectedType == SupplierDocumentType.workOrders)
          workOrderRows.length,
        if (invoiceRows.isNotEmpty ||
            _selectedType == SupplierDocumentType.invoices)
          invoiceRows.length,
      ];
      final hasMore = pageLengths.any((length) => length == _pageSize);

      if (!mounted) return;
      setState(() {
        _documents = append ? [..._documents, ...documents] : documents;
        _documents.sort((a, b) => b.sortDate.compareTo(a.sortDate));
        _loadedOrderCount = offset + _pageSize;
        _hasMore = hasMore;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _queryOrderRows(
    String supplierBusinessId,
    int offset,
  ) async {
    var query = Supabase.instance.client
        .from('orders')
        .select('''
          id,
          order_number,
          butcher_business_id,
          supplier_customer_account_id,
          quote_number,
          quote_revision,
          quote_last_saved_at,
          status,
          order_source,
          source_reference,
          customer_reference,
          internal_notes,
          delivery_notes,
          total_amount,
          created_at,
          updated_at,
          supplier_customer_accounts(customer_name, legal_name),
          businesses!orders_butcher_business_id_fkey(trading_name, legal_name),
          order_items(product_name_snapshot, sku_snapshot, notes)
        ''')
        .eq('supplier_business_id', supplierBusinessId);

    if (_selectedType == SupplierDocumentType.quotes) {
      query = query.eq('status', 'draft');
    }
    query = _applyCustomerToTopLevelQuery(query);
    final response = await query
        .order('updated_at', ascending: false)
        .range(offset, offset + _pageSize - 1);
    return _maps(response);
  }

  Future<List<Map<String, dynamic>>> _queryWorkOrderRows(
    String supplierBusinessId,
    int offset,
  ) async {
    final response = await Supabase.instance.client
        .from('warehouse_work_orders')
        .select('''
          id,
          order_id,
          work_order_number,
          status,
          warehouse_instructions,
          created_at,
          updated_at,
          orders!inner(
            id,
            order_number,
            butcher_business_id,
            supplier_customer_account_id,
            status,
            order_source,
            source_reference,
            customer_reference,
            internal_notes,
            delivery_notes,
            total_amount,
            supplier_customer_accounts(customer_name, legal_name),
            businesses!orders_butcher_business_id_fkey(trading_name, legal_name),
            order_items(product_name_snapshot, sku_snapshot, notes)
          )
        ''')
        .eq('supplier_business_id', supplierBusinessId)
        .order('updated_at', ascending: false)
        .range(offset, offset + _pageSize - 1);
    return _maps(response);
  }

  Future<List<Map<String, dynamic>>> _queryInvoiceRows(
    String supplierBusinessId,
    int offset,
  ) async {
    var query = Supabase.instance.client
        .from('invoices')
        .select('''
          id,
          invoice_number,
          order_id,
          butcher_business_id,
          supplier_customer_account_id,
          status,
          customer_name_snapshot,
          customer_reference_snapshot,
          total_amount,
          amount_paid,
          credit_applied,
          outstanding_amount,
          invoice_date,
          created_at,
          updated_at,
          invoice_items(product_name_snapshot, sku_snapshot, notes_snapshot),
          orders!inner(
            id,
            order_number,
            butcher_business_id,
            supplier_customer_account_id,
            order_source,
            customer_reference,
            supplier_customer_accounts(customer_name, legal_name),
            businesses!orders_butcher_business_id_fkey(trading_name, legal_name)
          )
        ''')
        .eq('supplier_business_id', supplierBusinessId);

    query = _applyCustomerToTopLevelQuery(query);
    final response = await query
        .order('updated_at', ascending: false)
        .range(offset, offset + _pageSize - 1);
    return _maps(response);
  }

  dynamic _applyCustomerToTopLevelQuery(dynamic query) {
    final customer = _selectedCustomer;
    if (customer == null) return query;
    final butcherId = customer.linkedButcherBusinessId;
    return butcherId == null
        ? query.eq('supplier_customer_account_id', customer.accountId)
        : query.or(
            'supplier_customer_account_id.eq.${customer.accountId},butcher_business_id.eq.$butcherId',
          );
  }

  static Map<String, dynamic>? _nestedMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  static List<Map<String, dynamic>> _maps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  List<_UnifiedDocument> get _filteredDocuments {
    final textQuery = _searchController.text.trim().toLowerCase();
    final numberQuery = _documentNumberController.text.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _documents.where((document) {
      if (!_matchesSelectedType(document)) return false;
      if (_selectedCustomer != null &&
          !document.matchesCustomer(_selectedCustomer!)) {
        return false;
      }
      if (_selectedSource != null && document.sourceValue != _selectedSource) {
        return false;
      }
      if (_selectedStatus != null && document.statusValue != _selectedStatus) {
        return false;
      }
      if (textQuery.isNotEmpty && !document.searchText.contains(textQuery)) {
        return false;
      }
      if (numberQuery.isNotEmpty &&
          !document.documentNumberSearch.contains(numberQuery)) {
        return false;
      }

      final start = switch (_dateRange) {
        _DocumentDateRange.today => today,
        _DocumentDateRange.last7Days => today.subtract(const Duration(days: 6)),
        _DocumentDateRange.last30Days => today.subtract(
          const Duration(days: 29),
        ),
        _ => null,
      };
      if (start != null && document.sortDate.isBefore(start)) return false;
      if (_dateRange == _DocumentDateRange.custom && _customDateRange != null) {
        final end = _customDateRange!.end.add(const Duration(days: 1));
        if (document.sortDate.isBefore(_customDateRange!.start) ||
            !document.sortDate.isBefore(end)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool _matchesSelectedType(_UnifiedDocument document) =>
      switch (_selectedType) {
        SupplierDocumentType.all => true,
        SupplierDocumentType.quotes =>
          document.type == _UnifiedDocumentType.quote,
        SupplierDocumentType.workOrders =>
          document.type == _UnifiedDocumentType.workOrder,
        SupplierDocumentType.invoices =>
          document.type == _UnifiedDocumentType.invoice,
      };

  List<String> get _sources =>
      _documents
          .where(_matchesSelectedType)
          .map((document) => document.sourceValue)
          .where((source) => source.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  List<String> get _statuses =>
      _documents
          .where(_matchesSelectedType)
          .map((document) => document.statusValue)
          .where((status) => status.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  void _clearFilters() {
    _customerController.clear();
    _searchController.clear();
    _documentNumberController.clear();
    setState(() {
      _selectedCustomer = null;
      _selectedSource = null;
      _selectedStatus = null;
      _dateRange = _DocumentDateRange.any;
      _customDateRange = null;
    });
    _loadAllDocuments();
  }

  Future<void> _openDocument(_UnifiedDocument document) async {
    Widget page;
    switch (document.type) {
      case _UnifiedDocumentType.quote:
        page = SupplierSalesPage(initialQuoteOrderId: document.orderId);
      case _UnifiedDocumentType.workOrder:
        page = SupplierWorkOrderPage(orderId: document.orderId);
      case _UnifiedDocumentType.invoice:
        page = SupplierInvoicePage(invoiceId: document.id);
      case _UnifiedDocumentType.order:
        if (document.source == 'Marketplace') {
          page = SupplierMarketplaceOrderDetailPage(orderId: document.orderId);
        } else {
          page = const SupplierOrdersPage();
        }
    }

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _loadAllDocuments();
  }

  Widget _header() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE3E5E8))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EAEA),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _darkRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orders',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 1),
                Text(
                  'Search and manage customer orders, quotes, work orders and invoices',
                  style: TextStyle(
                    color: Color(0xFF74787E),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupplierSalesPage()),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Sale'),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _loadAllDocuments,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _typeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F3),
        border: Border.all(color: const Color(0xFFDDE0E4)),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _typeButton(
            SupplierDocumentType.all,
            'All',
            Icons.view_list_outlined,
          ),
          _typeButton(
            SupplierDocumentType.quotes,
            'Quotes',
            Icons.description_outlined,
          ),
          _typeButton(
            SupplierDocumentType.workOrders,
            'Work Orders',
            Icons.assignment_outlined,
          ),
          _typeButton(
            SupplierDocumentType.invoices,
            'Invoices',
            Icons.request_quote_outlined,
          ),
        ],
      ),
    );
  }

  Widget _typeButton(SupplierDocumentType type, String label, IconData icon) {
    final selected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: TextButton.icon(
        onPressed: () {
          setState(() {
            _selectedType = type;
            _selectedStatus = null;
          });
          _documentNumberController.clear();
          _loadAllDocuments();
        },
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : const Color(0xFF565B61),
          backgroundColor: selected ? _darkRed : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: selected
                ? const BorderSide(color: Color(0xFF641717))
                : BorderSide.none,
          ),
          elevation: selected ? 1 : 0,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }

  Widget _managementView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadAllDocuments,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final documents = _filteredDocuments;
    return Column(
      children: [
        _filterPanel(),
        const SizedBox(height: 10),
        _resultsHeader(),
        const SizedBox(height: 4),
        Expanded(
          child: documents.isEmpty
              ? const Center(
                  child: Text('No commercial records match this search.'),
                )
              : RefreshIndicator(
                  onRefresh: _loadAllDocuments,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    itemCount: documents.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, index) {
                      if (index == documents.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: OutlinedButton.icon(
                              onPressed: _isLoadingMore
                                  ? null
                                  : () => _loadAllDocuments(append: true),
                              icon: _isLoadingMore
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.expand_more, size: 18),
                              label: Text(
                                _isLoadingMore
                                    ? 'Loading...'
                                    : 'Load More Records',
                              ),
                            ),
                          ),
                        );
                      }
                      return _documentRow(documents[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _resultsHeader() {
    final invoice = _selectedType == SupplierDocumentType.invoices;
    Widget heading(
      String text,
      double width, {
      TextAlign align = TextAlign.left,
    }) => SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          color: Color(0xFF74787E),
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.35,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: invoice
            ? [
                heading('INVOICE', 120),
                const Expanded(flex: 2, child: _ColumnHeading('CUSTOMER')),
                const Expanded(flex: 3, child: _ColumnHeading('DESCRIPTION')),
                heading('DATE', 82),
                heading('SOURCE', 78),
                heading('TOTAL', 80, align: TextAlign.right),
                heading('PAID', 80, align: TextAlign.right),
                heading('OUTSTANDING', 80, align: TextAlign.right),
                const SizedBox(width: 10),
                heading('PAYMENT', 100),
                heading('STATUS', 85),
                const SizedBox(width: 18),
              ]
            : [
                heading('DOCUMENT', 135),
                if (_selectedType == SupplierDocumentType.all)
                  heading('TYPE', 90),
                const Expanded(flex: 2, child: _ColumnHeading('CUSTOMER')),
                const Expanded(flex: 3, child: _ColumnHeading('DESCRIPTION')),
                heading('DATE', 82),
                heading('SOURCE', 82),
                heading('TOTAL', 90, align: TextAlign.right),
                const SizedBox(width: 12),
                heading('STATUS', 100),
                const SizedBox(width: 18),
              ],
      ),
    );
  }

  Widget _filterPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE3E5E8)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fieldWidth = constraints.maxWidth < 760
                ? constraints.maxWidth
                : (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 9,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(width: fieldWidth, child: _customerLookup()),
                SizedBox(
                  width: fieldWidth,
                  child: _dropdown(
                    label: 'Source / Sales Type',
                    value: _sources.contains(_selectedSource)
                        ? _selectedSource
                        : null,
                    items: _sources,
                    itemLabel: _UnifiedDocument.sourceLabel,
                    onChanged: (value) =>
                        setState(() => _selectedSource = value),
                  ),
                ),
                SizedBox(width: fieldWidth, child: _dateRangeField()),
                SizedBox(
                  width: fieldWidth,
                  child: _textField(
                    controller: _searchController,
                    label: 'Text Filter',
                    hint: 'Customer, product, PO, notes or reference',
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _textField(
                    controller: _documentNumberController,
                    label: switch (_selectedType) {
                      SupplierDocumentType.all => 'Document Number',
                      SupplierDocumentType.quotes => 'Quote Number',
                      SupplierDocumentType.workOrders => 'Work Order Number',
                      SupplierDocumentType.invoices => 'Invoice Number',
                    },
                    hint: 'Enter a full or partial number',
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _dropdown(
                    label: _selectedType == SupplierDocumentType.invoices
                        ? 'Invoice Status'
                        : 'Status',
                    value: _statuses.contains(_selectedStatus)
                        ? _selectedStatus
                        : null,
                    items: _statuses,
                    itemLabel: _UnifiedDocument.label,
                    onChanged: (value) =>
                        setState(() => _selectedStatus = value),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _executeSearch,
                    icon: const Icon(Icons.search, size: 17),
                    label: const Text('Search'),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                    label: const Text('Clear Filters'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Text(
                    '${_filteredDocuments.length} result${_filteredDocuments.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF686D73),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _customerLookup() => RawAutocomplete<_CustomerOption>(
    textEditingController: _customerController,
    focusNode: _customerFocusNode,
    displayStringForOption: (option) => option.displayName,
    optionsBuilder: (value) {
      final query = value.text.trim().toLowerCase();
      if (query.isEmpty) return const Iterable<_CustomerOption>.empty();
      return _customerOptions.where(
        (customer) => customer.searchText.contains(query),
      );
    },
    onSelected: _selectCustomer,
    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
        TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            final selected = _selectedCustomer;
            if (selected != null && value != selected.displayName) {
              setState(() => _selectedCustomer = null);
            }
          },
          onSubmitted: (_) => _submitCustomer(),
          decoration:
              _inputDecoration(
                label: 'Customer',
                hint: 'Type a customer name',
              ).copyWith(
                prefixIcon: const Icon(Icons.person_search_outlined, size: 19),
                suffixIcon: _customerController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _customerController.clear();
                          setState(() => _selectedCustomer = null);
                          _loadAllDocuments();
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
              ),
        ),
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 260),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 5),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return ListTile(
                dense: true,
                title: Text(
                  option.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(option.sourceLabel),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    ),
  );

  void _selectCustomer(_CustomerOption customer) {
    _customerController.text = customer.displayName;
    setState(() => _selectedCustomer = customer);
    _loadAllDocuments();
  }

  void _submitCustomer() {
    final input = _customerController.text.trim().toLowerCase();
    if (input.isEmpty) {
      if (_selectedCustomer != null) {
        setState(() => _selectedCustomer = null);
        _loadAllDocuments();
      }
      return;
    }
    final matches = _customerOptions
        .where((customer) => customer.searchText.contains(input))
        .toList();
    final exact = matches
        .where((customer) => customer.displayName.toLowerCase() == input)
        .toList();
    if (exact.length == 1) {
      _selectCustomer(exact.single);
    } else if (matches.length == 1) {
      _selectCustomer(matches.single);
    } else {
      _customerFocusNode.requestFocus();
      setState(() {});
    }
  }

  void _executeSearch() {
    if (_customerController.text.trim().isNotEmpty &&
        _selectedCustomer == null) {
      _submitCustomer();
      return;
    }
    _loadAllDocuments();
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) => TextField(
    controller: controller,
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => _executeSearch(),
    decoration: _inputDecoration(label: label, hint: hint),
  );

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required String Function(String) itemLabel,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: _inputDecoration(label: label, hint: 'All'),
    items: [
      const DropdownMenuItem<String>(value: null, child: Text('All')),
      for (final item in items)
        DropdownMenuItem(value: item, child: Text(itemLabel(item))),
    ],
    onChanged: onChanged,
  );

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFFAFAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFE3E5E8)),
    ),
  );

  Widget _dateRangeField() => DropdownButtonFormField<_DocumentDateRange>(
    initialValue: _dateRange,
    decoration: _inputDecoration(label: 'Date Range', hint: 'Any'),
    items: const [
      DropdownMenuItem(value: _DocumentDateRange.any, child: Text('Any')),
      DropdownMenuItem(value: _DocumentDateRange.today, child: Text('Today')),
      DropdownMenuItem(
        value: _DocumentDateRange.last7Days,
        child: Text('Last 7 Days'),
      ),
      DropdownMenuItem(
        value: _DocumentDateRange.last30Days,
        child: Text('Last 30 Days'),
      ),
      DropdownMenuItem(
        value: _DocumentDateRange.custom,
        child: Text('Custom Range'),
      ),
    ],
    onChanged: (value) async {
      if (value == null) return;
      if (value == _DocumentDateRange.custom) {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: _customDateRange,
        );
        if (picked == null || !mounted) return;
        setState(() {
          _dateRange = value;
          _customDateRange = picked;
        });
      } else {
        setState(() {
          _dateRange = value;
          _customDateRange = null;
        });
      }
    },
  );

  Widget _documentRow(_UnifiedDocument document) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openDocument(document),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE3E5E8)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _selectedType == SupplierDocumentType.invoices
              ? _invoiceRow(document)
              : _standardRow(document),
        ),
      ),
    );
  }

  Widget _standardRow(_UnifiedDocument document) => Row(
    children: [
      SizedBox(
        width: 135,
        child: Text(
          document.number,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      if (_selectedType == SupplierDocumentType.all)
        SizedBox(width: 90, child: _badge(document.typeLabel)),
      Expanded(
        flex: 2,
        child: Text(document.customer, overflow: TextOverflow.ellipsis),
      ),
      Expanded(
        flex: 3,
        child: Text(
          document.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5),
        ),
      ),
      SizedBox(width: 82, child: _muted(document.dateLabel)),
      SizedBox(width: 82, child: _muted(document.source)),
      SizedBox(
        width: 90,
        child: Text(
          document.totalLabel,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(width: 100, child: _statusChip(document.status)),
      const Icon(Icons.chevron_right, size: 18, color: Color(0xFF777B80)),
    ],
  );

  Widget _invoiceRow(_UnifiedDocument document) => Row(
    children: [
      SizedBox(
        width: 120,
        child: Text(
          document.number,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      Expanded(
        flex: 2,
        child: Text(document.customer, overflow: TextOverflow.ellipsis),
      ),
      Expanded(
        flex: 3,
        child: Text(
          document.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5),
        ),
      ),
      SizedBox(width: 82, child: _muted(document.dateLabel)),
      SizedBox(width: 78, child: _muted(document.source)),
      _moneyCell(document.totalLabel),
      _moneyCell(document.amountPaidLabel),
      _moneyCell(document.outstandingLabel),
      const SizedBox(width: 10),
      SizedBox(width: 100, child: _statusChip(document.paymentStatus)),
      SizedBox(width: 85, child: _statusChip(document.status)),
      const Icon(Icons.chevron_right, size: 18, color: Color(0xFF777B80)),
    ],
  );

  Widget _moneyCell(String value) => SizedBox(
    width: 80,
    child: Text(
      value,
      textAlign: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
    ),
  );

  Widget _muted(String value) => Text(
    value,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 11, color: Color(0xFF666A70)),
  );

  Widget _statusChip(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900),
      ),
    ),
  );

  Widget _badge(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EAEA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _darkRed,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  Widget _body() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Align(alignment: Alignment.centerLeft, child: _typeSelector()),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(_selectedType),
            child: _managementView(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ColoredBox(
      color: const Color(0xFFF7F8FA),
      child: Column(
        children: [
          _header(),
          Expanded(child: _body()),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(child: content),
    );
  }
}

enum _UnifiedDocumentType { order, quote, workOrder, invoice }

class _ColumnHeading extends StatelessWidget {
  const _ColumnHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF74787E),
      fontSize: 9.5,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.35,
    ),
  );
}

class _CustomerOption {
  const _CustomerOption({
    required this.accountId,
    required this.displayName,
    required this.legalName,
    required this.linkedButcherBusinessId,
    required this.accountSource,
  });

  final String accountId;
  final String displayName;
  final String legalName;
  final String? linkedButcherBusinessId;
  final String accountSource;

  factory _CustomerOption.fromMap(Map<String, dynamic> row) {
    final customerName = row['customer_name']?.toString().trim() ?? '';
    final legalName = row['legal_name']?.toString().trim() ?? '';
    return _CustomerOption(
      accountId: row['id'].toString(),
      displayName: customerName.isNotEmpty
          ? customerName
          : (legalName.isNotEmpty ? legalName : 'Customer'),
      legalName: legalName,
      linkedButcherBusinessId: row['linked_butcher_business_id']?.toString(),
      accountSource: row['account_source']?.toString() ?? '',
    );
  }

  String get searchText => '$displayName $legalName'.toLowerCase();
  String get sourceLabel =>
      accountSource == 'manual' ? 'External customer' : 'CutLink customer';
}

class _UnifiedDocument {
  const _UnifiedDocument({
    required this.id,
    required this.orderId,
    required this.type,
    required this.number,
    required this.customer,
    required this.sortDate,
    required this.total,
    required this.statusValue,
    required this.sourceValue,
    required this.reference,
    required this.relatedOrderNumber,
    required this.searchableDetails,
    required this.itemDescriptions,
    required this.supplierCustomerAccountId,
    required this.butcherBusinessId,
    this.amountPaid,
    this.outstandingAmount,
  });

  final String id;
  final String orderId;
  final _UnifiedDocumentType type;
  final String number;
  final String customer;
  final DateTime sortDate;
  final double? total;
  final String statusValue;
  final String sourceValue;
  final String reference;
  final String relatedOrderNumber;
  final String searchableDetails;
  final List<String> itemDescriptions;
  final String? supplierCustomerAccountId;
  final String? butcherBusinessId;
  final double? amountPaid;
  final double? outstandingAmount;

  factory _UnifiedDocument.fromOrder(
    Map<String, dynamic> order, {
    required bool isQuote,
  }) {
    final revision = (order['quote_revision'] as num?)?.toInt() ?? 0;
    final baseNumber = isQuote
        ? order['quote_number']?.toString() ??
              order['order_number']?.toString() ??
              'Quote'
        : order['order_number']?.toString() ?? 'Order';
    return _UnifiedDocument(
      id: order['id'].toString(),
      orderId: order['id'].toString(),
      type: isQuote ? _UnifiedDocumentType.quote : _UnifiedDocumentType.order,
      number: isQuote && revision > 0 ? '$baseNumber R$revision' : baseNumber,
      customer: _customerName(order),
      sortDate: _date(
        order[isQuote ? 'quote_last_saved_at' : 'updated_at'] ??
            order['created_at'],
      ),
      total: _double(order['total_amount']),
      statusValue: order['status']?.toString() ?? '',
      sourceValue: order['order_source']?.toString() ?? '',
      reference:
          '${order['customer_reference'] ?? ''} ${order['source_reference'] ?? ''}',
      relatedOrderNumber: order['order_number']?.toString() ?? '',
      searchableDetails: _orderSearchableDetails(order),
      itemDescriptions: _itemDescriptions(order['order_items']),
      supplierCustomerAccountId: order['supplier_customer_account_id']
          ?.toString(),
      butcherBusinessId: order['butcher_business_id']?.toString(),
    );
  }

  factory _UnifiedDocument.fromWorkOrder(
    Map<String, dynamic> workOrder,
    Map<String, dynamic> order,
  ) => _UnifiedDocument(
    id: workOrder['id'].toString(),
    orderId: order['id'].toString(),
    type: _UnifiedDocumentType.workOrder,
    number: workOrder['work_order_number']?.toString() ?? 'Work Order',
    customer: _customerName(order),
    sortDate: _date(workOrder['updated_at'] ?? workOrder['created_at']),
    total: _double(order['total_amount']),
    statusValue: workOrder['status']?.toString() ?? '',
    sourceValue: order['order_source']?.toString() ?? '',
    reference:
        '${order['order_number'] ?? ''} ${order['customer_reference'] ?? ''}',
    relatedOrderNumber: order['order_number']?.toString() ?? '',
    searchableDetails:
        '${_orderSearchableDetails(order)} ${workOrder['warehouse_instructions'] ?? ''}',
    itemDescriptions: _itemDescriptions(order['order_items']),
    supplierCustomerAccountId: order['supplier_customer_account_id']
        ?.toString(),
    butcherBusinessId: order['butcher_business_id']?.toString(),
  );

  factory _UnifiedDocument.fromInvoice(
    Map<String, dynamic> invoice,
    Map<String, dynamic> order,
  ) => _UnifiedDocument(
    id: invoice['id'].toString(),
    orderId: order['id'].toString(),
    type: _UnifiedDocumentType.invoice,
    number: invoice['invoice_number']?.toString() ?? 'Invoice',
    customer:
        invoice['customer_name_snapshot']?.toString() ?? _customerName(order),
    sortDate: _date(
      invoice['invoice_date'] ?? invoice['updated_at'] ?? invoice['created_at'],
    ),
    total: _double(invoice['total_amount']),
    statusValue: invoice['status']?.toString() ?? '',
    sourceValue: order['order_source']?.toString() ?? '',
    reference:
        '${order['order_number'] ?? ''} ${order['customer_reference'] ?? ''} ${invoice['customer_reference_snapshot'] ?? ''}',
    relatedOrderNumber: order['order_number']?.toString() ?? '',
    searchableDetails: _invoiceSearchableDetails(invoice),
    itemDescriptions: _itemDescriptions(invoice['invoice_items']),
    supplierCustomerAccountId:
        invoice['supplier_customer_account_id']?.toString() ??
        order['supplier_customer_account_id']?.toString(),
    butcherBusinessId:
        invoice['butcher_business_id']?.toString() ??
        order['butcher_business_id']?.toString(),
    amountPaid: _double(invoice['amount_paid']),
    outstandingAmount: _double(invoice['outstanding_amount']),
  );

  String get typeLabel => switch (type) {
    _UnifiedDocumentType.order => 'ORDER',
    _UnifiedDocumentType.quote => 'QUOTE',
    _UnifiedDocumentType.workOrder => 'WORK ORDER',
    _UnifiedDocumentType.invoice => 'INVOICE',
  };

  String get dateLabel =>
      '${sortDate.day.toString().padLeft(2, '0')}/${sortDate.month.toString().padLeft(2, '0')}/${sortDate.year}';
  String get totalLabel =>
      total == null ? '—' : '\$${total!.toStringAsFixed(2)}';
  String get amountPaidLabel => _money(amountPaid);
  String get outstandingLabel => _money(outstandingAmount);
  String get status => label(statusValue);
  String get source => sourceLabel(sourceValue);
  String get paymentStatus {
    if (statusValue == 'void') return 'Void';
    if (statusValue == 'paid') return 'Paid';
    if (statusValue == 'part_paid' || (amountPaid ?? 0) > 0) {
      return 'Part Paid';
    }
    if (statusValue == 'issued') return 'Outstanding';
    return status;
  }

  String get documentNumberSearch => number.toLowerCase();
  String get description {
    if (itemDescriptions.isEmpty) return '-';
    final visible = itemDescriptions.take(3).join(', ');
    final hasMore = itemDescriptions.length > 3;
    final text = hasMore ? '$visible...' : visible;
    if (text.length <= 64) return text;
    return '${text.substring(0, 61).trimRight()}...';
  }

  bool matchesCustomer(_CustomerOption customer) =>
      supplierCustomerAccountId == customer.accountId ||
      (customer.linkedButcherBusinessId != null &&
          butcherBusinessId == customer.linkedButcherBusinessId);
  String get searchText =>
      '$number $relatedOrderNumber $typeLabel $customer $status $source $reference $searchableDetails'
          .toLowerCase();

  static String _money(double? value) =>
      value == null ? '-' : '\$${value.toStringAsFixed(2)}';

  static String _orderSearchableDetails(Map<String, dynamic> order) {
    final items = order['order_items'];
    final itemText = items is List
        ? items
              .whereType<Map>()
              .map(
                (item) =>
                    '${item['product_name_snapshot'] ?? ''} ${item['sku_snapshot'] ?? ''} ${item['notes'] ?? ''}',
              )
              .join(' ')
        : '';
    return '${order['internal_notes'] ?? ''} ${order['delivery_notes'] ?? ''} $itemText';
  }

  static String _invoiceSearchableDetails(Map<String, dynamic> invoice) {
    final items = invoice['invoice_items'];
    final itemText = items is List
        ? items
              .whereType<Map>()
              .map(
                (item) =>
                    '${item['product_name_snapshot'] ?? ''} ${item['sku_snapshot'] ?? ''} ${item['notes_snapshot'] ?? ''}',
              )
              .join(' ')
        : '';
    return '${invoice['customer_reference_snapshot'] ?? ''} $itemText';
  }

  static List<String> _itemDescriptions(dynamic raw) {
    if (raw is! List) return const [];
    final seen = <String>{};
    final descriptions = <String>[];
    for (final item in raw.whereType<Map>()) {
      final name = item['product_name_snapshot']?.toString().trim() ?? '';
      if (name.isNotEmpty && seen.add(name.toLowerCase())) {
        descriptions.add(name);
      }
    }
    return descriptions;
  }

  static Map<String, dynamic>? _map(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  static String _customerName(Map<String, dynamic> order) {
    final account = _map(order['supplier_customer_accounts']);
    final butcher = _map(order['businesses']);
    for (final value in [
      account?['customer_name'],
      account?['legal_name'],
      butcher?['trading_name'],
      butcher?['legal_name'],
    ]) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return 'Customer';
  }

  static DateTime _date(dynamic raw) =>
      DateTime.tryParse(raw?.toString() ?? '')?.toLocal() ?? DateTime(1900);
  static double? _double(dynamic raw) => raw == null
      ? null
      : (raw is num ? raw.toDouble() : double.tryParse(raw.toString()));
  static String label(dynamic raw) {
    final value = raw?.toString() ?? 'Unknown';
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  static String sourceLabel(dynamic raw) => switch (raw?.toString()) {
    'marketplace' => 'Marketplace',
    'phone' => 'Phone',
    'email' => 'Email',
    'sales_rep' => 'Sales Rep',
    'manual' => 'Manual',
    'replacement' => 'Replacement',
    final value? => value,
    null => '',
  };
}
