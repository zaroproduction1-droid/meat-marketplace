import '../../../shared/widgets/cutlink_workspace_theme.dart';
import '../../../shared/widgets/phone_layout.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../customers/presentation/supplier_customer_requests_page.dart';
import 'price_list_products_page.dart';
import 'private_price_list_customers_page.dart';

class SupplierPriceListsPage extends StatefulWidget {
  const SupplierPriceListsPage({super.key});

  @override
  State<SupplierPriceListsPage> createState() => _SupplierPriceListsPageState();
}

class _SupplierPriceListsPageState extends State<SupplierPriceListsPage> {
  String _search = '', _visibility = 'all';
  bool _isLoading = true;
  String? _errorMessage;
  String? _supplierBusinessId;

  List<Map<String, dynamic>> _priceLists = [];

  @override
  void initState() {
    super.initState();
    _loadPriceLists();
  }

  Future<void> _loadPriceLists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final businessId = membership['business_id'] as String;

      final response = await Supabase.instance.client
          .from('price_lists')
          .select('''
            id,
            name,
            visibility,
            active,
            valid_from,
            valid_to,
            created_at
            ''')
          .eq('supplier_business_id', businessId)
          .order('created_at', ascending: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _supplierBusinessId = businessId;
        _priceLists = List<Map<String, dynamic>>.from(response);
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

  Future<void> _openCreatePriceListDialog() async {
    if (_supplierBusinessId == null) {
      return;
    }

    final nameController = TextEditingController();
    String visibility = 'public';
    bool isSaving = false;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> savePriceList() async {
              final name = nameController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a price list name.'),
                  ),
                );
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              try {
                await Supabase.instance.client.from('price_lists').insert({
                  'supplier_business_id': _supplierBusinessId,
                  'name': name,
                  'visibility': visibility,
                  'active': true,
                });

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop(true);
              } on PostgrestException catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isSaving = false;
                });

                var message = error.message;

                if (error.code == '23505') {
                  message = 'A price list with this name already exists.';
                }

                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(message)));
              }
            }

            return phoneDialog(
              context,
              AlertDialog(
                title: const Text('Create Price List'),
                content: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Price list name',
                          hintText: 'Example: Public Marketplace Prices',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        isExpanded: isPhoneLayout(context),
                        initialValue: visibility,
                        decoration: const InputDecoration(
                          labelText: 'Price visibility',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'public',
                            child: Text('Public marketplace'),
                          ),
                          DropdownMenuItem(
                            value: 'approved_customers',
                            child: Text('Approved customers'),
                          ),
                          DropdownMenuItem(
                            value: 'private',
                            child: Text('Private contract'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    visibility = value;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _visibilityDescription(visibility),
                        style: const TextStyle(
                          color: Color(0xFF5E5E5E),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop(false);
                          },
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSaving ? null : savePriceList,
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();

    if (created == true) {
      await _loadPriceLists();
    }
  }

  static String _visibilityDescription(String visibility) {
    switch (visibility) {
      case 'public':
        return 'Visible to approved marketplace buyers.';
      case 'approved_customers':
        return 'Visible only to butchers approved by this supplier.';
      case 'private':
        return 'Visible only to specifically assigned butcher businesses.';
      default:
        return '';
    }
  }

  String _formatVisibility(String? visibility) {
    switch (visibility) {
      case 'public':
        return 'Public';
      case 'approved_customers':
        return 'Approved customers';
      case 'private':
        return 'Private';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CutLinkWorkspaceTheme(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: phoneAppBar(
          context,
          AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Price Lists',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const SupplierCustomerRequestsPage(),
                    ),
                  );
                },
                tooltip: 'Customer requests',
                icon: const Icon(Icons.people_outline),
              ),
              IconButton(
                onPressed: _loadPriceLists,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreatePriceListDialog,
          backgroundColor: const Color(0xFF741C1C),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Create Price List'),
        ),
        body: _buildBody(),
      ),
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
                onPressed: _loadPriceLists,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_priceLists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.price_change_outlined,
                size: 80,
                color: Color(0xFF741C1C),
              ),
              const SizedBox(height: 24),
              const Text(
                'No price lists yet',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              const Text(
                'Create a price list to begin setting product prices.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _openCreatePriceListDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create First Price List'),
              ),
            ],
          ),
        ),
      );
    }

    final lists = _priceLists
        .where(
          (p) =>
              (_visibility == 'all' || p['visibility'] == _visibility) &&
              '${p['name']}'.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        const CutLinkSectionHeading(
          title: 'Pricing & customer offers',
          subtitle:
              'Standard pricing for the marketplace, Trade pricing for approved customers and private lists for agreed VIP rates.',
          icon: Icons.price_change_outlined,
        ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search price lists',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in const {
              'all': 'All lists',
              'public': 'Standard',
              'approved_customers': 'Trade',
              'private': 'VIP / private',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _visibility == entry.key,
                onSelected: (_) => setState(() => _visibility = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (lists.isEmpty) const Text('No price lists match your search.'),
        for (final list in lists)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.sell_outlined,
                          color: Color(0xFF741C1C),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${list['name']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            list['active'] == true ? 'Active' : 'Inactive',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatVisibility(list['visibility']?.toString())} · ${_visibilityDescription('${list['visibility']}')}',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PriceListProductsPage(
                                priceListId: '${list['id']}',
                                priceListName: '${list['name']}',
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit product prices'),
                        ),
                        if (list['visibility'] == 'private' &&
                            _supplierBusinessId != null)
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => PrivatePriceListCustomersPage(
                                  priceListId: '${list['id']}',
                                  priceListName: '${list['name']}',
                                  supplierBusinessId: _supplierBusinessId!,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.people_outline),
                            label: const Text('Assign VIP customers'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
