import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_vip_applications_page.dart';

class SupplierCustomerRequestsPage extends StatefulWidget {
  const SupplierCustomerRequestsPage({super.key});

  @override
  State<SupplierCustomerRequestsPage> createState() =>
      _SupplierCustomerRequestsPageState();
}

class _SupplierCustomerRequestsPageState
    extends State<SupplierCustomerRequestsPage> {
  static const _darkRed = Color(0xFF741C1C);

  bool _isLoading = true;
  String? _errorMessage;
  String? _supplierBusinessId;

  List<Map<String, dynamic>> _relationships = [];
  List<Map<String, dynamic>> _customerAccounts = [];
  int _pendingVipApplicationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      final membership = await client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final supplierBusinessId = membership['business_id'] as String;

      final relationshipResponse = await client
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
              trading_name,
              abn,
              business_email,
              business_phone,
              address_line_1,
              address_line_2,
              suburb,
              state,
              postcode
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .order('created_at', ascending: false);

      final accountResponse = await client
          .from('supplier_customer_accounts')
          .select('''
            id,
            supplier_business_id,
            linked_butcher_business_id,
            supplier_customer_relationship_id,
            account_source,
            customer_name,
            legal_name,
            abn,
            contact_name,
            email,
            phone,
            billing_address_line_1,
            billing_address_line_2,
            billing_suburb,
            billing_state,
            billing_postcode,
            delivery_address_line_1,
            delivery_address_line_2,
            delivery_suburb,
            delivery_state,
            delivery_postcode,
            account_reference,
            payment_method,
            payment_terms_days,
            credit_limit,
            issue_reporting_window_hours,
            active,
            created_at,
            updated_at
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .order('customer_name');

      final pendingVipApplications = await client
          .from('vip_trade_applications')
          .select('id')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('status', 'pending');

      final pendingVipCount = pendingVipApplications.length;

      if (!mounted) {
        return;
      }

      setState(() {
        _supplierBusinessId = supplierBusinessId;
        _relationships = List<Map<String, dynamic>>.from(relationshipResponse);
        _customerAccounts = List<Map<String, dynamic>>.from(accountResponse);
        _pendingVipApplicationCount = pendingVipCount;
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

  Map<String, dynamic>? _accountForRelationship(
    Map<String, dynamic> relationship,
  ) {
    final relationshipId = relationship['id']?.toString();
    final butcherId = relationship['butcher_business_id']?.toString();

    for (final account in _customerAccounts) {
      if (relationshipId != null &&
          account['supplier_customer_relationship_id']?.toString() ==
              relationshipId) {
        return account;
      }

      if (butcherId != null &&
          account['linked_butcher_business_id']?.toString() == butcherId) {
        return account;
      }
    }

    return null;
  }

  String _businessName(Map<String, dynamic> relationship) {
    final business = relationship['businesses'] as Map<String, dynamic>?;

    final tradingName = business?['trading_name']?.toString().trim();
    if (tradingName != null && tradingName.isNotEmpty) {
      return tradingName;
    }

    final legalName = business?['legal_name']?.toString().trim();
    if (legalName != null && legalName.isNotEmpty) {
      return legalName;
    }

    return 'Unknown butcher';
  }

  String _accountName(Map<String, dynamic> account) {
    final name = account['customer_name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final legalName = account['legal_name']?.toString().trim();
    if (legalName != null && legalName.isNotEmpty) {
      return legalName;
    }

    return 'Customer';
  }

  Future<void> _updateStatus({
    required Map<String, dynamic> relationship,
    required String status,
  }) async {
    final relationshipId = relationship['id']?.toString();

    if (relationshipId == null || relationshipId.isEmpty) {
      return;
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final updates = <String, dynamic>{
        'status': status,
        'updated_at': now,
        'approved_at': status == 'approved' ? now : null,
      };

      await Supabase.instance.client
          .from('supplier_customer_relationships')
          .update(updates)
          .eq('id', relationshipId);

      if (status == 'approved') {
        await _ensureCustomerAccountForRelationship(relationship);
      }

      if (!mounted) {
        return;
      }

      final message = switch (status) {
        'approved' => 'Customer access approved.',
        'declined' => 'Customer access declined.',
        'suspended' => 'Customer access suspended.',
        _ => 'Customer relationship updated.',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      await _loadPage();
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

  Future<void> _ensureCustomerAccountForRelationship(
    Map<String, dynamic> relationship,
  ) async {
    final supplierBusinessId = _supplierBusinessId;
    final relationshipId = relationship['id']?.toString();
    final butcherBusinessId = relationship['butcher_business_id']?.toString();
    final business = relationship['businesses'] as Map<String, dynamic>?;

    if (supplierBusinessId == null ||
        relationshipId == null ||
        butcherBusinessId == null ||
        business == null) {
      return;
    }

    final payload = <String, dynamic>{
      'supplier_business_id': supplierBusinessId,
      'linked_butcher_business_id': butcherBusinessId,
      'supplier_customer_relationship_id': relationshipId,
      'account_source': 'cutlink',
      'customer_name': _businessName(relationship),
      'legal_name': business['legal_name'],
      'abn': business['abn'],
      'email': business['business_email'],
      'phone': business['business_phone'],
      'billing_address_line_1': business['address_line_1'],
      'billing_address_line_2': business['address_line_2'],
      'billing_suburb': business['suburb'],
      'billing_state': business['state'],
      'billing_postcode': business['postcode'],
      'delivery_address_line_1': business['address_line_1'],
      'delivery_address_line_2': business['address_line_2'],
      'delivery_suburb': business['suburb'],
      'delivery_state': business['state'],
      'delivery_postcode': business['postcode'],
      'account_reference': relationship['account_reference'],
      'payment_method': relationship['payment_method'] ?? 'cod',
      'payment_terms_days': relationship['payment_terms_days'] ?? 0,
      'credit_limit': relationship['credit_limit'],
      'issue_reporting_window_hours':
          relationship['issue_reporting_window_hours'] ?? 24,
      'active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final existing = _accountForRelationship(relationship);

    if (existing == null) {
      await Supabase.instance.client
          .from('supplier_customer_accounts')
          .insert(payload);
      return;
    }

    await Supabase.instance.client
        .from('supplier_customer_accounts')
        .update(payload)
        .eq('id', existing['id']);
  }

  Future<void> _openAddExternalCustomerDialog() async {
    final supplierBusinessId = _supplierBusinessId;

    if (supplierBusinessId == null) {
      return;
    }

    final result = await _showCustomerAccountDialog();

    if (result == null) {
      return;
    }

    try {
      await Supabase.instance.client.from('supplier_customer_accounts').insert({
        'supplier_business_id': supplierBusinessId,
        'account_source': 'manual',
        ...result,
        'active': true,
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('External customer added.')));

      await _loadPage();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _editCustomerAccount(Map<String, dynamic> account) async {
    final result = await _showCustomerAccountDialog(account: account);

    if (result == null) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('supplier_customer_accounts')
          .update({
            ...result,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', account['id']);

      final relationshipId = account['supplier_customer_relationship_id']
          ?.toString();

      if (relationshipId != null && relationshipId.isNotEmpty) {
        await Supabase.instance.client
            .from('supplier_customer_relationships')
            .update({
              'payment_method': result['payment_method'],
              'payment_terms_days': result['payment_terms_days'],
              'credit_limit': result['credit_limit'],
              'issue_reporting_window_hours':
                  result['issue_reporting_window_hours'],
              'account_reference': result['account_reference'],
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', relationshipId);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer account updated.')),
      );

      await _loadPage();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<Map<String, dynamic>?> _showCustomerAccountDialog({
    Map<String, dynamic>? account,
  }) async {
    final customerNameController = TextEditingController(
      text: account?['customer_name']?.toString() ?? '',
    );
    final legalNameController = TextEditingController(
      text: account?['legal_name']?.toString() ?? '',
    );
    final abnController = TextEditingController(
      text: account?['abn']?.toString() ?? '',
    );
    final contactNameController = TextEditingController(
      text: account?['contact_name']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: account?['email']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: account?['phone']?.toString() ?? '',
    );

    final deliveryLine1Controller = TextEditingController(
      text: account?['delivery_address_line_1']?.toString() ?? '',
    );
    final deliveryLine2Controller = TextEditingController(
      text: account?['delivery_address_line_2']?.toString() ?? '',
    );
    final deliverySuburbController = TextEditingController(
      text: account?['delivery_suburb']?.toString() ?? '',
    );
    final deliveryStateController = TextEditingController(
      text: account?['delivery_state']?.toString() ?? 'NSW',
    );
    final deliveryPostcodeController = TextEditingController(
      text: account?['delivery_postcode']?.toString() ?? '',
    );

    final accountReferenceController = TextEditingController(
      text: account?['account_reference']?.toString() ?? '',
    );
    final paymentTermsController = TextEditingController(
      text: '${account?['payment_terms_days'] ?? 0}',
    );
    final creditLimitController = TextEditingController(
      text: account?['credit_limit'] == null
          ? ''
          : account!['credit_limit'].toString(),
    );
    final issueWindowController = TextEditingController(
      text: '${account?['issue_reporting_window_hours'] ?? 24}',
    );

    String paymentMethod = account?['payment_method']?.toString() ?? 'cod';

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                account == null ? 'Add External Customer' : 'Edit Customer',
              ),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: customerNameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Customer / trading name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: legalNameController,
                        decoration: const InputDecoration(
                          labelText: 'Legal name (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: abnController,
                        decoration: const InputDecoration(
                          labelText: 'ABN (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: contactNameController,
                        decoration: const InputDecoration(
                          labelText: 'Contact name (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Delivery address',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: deliveryLine1Controller,
                        decoration: const InputDecoration(
                          labelText: 'Address line 1 (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: deliveryLine2Controller,
                        decoration: const InputDecoration(
                          labelText: 'Address line 2 (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 560;

                          final suburb = TextField(
                            controller: deliverySuburbController,
                            decoration: const InputDecoration(
                              labelText: 'Suburb',
                              border: OutlineInputBorder(),
                            ),
                          );
                          final state = TextField(
                            controller: deliveryStateController,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                            ),
                          );
                          final postcode = TextField(
                            controller: deliveryPostcodeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Postcode',
                              border: OutlineInputBorder(),
                            ),
                          );

                          if (narrow) {
                            return Column(
                              children: [
                                suburb,
                                const SizedBox(height: 14),
                                state,
                                const SizedBox(height: 14),
                                postcode,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(flex: 2, child: suburb),
                              const SizedBox(width: 12),
                              Expanded(child: state),
                              const SizedBox(width: 12),
                              Expanded(child: postcode),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Commercial terms',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cod', child: Text('COD')),
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
                              creditLimitController.clear();
                            }
                          });
                        },
                      ),
                      if (paymentMethod == 'account') ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: paymentTermsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Account terms (days)',
                            hintText: 'Example: 7, 15, 30',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: creditLimitController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Credit limit (optional)',
                            prefixText: '\$',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: accountReferenceController,
                        decoration: const InputDecoration(
                          labelText: 'Account reference (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: issueWindowController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Issue reporting window (hours)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final customerName = customerNameController.text.trim();

                    if (customerName.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Enter a customer name.')),
                      );
                      return;
                    }

                    final paymentTermsDays =
                        int.tryParse(paymentTermsController.text.trim()) ?? 0;
                    final issueWindowHours = int.tryParse(
                      issueWindowController.text.trim(),
                    );

                    final creditLimitText = creditLimitController.text.trim();
                    final creditLimit = creditLimitText.isEmpty
                        ? null
                        : double.tryParse(creditLimitText);

                    if (paymentMethod == 'account' && paymentTermsDays <= 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Enter valid account terms in days.'),
                        ),
                      );
                      return;
                    }

                    if (issueWindowHours == null ||
                        issueWindowHours < 1 ||
                        issueWindowHours > 720) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
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
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid credit limit.'),
                        ),
                      );
                      return;
                    }

                    String? nullable(String value) {
                      final trimmed = value.trim();
                      return trimmed.isEmpty ? null : trimmed;
                    }

                    Navigator.of(dialogContext).pop({
                      'customer_name': customerName,
                      'legal_name': nullable(legalNameController.text),
                      'abn': nullable(abnController.text),
                      'contact_name': nullable(contactNameController.text),
                      'email': nullable(emailController.text),
                      'phone': nullable(phoneController.text),
                      'delivery_address_line_1': nullable(
                        deliveryLine1Controller.text,
                      ),
                      'delivery_address_line_2': nullable(
                        deliveryLine2Controller.text,
                      ),
                      'delivery_suburb': nullable(
                        deliverySuburbController.text,
                      ),
                      'delivery_state': nullable(deliveryStateController.text),
                      'delivery_postcode': nullable(
                        deliveryPostcodeController.text,
                      ),
                      'account_reference': nullable(
                        accountReferenceController.text,
                      ),
                      'payment_method': paymentMethod,
                      'payment_terms_days': paymentMethod == 'account'
                          ? paymentTermsDays
                          : 0,
                      'credit_limit': paymentMethod == 'account'
                          ? creditLimit
                          : null,
                      'issue_reporting_window_hours': issueWindowHours,
                    });
                  },
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  child: Text(account == null ? 'Add Customer' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    customerNameController.dispose();
    legalNameController.dispose();
    abnController.dispose();
    contactNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    deliveryLine1Controller.dispose();
    deliveryLine2Controller.dispose();
    deliverySuburbController.dispose();
    deliveryStateController.dispose();
    deliveryPostcodeController.dispose();
    accountReferenceController.dispose();
    paymentTermsController.dispose();
    creditLimitController.dispose();
    issueWindowController.dispose();

    return result;
  }

  String _formatStatus(String? status) {
    return switch (status) {
      'requested' => 'Pending',
      'approved' => 'Approved',
      'declined' => 'Declined',
      'suspended' => 'Suspended',
      _ => 'Unknown',
    };
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'approved' => Colors.green,
      'declined' => Colors.red,
      'suspended' => Colors.red,
      'requested' => Colors.orange,
      _ => Colors.grey,
    };
  }

  IconData _statusIcon(String? status) {
    return switch (status) {
      'approved' => Icons.check_circle_outline,
      'declined' => Icons.cancel_outlined,
      'suspended' => Icons.block,
      'requested' => Icons.schedule,
      _ => Icons.help_outline,
    };
  }

  String _paymentText(Map<String, dynamic> account) {
    final method = account['payment_method']?.toString();

    return switch (method) {
      'account' => '${account['payment_terms_days'] ?? 0} day account',
      'prepaid' => 'Prepaid',
      _ => 'COD',
    };
  }

  List<Map<String, dynamic>> get _manualAccounts {
    return _customerAccounts
        .where((account) => account['account_source']?.toString() == 'manual')
        .toList();
  }

  Future<void> _openVipApplications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SupplierVipApplicationsPage(),
      ),
    );

    if (!mounted) return;
    await _loadPage();
  }

  Widget _vipApplicationsPanel() {
    final hasPending = _pendingVipApplicationCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasPending ? const Color(0xFFFFF8EB) : const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPending ? const Color(0xFFE6C98A) : const Color(0xFFE0E0DD),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _darkRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: _darkRed,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'VIP Applications',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (hasPending) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9A6500),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_pendingVipApplicationCount pending',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  hasPending
                      ? 'You have VIP or credit applications waiting for review.'
                      : 'Review VIP pricing and credit applications from CutLink butchers.',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _openVipApplications,
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            icon: const Icon(Icons.open_in_new),
            label: Text(hasPending ? 'Review Now' : 'Open'),
          ),
        ],
      ),
    );
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
          FilledButton.icon(
            onPressed: _isLoading ? null : _openAddExternalCustomerDialog,
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add External Customer'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadPage,
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
              const Icon(Icons.error_outline, size: 60, color: _darkRed),
              const SizedBox(height: 18),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadPage,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;

        Widget cutLinkList() {
          if (_relationships.isEmpty) {
            return _emptyCard(
              icon: Icons.people_outline,
              title: 'No CutLink customer requests',
              description: 'Butcher access requests will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            itemCount: _relationships.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) =>
                _buildRelationshipCard(_relationships[index]),
          );
        }

        Widget externalList() {
          if (_manualAccounts.isEmpty) {
            return _emptyCard(
              icon: Icons.person_add_alt_1_outlined,
              title: 'No external customers',
              description:
                  'Add customers here for phone, email or sales-rep orders.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            itemCount: _manualAccounts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) =>
                _buildAccountCard(_manualAccounts[index]),
          );
        }

        Widget panel({
          required String title,
          required String subtitle,
          required Widget child,
          Widget? action,
        }) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0DD)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 12, 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ?action,
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: child),
              ],
            ),
          );
        }

        final vip = _vipApplicationsPanel();

        if (!desktop) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              vip,
              const SizedBox(height: 12),
              SizedBox(
                height: 420,
                child: panel(
                  title: 'CutLink Customers',
                  subtitle: 'Registered butcher relationships and terms.',
                  child: cutLinkList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 420,
                child: panel(
                  title: 'External Customers',
                  subtitle:
                      'Supplier-private phone, email and manual customers.',
                  action: FilledButton.icon(
                    onPressed: _openAddExternalCustomerDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkRed,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Add'),
                  ),
                  child: externalList(),
                ),
              ),
            ],
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                children: [
                  vip,
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: panel(
                            title: 'CutLink Customers',
                            subtitle:
                                'Registered butcher relationships and commercial account settings.',
                            child: cutLinkList(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: panel(
                            title: 'External Customers',
                            subtitle:
                                'Supplier-private customers for direct sales.',
                            action: FilledButton.icon(
                              onPressed: _openAddExternalCustomerDialog,
                              style: FilledButton.styleFrom(
                                backgroundColor: _darkRed,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.add, size: 17),
                              label: const Text('Add External'),
                            ),
                            child: externalList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 54, color: _darkRed),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipCard(Map<String, dynamic> relationship) {
    final status = relationship['status']?.toString();
    final account = _accountForRelationship(relationship);
    final accountText = account == null
        ? 'No account'
        : '${_paymentText(account)}'
              '${account['credit_limit'] == null ? '' : ' • Limit \$${account['credit_limit']}'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5E1)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF4E5E5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: _darkRed,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _businessName(relationship),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      _statusIcon(status),
                      size: 14,
                      color: _statusColor(status),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatStatus(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (status == 'approved') ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          accountText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (status == 'requested') ...[
            IconButton(
              tooltip: 'Approve',
              onPressed: () =>
                  _updateStatus(relationship: relationship, status: 'approved'),
              icon: const Icon(Icons.check_circle_outline),
              color: const Color(0xFF2E7D32),
            ),
            IconButton(
              tooltip: 'Decline',
              onPressed: () =>
                  _updateStatus(relationship: relationship, status: 'declined'),
              icon: const Icon(Icons.cancel_outlined),
              color: _darkRed,
            ),
          ] else
            PopupMenuButton<String>(
              tooltip: 'Customer actions',
              onSelected: (value) {
                if (value == 'edit' && account != null) {
                  _editCustomerAccount(account);
                } else if (value == 'suspend') {
                  _updateStatus(
                    relationship: relationship,
                    status: 'suspended',
                  );
                } else if (value == 'approve') {
                  _updateStatus(relationship: relationship, status: 'approved');
                }
              },
              itemBuilder: (_) => [
                if (account != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Account'),
                  ),
                if (status == 'approved')
                  const PopupMenuItem(
                    value: 'suspend',
                    child: Text('Suspend Access'),
                  ),
                if (status == 'suspended' || status == 'declined')
                  const PopupMenuItem(
                    value: 'approve',
                    child: Text('Approve Access'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final active = account['active'] == true;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _editCustomerAccount(account),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E5E1)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4E5E5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: _darkRed,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _accountName(account),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${active ? 'Active' : 'Inactive'} • ${_paymentText(account)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF777777),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _darkRed),
            ],
          ),
        ),
      ),
    );
  }
}
