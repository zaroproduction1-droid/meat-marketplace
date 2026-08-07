import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierCustomerRequestsPage extends StatefulWidget {
  const SupplierCustomerRequestsPage({super.key});

  @override
  State<SupplierCustomerRequestsPage> createState() =>
      _SupplierCustomerRequestsPageState();
}

class _SupplierCustomerRequestsPageState
    extends State<SupplierCustomerRequestsPage> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _relationships = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
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

      final supplierBusinessId = membership['business_id'] as String;

      final response = await Supabase.instance.client
          .from('supplier_customer_relationships')
          .select('''
            id,
            butcher_business_id,
            status,
            account_reference,
            credit_terms,
            created_at,
            approved_at,
            businesses!supplier_customer_relationships_butcher_business_id_fkey(
              legal_name,
              trading_name
            )
            ''')
          .eq('supplier_business_id', supplierBusinessId)
          .order('created_at', ascending: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _relationships = List<Map<String, dynamic>>.from(response);

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

  Future<void> _updateStatus({
    required String relationshipId,
    required String status,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == 'approved') {
        updates['approved_at'] = DateTime.now().toIso8601String();
      }

      if (status != 'approved') {
        updates['approved_at'] = null;
      }

      await Supabase.instance.client
          .from('supplier_customer_relationships')
          .update(updates)
          .eq('id', relationshipId);

      if (!mounted) {
        return;
      }

      String message;

      switch (status) {
        case 'approved':
          message = 'Customer access approved.';
          break;
        case 'declined':
          message = 'Customer access declined.';
          break;
        case 'suspended':
          message = 'Customer access suspended.';
          break;
        default:
          message = 'Customer relationship updated.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      await _loadRequests();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _businessName(Map<String, dynamic> relationship) {
    final business = relationship['businesses'] as Map<String, dynamic>?;

    final tradingName = business?['trading_name'] as String?;

    if (tradingName != null && tradingName.trim().isNotEmpty) {
      return tradingName;
    }

    final legalName = business?['legal_name'] as String?;

    if (legalName != null && legalName.trim().isNotEmpty) {
      return legalName;
    }

    return 'Unknown butcher';
  }

  String _formatStatus(String? status) {
    switch (status) {
      case 'requested':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'declined':
        return 'Declined';
      case 'suspended':
        return 'Suspended';
      default:
        return 'Unknown';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'suspended':
        return Colors.red;
      case 'requested':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'declined':
        return Icons.cancel_outlined;
      case 'suspended':
        return Icons.block;
      case 'requested':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Customer Requests',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadRequests,
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
                onPressed: _loadRequests,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_relationships.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 76, color: Color(0xFF741C1C)),
              SizedBox(height: 20),
              Text(
                'No customer requests',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'Butcher access requests will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666)),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: _relationships.length,
          separatorBuilder: (context, index) {
            return const SizedBox(height: 14);
          },
          itemBuilder: (context, index) {
            final relationship = _relationships[index];

            final status = relationship['status'] as String?;

            final accountReference = relationship['account_reference']
                ?.toString();

            final creditTerms = relationship['credit_terms']?.toString();

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4E5E5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: Color(0xFF741C1C),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _businessName(relationship),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _statusIcon(status),
                                    size: 18,
                                    color: _statusColor(status),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatStatus(status),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _statusColor(status),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (accountReference != null &&
                        accountReference.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Account reference: '
                        '$accountReference',
                      ),
                    ],
                    if (creditTerms != null &&
                        creditTerms.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Credit terms: $creditTerms'),
                    ],
                    if (status == 'requested') ...[
                      const SizedBox(height: 22),
                      const Divider(),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              _updateStatus(
                                relationshipId: relationship['id'] as String,
                                status: 'approved',
                              );
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              _updateStatus(
                                relationshipId: relationship['id'] as String,
                                status: 'declined',
                              );
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Decline'),
                          ),
                        ],
                      ),
                    ],
                    if (status == 'approved') ...[
                      const SizedBox(height: 22),
                      const Divider(),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          _updateStatus(
                            relationshipId: relationship['id'] as String,
                            status: 'suspended',
                          );
                        },
                        icon: const Icon(Icons.block),
                        label: const Text('Suspend Access'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
