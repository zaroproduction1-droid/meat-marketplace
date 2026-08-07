import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceProductDetailsPage extends StatefulWidget {
  const MarketplaceProductDetailsPage({super.key, required this.product});

  final Map<String, dynamic> product;

  @override
  State<MarketplaceProductDetailsPage> createState() =>
      _MarketplaceProductDetailsPageState();
}

class _MarketplaceProductDetailsPageState
    extends State<MarketplaceProductDetailsPage> {
  bool _isCheckingRelationship = true;
  bool _isSubmittingRequest = false;
  String? _relationshipStatus;
  String? _butcherBusinessId;

  @override
  void initState() {
    super.initState();
    _loadRelationshipStatus();
  }

  Future<void> _loadRelationshipStatus() async {
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

      final butcherBusinessId = membership['business_id'] as String;

      final supplierBusinessId =
          widget.product['supplier_business_id'] as String;

      final relationships = await Supabase.instance.client
          .from('supplier_customer_relationships')
          .select('status')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('butcher_business_id', butcherBusinessId)
          .limit(1);

      if (!mounted) {
        return;
      }

      setState(() {
        _butcherBusinessId = butcherBusinessId;
        _relationshipStatus = relationships.isEmpty
            ? null
            : relationships.first['status'] as String?;
        _isCheckingRelationship = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCheckingRelationship = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCheckingRelationship = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to check supplier access.')),
      );
    }
  }

  Future<void> _requestSupplierAccess() async {
    final butcherBusinessId = _butcherBusinessId;

    if (butcherBusinessId == null) {
      return;
    }

    setState(() {
      _isSubmittingRequest = true;
    });

    try {
      await Supabase.instance.client
          .from('supplier_customer_relationships')
          .insert({
            'supplier_business_id': widget.product['supplier_business_id'],
            'butcher_business_id': butcherBusinessId,
            'status': 'requested',
          });

      if (!mounted) {
        return;
      }

      setState(() {
        _relationshipStatus = 'requested';
        _isSubmittingRequest = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier access request sent.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmittingRequest = false;
      });

      var message = error.message;

      if (error.code == '23505') {
        message = 'A supplier relationship already exists.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _supplierName() {
    final supplier = widget.product['businesses'] as Map<String, dynamic>?;

    final tradingName = supplier?['trading_name'] as String?;

    if (tradingName != null && tradingName.trim().isNotEmpty) {
      return tradingName;
    }

    return supplier?['legal_name'] as String? ?? 'Unknown supplier';
  }

  String _formatAvailability(String? value) {
    switch (value) {
      case 'in_stock':
        return 'In stock';
      case 'limited':
        return 'Limited stock';
      case 'out_of_stock':
        return 'Out of stock';
      case 'made_to_order':
        return 'Made to order';
      default:
        return 'Unknown';
    }
  }

  String _formatTemperature(String? value) {
    switch (value) {
      case 'fresh':
        return 'Fresh';
      case 'frozen':
        return 'Frozen';
      case 'chilled':
        return 'Chilled';
      default:
        return value ?? 'Not specified';
    }
  }

  Widget _buildRelationshipButton() {
    if (_isCheckingRelationship) {
      return const CircularProgressIndicator();
    }

    switch (_relationshipStatus) {
      case 'approved':
        return const Chip(
          avatar: Icon(Icons.verified, size: 18),
          label: Text('Approved customer'),
        );

      case 'requested':
        return const Chip(
          avatar: Icon(Icons.schedule, size: 18),
          label: Text('Access request pending'),
        );

      case 'declined':
        return const Chip(
          avatar: Icon(Icons.cancel_outlined, size: 18),
          label: Text('Access request declined'),
        );

      case 'suspended':
        return const Chip(
          avatar: Icon(Icons.block, size: 18),
          label: Text('Supplier access suspended'),
        );

      default:
        return FilledButton.icon(
          onPressed: _isSubmittingRequest ? null : _requestSupplierAccess,
          icon: _isSubmittingRequest
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_add_alt_1),
          label: Text(
            _isSubmittingRequest
                ? 'Sending Request'
                : 'Request Supplier Access',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    final animalType = product['animal_types'] as Map<String, dynamic>?;

    final cut = product['cuts'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Product Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['product_name'] as String? ?? 'Unnamed product',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _supplierName(),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF741C1C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Chip(
                            label: Text(
                              animalType?['name'] as String? ??
                                  'Unknown animal',
                            ),
                          ),
                          Chip(
                            label: Text(
                              cut?['name'] as String? ?? 'Unknown cut',
                            ),
                          ),
                          Chip(
                            label: Text(
                              _formatTemperature(
                                product['temperature_state'] as String?,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              _formatAvailability(
                                product['availability_status'] as String?,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 20),
                      _DetailRow(
                        label: 'SKU',
                        value: product['sku']?.toString() ?? 'Not provided',
                      ),
                      _DetailRow(
                        label: 'Brand',
                        value: product['brand']?.toString() ?? 'Not provided',
                      ),
                      _DetailRow(
                        label: 'Available quantity',
                        value:
                            '${product['available_quantity'] ?? 'Not provided'} '
                            '${product['quantity_unit'] ?? ''}',
                      ),
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 20),
                      const Text(
                        'Supplier Access',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Request access to become an approved customer of this supplier and view customer-only pricing.',
                        style: TextStyle(color: Color(0xFF5E5E5E), height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      _buildRelationshipButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
