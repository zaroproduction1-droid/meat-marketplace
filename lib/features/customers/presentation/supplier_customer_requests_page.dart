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
            payment_method,
            payment_terms_days,
            credit_limit,
            issue_reporting_window_hours,
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

  Future<void> _editAccountTerms(
    Map<String, dynamic> relationship,
  ) async {
    String paymentMethod =
        relationship['payment_method']?.toString() ?? 'cod';

    final paymentTermsController = TextEditingController(
      text: '${relationship['payment_terms_days'] ?? 0}',
    );

    final creditLimitController = TextEditingController(
      text: relationship['credit_limit'] == null
          ? ''
          : relationship['credit_limit'].toString(),
    );

    final issueWindowController = TextEditingController(
      text: '${relationship['issue_reporting_window_hours'] ?? 24}',
    );

    final accountReferenceController = TextEditingController(
      text: relationship['account_reference']?.toString() ?? '',
    );

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Account settings - ${_businessName(relationship)}',
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'cod',
                            child: Text('COD'),
                          ),
                          DropdownMenuItem(
                            value: 'prepaid',
                            child: Text('Prepaid'),
                          ),
                          DropdownMenuItem(
                            value: 'account',
                            child: Text('Account'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setDialogState(() {
                            paymentMethod = value;

                            if (value != 'account') {
                              paymentTermsController.text = '0';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      if (paymentMethod == 'account') ...[
                        TextField(
                          controller: paymentTermsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Account terms (days)',
                            hintText: 'Example: 7, 15, 30',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: creditLimitController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Credit limit',
                            hintText: 'Optional',
                            prefixText: '\$',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextField(
                        controller: accountReferenceController,
                        decoration: const InputDecoration(
                          labelText: 'Account reference',
                          hintText: 'Optional supplier account code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: issueWindowController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Issue reporting window (hours)',
                          hintText: 'Example: 24',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This controls how long after delivery the butcher is expected to report quality, wrong-product or delivery issues.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final paymentTermsDays =
                        int.tryParse(paymentTermsController.text.trim());

                    final issueWindowHours =
                        int.tryParse(issueWindowController.text.trim());

                    final creditLimitText =
                        creditLimitController.text.trim();

                    final creditLimit = creditLimitText.isEmpty
                        ? null
                        : double.tryParse(creditLimitText);

                    if (paymentMethod == 'account' &&
                        (paymentTermsDays == null ||
                            paymentTermsDays <= 0)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a valid number of account days.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (issueWindowHours == null ||
                        issueWindowHours < 1 ||
                        issueWindowHours > 720) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Issue reporting window must be between 1 and 720 hours.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (creditLimitText.isNotEmpty &&
                        (creditLimit == null || creditLimit < 0)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a valid credit limit.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop({
                      'payment_method': paymentMethod,
                      'payment_terms_days':
                          paymentMethod == 'account'
                              ? paymentTermsDays
                              : 0,
                      'credit_limit':
                          paymentMethod == 'account'
                              ? creditLimit
                              : null,
                      'issue_reporting_window_hours':
                          issueWindowHours,
                      'account_reference':
                          accountReferenceController.text.trim(),
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF741C1C),
                  ),
                  child: const Text('Save Settings'),
                ),
              ],
            );
          },
        );
      },
    );

    paymentTermsController.dispose();
    creditLimitController.dispose();
    issueWindowController.dispose();
    accountReferenceController.dispose();

    if (result == null) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('supplier_customer_relationships')
          .update({
            'payment_method': result['payment_method'],
            'payment_terms_days': result['payment_terms_days'],
            'credit_limit': result['credit_limit'],
            'issue_reporting_window_hours':
                result['issue_reporting_window_hours'],
            'account_reference':
                (result['account_reference'] as String).isEmpty
                    ? null
                    : result['account_reference'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', relationship['id']);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer account settings updated.'),
        ),
      );

      await _loadRequests();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  String _formatPaymentTerms(Map<String, dynamic> relationship) {
    final method = relationship['payment_method']?.toString();

    switch (method) {
      case 'account':
        return '${relationship['payment_terms_days'] ?? 0} day account';
      case 'prepaid':
        return 'Prepaid';
      case 'cod':
      default:
        return 'COD';
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
          'Customers & Accounts',
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

            final paymentTerms = _formatPaymentTerms(relationship);
            final creditLimit = relationship['credit_limit'];
            final issueWindowHours =
                relationship['issue_reporting_window_hours'] ?? 24;

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

                    if (status == 'approved') ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE1E1DE),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Commercial terms',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text('Payment: $paymentTerms'),
                            if (creditLimit != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Credit limit: \$${creditLimit.toString()}',
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'Issue reporting window: $issueWindowHours hours',
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _editAccountTerms(relationship),
                              icon: const Icon(Icons.tune_outlined),
                              label: const Text('Edit Account Settings'),
                            ),
                          ],
                        ),
                      ),
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
