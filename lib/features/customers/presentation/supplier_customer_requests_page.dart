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

      final memberships = await client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active');

      final businessIds = <String>[
        for (final membership in memberships)
          if (membership['business_id'] != null)
            membership['business_id'].toString(),
      ];

      if (businessIds.isEmpty) {
        throw Exception('No active business membership was found.');
      }

      final supplierBusinesses = await client
          .from('businesses')
          .select('id')
          .inFilter('id', businessIds)
          .eq('business_type', 'supplier')
          .eq('active', true);

      if (supplierBusinesses.isEmpty) {
        throw Exception('No active supplier business was found.');
      }

      final supplierBusinessId = supplierBusinesses.first['id'].toString();

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

  Future<void> _setAccountActive(
    Map<String, dynamic> account,
    bool active,
  ) async {
    try {
      await Supabase.instance.client
          .from('supplier_customer_accounts')
          .update({
            'active': active,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', account['id']);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'Customer account reactivated.'
                : 'Customer account deactivated.',
          ),
        ),
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

  Future<void> _openPendingVipApplicationForRelationship(
    Map<String, dynamic> relationship,
  ) async {
    final supplierBusinessId = _supplierBusinessId;
    final butcherBusinessId = relationship['butcher_business_id']?.toString();

    if (supplierBusinessId == null ||
        butcherBusinessId == null ||
        butcherBusinessId.isEmpty) {
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('vip_trade_applications')
          .select('''
            id,
            supplier_business_id,
            butcher_business_id,
            status,
            application_type,
            application_purpose,
            butcher_trading_name_snapshot,
            butcher_legal_name_snapshot,
            butcher_abn_snapshot,
            butcher_email_snapshot,
            butcher_phone_snapshot,
            butcher_address_snapshot,
            primary_contact_name,
            primary_contact_position,
            years_trading,
            estimated_monthly_purchases,
            requested_payment_terms_days,
            requested_credit_limit,
            application_message,
            trade_reference_contact_consent,
            commercial_credit_assessment_consent,
            consumer_credit_report_consent,
            privacy_notice_accepted,
            applicant_declaration_accepted,
            submitted_at,
            decided_at,
            created_at,
            vip_trade_application_references(
              id,
              reference_order,
              business_name,
              contact_name,
              contact_position,
              contact_email,
              contact_phone,
              years_trading_with_reference,
              notes
            ),
            vip_trade_application_documents(
              id,
              document_type,
              file_name,
              storage_path,
              mime_type,
              file_size_bytes,
              created_at
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('butcher_business_id', butcherBusinessId)
          .eq('status', 'pending')
          .order('submitted_at', ascending: false)
          .limit(1);

      final rows = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pending VIP application was found for this butcher.',
            ),
          ),
        );
        return;
      }

      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) =>
              SupplierVipApplicationDetailPage(application: rows.first),
        ),
      );

      if (!mounted) return;

      if (changed == true) {
        await _loadPage();
      }
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _vipApplicationsPanel(),
            const SizedBox(height: 20),
            const Text(
              'CutLink Customers',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage supplier-specific account settings for registered CutLink butchers.',
              style: TextStyle(color: Color(0xFF666666), height: 1.4),
            ),
            const SizedBox(height: 16),
            if (_relationships.isEmpty)
              _emptyCard(
                icon: Icons.people_outline,
                title: 'No CutLink customer requests',
                description: 'Butcher access requests will appear here.',
              )
            else
              for (final relationship in _relationships)
                _buildRelationshipCard(relationship),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'External Customers',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Customers entered by the supplier for phone, email, sales rep or manual orders.',
                        style: TextStyle(color: Color(0xFF666666), height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _openAddExternalCustomerDialog,
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  icon: const Icon(Icons.add),
                  label: const Text('Add External Customer'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_manualAccounts.isEmpty)
              _emptyCard(
                icon: Icons.person_add_alt_1_outlined,
                title: 'No external customers',
                description:
                    'Add a customer here when they order by phone, email or through a sales representative.',
              )
            else
              for (final account in _manualAccounts) _buildAccountCard(account),
          ],
        ),
      ),
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

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: status == 'requested'
            ? () => _openPendingVipApplicationForRelationship(relationship)
            : null,
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
                      color: _darkRed,
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
              if (status == 'approved') ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E1DE)),
                  ),
                  child: account == null
                      ? const Text(
                          'Customer account is being prepared. Refresh this page if it does not appear.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Commercial account',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text('Payment: ${_paymentText(account)}'),
                            if (account['account_reference'] != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                'Account reference: ${account['account_reference']}',
                              ),
                            ],
                            if (account['credit_limit'] != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                'Credit limit: \$${account['credit_limit']}',
                              ),
                            ],
                            const SizedBox(height: 5),
                            Text(
                              'Issue reporting window: ${account['issue_reporting_window_hours'] ?? 24} hours',
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _editCustomerAccount(account),
                              icon: const Icon(Icons.tune_outlined),
                              label: const Text('Edit Account'),
                            ),
                          ],
                        ),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (status == 'requested')
                    FilledButton.icon(
                      onPressed: () =>
                          _openPendingVipApplicationForRelationship(
                            relationship,
                          ),
                      style: FilledButton.styleFrom(backgroundColor: _darkRed),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Review Application'),
                    ),
                  if (status == 'approved')
                    OutlinedButton.icon(
                      onPressed: () => _updateStatus(
                        relationship: relationship,
                        status: 'suspended',
                      ),
                      icon: const Icon(Icons.block),
                      label: const Text('Suspend Access'),
                    ),
                  if (status == 'suspended' || status == 'declined')
                    OutlinedButton.icon(
                      onPressed: () => _updateStatus(
                        relationship: relationship,
                        status: 'approved',
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve Access'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final active = account['active'] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
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
                  child: const Icon(Icons.person_outline, color: _darkRed),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _accountName(account),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        active
                            ? 'Active external customer'
                            : 'Inactive customer',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Payment: ${_paymentText(account)}'),
            if (account['account_reference'] != null) ...[
              const SizedBox(height: 5),
              Text('Account reference: ${account['account_reference']}'),
            ],
            if (account['phone'] != null) ...[
              const SizedBox(height: 5),
              Text('Phone: ${account['phone']}'),
            ],
            if (account['email'] != null) ...[
              const SizedBox(height: 5),
              Text('Email: ${account['email']}'),
            ],
            if (account['delivery_suburb'] != null ||
                account['delivery_postcode'] != null) ...[
              const SizedBox(height: 5),
              Text(
                'Delivery: ${[account['delivery_suburb'], account['delivery_state'], account['delivery_postcode']].where((value) => value != null && value.toString().trim().isNotEmpty).join(' ')}',
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _editCustomerAccount(account),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Customer'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _setAccountActive(account, !active),
                  icon: Icon(
                    active
                        ? Icons.person_off_outlined
                        : Icons.person_add_alt_outlined,
                  ),
                  label: Text(active ? 'Deactivate' : 'Reactivate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
