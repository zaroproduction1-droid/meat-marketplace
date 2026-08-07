import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'price_list_products_page.dart';

class PrivatePriceListCustomersPage extends StatefulWidget {
  const PrivatePriceListCustomersPage({
    super.key,
    required this.priceListId,
    required this.priceListName,
    required this.supplierBusinessId,
  });

  final String priceListId;
  final String priceListName;
  final String supplierBusinessId;

  @override
  State<PrivatePriceListCustomersPage> createState() =>
      _PrivatePriceListCustomersPageState();
}

class _PrivatePriceListCustomersPageState
    extends State<PrivatePriceListCustomersPage> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _customers = [];
  Set<String> _assignedCustomerIds = {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final relationships = await Supabase.instance.client
          .from('supplier_customer_relationships')
          .select('''
            butcher_business_id,
            status,
            businesses!supplier_customer_relationships_butcher_business_id_fkey(
              id,
              legal_name,
              trading_name
            )
            ''')
          .eq('supplier_business_id', widget.supplierBusinessId)
          .eq('status', 'approved')
          .order('created_at');

      final assigned = await Supabase.instance.client
          .from('price_list_customers')
          .select('butcher_business_id')
          .eq('price_list_id', widget.priceListId);

      final assignedIds = assigned
          .map((row) => row['butcher_business_id'] as String)
          .toSet();

      if (!mounted) {
        return;
      }

      setState(() {
        _customers = List<Map<String, dynamic>>.from(relationships);

        _assignedCustomerIds = assignedIds;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _setCustomerAssignment({
    required String butcherBusinessId,
    required bool assigned,
  }) async {
    try {
      if (assigned) {
        await Supabase.instance.client.from('price_list_customers').insert({
          'price_list_id': widget.priceListId,
          'butcher_business_id': butcherBusinessId,
        });
      } else {
        await Supabase.instance.client
            .from('price_list_customers')
            .delete()
            .eq('price_list_id', widget.priceListId)
            .eq('butcher_business_id', butcherBusinessId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        if (assigned) {
          _assignedCustomerIds.add(butcherBusinessId);
        } else {
          _assignedCustomerIds.remove(butcherBusinessId);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assigned
                ? 'Customer added to private price list.'
                : 'Customer removed from private price list.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _businessName(Map<String, dynamic> customer) {
    final business = customer['businesses'] as Map<String, dynamic>?;

    final tradingName = business?['trading_name'] as String?;

    if (tradingName != null && tradingName.trim().isNotEmpty) {
      return tradingName;
    }

    return business?['legal_name'] as String? ?? 'Unknown butcher';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          widget.priceListName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PriceListProductsPage(
                    priceListId: widget.priceListId,
                    priceListName: widget.priceListName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.price_change_outlined),
            label: const Text('Product Prices'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadCustomers,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Color(0xFF741C1C),
              ),
              const SizedBox(height: 18),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadCustomers,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_customers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 72, color: Color(0xFF741C1C)),
              SizedBox(height: 20),
              Text(
                'No approved customers',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'Approve a butcher customer first before assigning private pricing.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: _customers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final customer = _customers[index];

            final butcherBusinessId = customer['butcher_business_id'] as String;

            final assigned = _assignedCustomerIds.contains(butcherBusinessId);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                title: Text(
                  _businessName(customer),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  assigned
                      ? 'Private pricing enabled'
                      : 'Private pricing not assigned',
                ),
                value: assigned,
                onChanged: (value) {
                  _setCustomerAssignment(
                    butcherBusinessId: butcherBusinessId,
                    assigned: value,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
