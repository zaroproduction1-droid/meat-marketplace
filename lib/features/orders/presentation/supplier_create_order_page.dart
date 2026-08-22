import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierCreateOrderPage extends StatefulWidget {
  const SupplierCreateOrderPage({super.key});

  @override
  State<SupplierCreateOrderPage> createState() =>
      _SupplierCreateOrderPageState();
}

class _SupplierCreateOrderPageState extends State<SupplierCreateOrderPage> {
  static const _darkRed = Color(0xFF741C1C);

  final _customerSearchController = TextEditingController();
  final _deliveryNotesController = TextEditingController();
  final _internalNotesController = TextEditingController();

  bool _isLoading = true;
  bool _isSavingCustomer = false;
  bool _searchCommitted = false;
  String? _errorMessage;
  String? _supplierBusinessId;

  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _selectedCustomer;

  String _paymentMethod = 'cod';
  int _paymentTermsDays = 0;
  String _fulfilmentMethod = 'pickup';
  DateTime? _requestedDate = DateTime.now();
  TimeOfDay? _requestedTime = const TimeOfDay(hour: 12, minute: 0);

  @override
  void initState() {
    super.initState();
    _customerSearchController.addListener(_handleSearchChanged);
    _loadPage();
  }

  @override
  void dispose() {
    _customerSearchController.removeListener(_handleSearchChanged);
    _customerSearchController.dispose();
    _deliveryNotesController.dispose();
    _internalNotesController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (_searchCommitted) {
      setState(() => _searchCommitted = false);
    }
  }

  Future<String> _resolveSupplierBusinessId() async {
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

    final suppliers = await client
        .from('businesses')
        .select('id')
        .inFilter('id', businessIds)
        .eq('business_type', 'supplier')
        .eq('active', true);

    if (suppliers.isEmpty) {
      throw Exception('No active supplier business was found.');
    }

    return suppliers.first['id'].toString();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final supplierBusinessId = await _resolveSupplierBusinessId();

      final response = await client
          .from('supplier_customer_accounts')
          .select(
            'id, customer_name, legal_name, account_source, '
            'linked_butcher_business_id, account_reference, '
            'payment_method, payment_terms_days, contact_name, email, phone, '
            'abn, licence_number, '
            'delivery_address_line_1, delivery_address_line_2, '
            'delivery_suburb, delivery_state, delivery_postcode, active',
          )
          .eq('supplier_business_id', supplierBusinessId)
          .eq('active', true)
          .order('customer_name');

      final byId = <String, Map<String, dynamic>>{};

      for (final raw in response) {
        final customer = Map<String, dynamic>.from(raw);
        final id = customer['id']?.toString();
        if (id == null || id.isEmpty) continue;
        byId[id] = customer;
      }

      final customers = byId.values.toList()
        ..sort(
          (a, b) => _customerName(
            a,
          ).toLowerCase().compareTo(_customerName(b).toLowerCase()),
        );

      if (!mounted) return;

      setState(() {
        _supplierBusinessId = supplierBusinessId;
        _customers = customers;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  String _customerName(Map<String, dynamic> customer) {
    final customerName = customer['customer_name']?.toString().trim();
    final legalName = customer['legal_name']?.toString().trim();

    if (customerName != null && customerName.isNotEmpty) return customerName;
    if (legalName != null && legalName.isNotEmpty) return legalName;
    return 'Customer';
  }

  List<Map<String, dynamic>> get _matchingCustomers {
    final query = _customerSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final startsWith = <Map<String, dynamic>>[];
    final contains = <Map<String, dynamic>>[];

    for (final customer in _customers) {
      final name = _customerName(customer).toLowerCase();
      final legalName = customer['legal_name']?.toString().toLowerCase() ?? '';
      final abn = customer['abn']?.toString().toLowerCase() ?? '';
      final phone = customer['phone']?.toString().toLowerCase() ?? '';

      if (name.startsWith(query) || legalName.startsWith(query)) {
        startsWith.add(customer);
      } else if (name.contains(query) ||
          legalName.contains(query) ||
          abn.contains(query) ||
          phone.contains(query)) {
        contains.add(customer);
      }
    }

    return [...startsWith, ...contains];
  }

  void _commitCustomerSearch() {
    FocusScope.of(context).unfocus();
    setState(() => _searchCommitted = true);
  }

  bool _customerHasAccount(Map<String, dynamic> customer) {
    return customer['payment_method']?.toString() == 'account' &&
        (customer['payment_terms_days'] is num) &&
        (customer['payment_terms_days'] as num).toInt() > 0;
  }

  int _customerAccountTerms(Map<String, dynamic> customer) {
    final raw = customer['payment_terms_days'];
    if (raw is num) {
      return raw.toInt();
    }
    return 0;
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    final hasAccount = _customerHasAccount(customer);

    setState(() {
      _selectedCustomer = customer;
      _customerSearchController.text = _customerName(customer);
      _searchCommitted = false;

      // Approved account customers default to Account.
      // Non-account customers default to COD.
      _paymentMethod = hasAccount ? 'account' : 'cod';
      _paymentTermsDays = hasAccount ? _customerAccountTerms(customer) : 0;
    });
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _addCustomer() async {
    final supplierBusinessId = _supplierBusinessId;
    if (supplierBusinessId == null || _isSavingCustomer) return;

    final businessNameController = TextEditingController(
      text: _customerSearchController.text.trim(),
    );
    final legalNameController = TextEditingController();
    final identificationNumberController = TextEditingController();
    var identificationType = 'abn';
    final contactNameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final address1Controller = TextEditingController();
    final address2Controller = TextEditingController();
    final suburbController = TextEditingController();
    final stateController = TextEditingController(text: 'NSW');
    final postcodeController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add New Customer'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: businessNameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Business / customer name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: legalNameController,
                    decoration: const InputDecoration(
                      labelText: 'Legal name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setIdentificationState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Identification (optional)',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'abn',
                                label: Text('ABN'),
                                icon: Icon(Icons.business_outlined),
                              ),
                              ButtonSegment(
                                value: 'licence',
                                label: Text('Licence Number'),
                                icon: Icon(Icons.badge_outlined),
                              ),
                            ],
                            selected: {identificationType},
                            onSelectionChanged: (selection) {
                              setIdentificationState(() {
                                identificationType = selection.first;
                                identificationNumberController.clear();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: identificationNumberController,
                            keyboardType: identificationType == 'abn'
                                ? TextInputType.number
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: identificationType == 'abn'
                                  ? 'ABN'
                                  : 'Licence number',
                              hintText: identificationType == 'abn'
                                  ? 'Enter business ABN'
                                  : 'Enter licence number',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactNameController,
                    decoration: const InputDecoration(
                      labelText: 'Contact name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Default delivery address',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: address1Controller,
                    decoration: const InputDecoration(
                      labelText: 'Address line 1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: address2Controller,
                    decoration: const InputDecoration(
                      labelText: 'Address line 2 (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: suburbController,
                          decoration: const InputDecoration(
                            labelText: 'Suburb',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: stateController,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: postcodeController,
                          decoration: const InputDecoration(
                            labelText: 'Postcode',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
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
              style: FilledButton.styleFrom(backgroundColor: _darkRed),
              onPressed: () {
                final customerName = businessNameController.text.trim();

                if (customerName.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter the customer business name.'),
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop({
                  'customer_name': customerName,
                  'legal_name': _nullable(legalNameController.text),
                  'abn': identificationType == 'abn'
                      ? _nullable(identificationNumberController.text)
                      : null,
                  'licence_number': identificationType == 'licence'
                      ? _nullable(identificationNumberController.text)
                      : null,
                  'contact_name': _nullable(contactNameController.text),
                  'phone': _nullable(phoneController.text),
                  'email': _nullable(emailController.text),
                  'delivery_address_line_1': _nullable(address1Controller.text),
                  'delivery_address_line_2': _nullable(address2Controller.text),
                  'delivery_suburb': _nullable(suburbController.text),
                  'delivery_state': _nullable(stateController.text),
                  'delivery_postcode': _nullable(postcodeController.text),
                });
              },
              child: const Text('Add Customer'),
            ),
          ],
        );
      },
    );

    businessNameController.dispose();
    legalNameController.dispose();
    identificationNumberController.dispose();
    contactNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    address1Controller.dispose();
    address2Controller.dispose();
    suburbController.dispose();
    stateController.dispose();
    postcodeController.dispose();

    if (result == null) return;

    setState(() => _isSavingCustomer = true);

    try {
      final inserted = await Supabase.instance.client
          .from('supplier_customer_accounts')
          .insert({
            'supplier_business_id': supplierBusinessId,
            'account_source': 'manual',
            ...result,
            'payment_method': 'cod',
            'payment_terms_days': 0,
            'issue_reporting_window_hours': 24,
            'active': true,
          })
          .select(
            'id, customer_name, legal_name, account_source, '
            'linked_butcher_business_id, account_reference, '
            'payment_method, payment_terms_days, contact_name, email, phone, '
            'abn, licence_number, '
            'delivery_address_line_1, delivery_address_line_2, '
            'delivery_suburb, delivery_state, delivery_postcode, active',
          )
          .single();

      final customer = Map<String, dynamic>.from(inserted);

      if (!mounted) return;

      setState(() {
        _customers = [..._customers, customer]
          ..sort(
            (a, b) => _customerName(
              a,
            ).toLowerCase().compareTo(_customerName(b).toLowerCase()),
          );
        _isSavingCustomer = false;
      });

      _selectCustomer(customer);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_customerName(customer)} added.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() => _isSavingCustomer = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _requestedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null || !mounted) return;
    setState(() => _requestedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _requestedTime ?? TimeOfDay.now(),
    );

    if (picked == null || !mounted) return;
    setState(() => _requestedTime = picked);
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Choose date';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _deliveryAddress(Map<String, dynamic> customer) {
    final parts = <String>[
      customer['delivery_address_line_1']?.toString().trim() ?? '',
      customer['delivery_address_line_2']?.toString().trim() ?? '',
      customer['delivery_suburb']?.toString().trim() ?? '',
      customer['delivery_state']?.toString().trim() ?? '',
      customer['delivery_postcode']?.toString().trim() ?? '',
    ].where((value) => value.isNotEmpty).toList();

    return parts.isEmpty ? 'No delivery address saved' : parts.join(', ');
  }

  void _continueToDraft() {
    final customer = _selectedCustomer;

    if (customer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a customer first.')));
      return;
    }

    if (_paymentMethod == 'account') {
      if (!_customerHasAccount(customer)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This customer is not approved for an account.'),
          ),
        );
        return;
      }

      _paymentTermsDays = _customerAccountTerms(customer);
    }

    if (_requestedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _fulfilmentMethod == 'pickup'
                ? 'Choose the pickup date.'
                : 'Choose the delivery date.',
          ),
        ),
      );
      return;
    }

    if (_requestedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _fulfilmentMethod == 'pickup'
                ? 'Choose the pickup time.'
                : 'Choose the delivery time.',
          ),
        ),
      );
      return;
    }

    if (_fulfilmentMethod == 'delivery' &&
        _deliveryAddress(customer) == 'No delivery address saved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This customer needs a delivery address before using delivery.',
          ),
        ),
      );
      return;
    }

    final time = _requestedTime!;
    final timeString =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';

    Navigator.of(context).pop(<String, dynamic>{
      'supplier_customer_account_id': customer['id']?.toString(),
      'customer': Map<String, dynamic>.from(customer),
      'customer_name': _customerName(customer),
      'payment_method': _paymentMethod,
      'payment_terms_days': _paymentMethod == 'account' ? _paymentTermsDays : 0,
      'fulfilment_method': _fulfilmentMethod,
      'requested_fulfilment_date': _requestedDate!
          .toIso8601String()
          .split('T')
          .first,
      'requested_fulfilment_time': timeString,
      'delivery_address': _fulfilmentMethod == 'delivery'
          ? _deliveryAddress(customer)
          : null,
      'delivery_notes': _deliveryNotesController.text.trim(),
      'internal_notes': _internalNotesController.text.trim(),
    });
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF666666), height: 1.4),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _customerSearchSection() {
    final matches = _matchingCustomers;
    final query = _customerSearchController.text.trim();

    return _sectionCard(
      title: '1. Customer',
      subtitle:
          'Search the customer you are selling to. Press Enter to show matching customers.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _customerSearchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _commitCustomerSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search customer name, ABN or phone',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Search',
                      onPressed: _commitCustomerSearch,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _isSavingCustomer ? null : _addCustomer,
                style: FilledButton.styleFrom(
                  backgroundColor: _darkRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 17,
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add Customer'),
              ),
            ],
          ),
          if (_selectedCustomer != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4E5E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: _darkRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Selling to ${_customerName(_selectedCustomer!)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _darkRed,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCustomer = null;
                        _customerSearchController.clear();
                        _searchCommitted = false;
                      });
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ],
          if (_selectedCustomer == null &&
              _searchCommitted &&
              query.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 270),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0DD)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Text(
                            'No customer found for "$query".',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _isSavingCustomer ? null : _addCustomer,
                            style: FilledButton.styleFrom(
                              backgroundColor: _darkRed,
                            ),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Add New Customer'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = matches[index];
                        final external =
                            customer['account_source']?.toString() == 'manual';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFF4E5E5),
                            child: Icon(
                              external
                                  ? Icons.person_outline
                                  : Icons.storefront_outlined,
                              color: _darkRed,
                            ),
                          ),
                          title: Text(
                            _customerName(customer),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [
                              external
                                  ? 'External customer'
                                  : 'CutLink customer',
                              if ((customer['phone']?.toString().trim() ?? '')
                                  .isNotEmpty)
                                customer['phone'].toString(),
                            ].join(' • '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _selectCustomer(customer),
                        );
                      },
                    ),
            ),
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isSavingCustomer ? null : _addCustomer,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add a different new customer'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _saleDetailsSection() {
    final customer = _selectedCustomer;

    return _sectionCard(
      title: '2. Payment & Fulfilment',
      subtitle:
          'Set how the customer will pay and when the order will be collected or delivered.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Payment method',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(
                value: 'cod',
                icon: Icon(Icons.payments_outlined),
                label: Text('COD'),
              ),
              const ButtonSegment(
                value: 'prepaid',
                icon: Icon(Icons.credit_card_outlined),
                label: Text('Prepaid'),
              ),
              if (customer != null && _customerHasAccount(customer))
                const ButtonSegment(
                  value: 'account',
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: Text('Account'),
                ),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: customer == null
                ? null
                : (selection) {
                    final value = selection.first;

                    if (value == 'account' && !_customerHasAccount(customer)) {
                      return;
                    }

                    setState(() {
                      _paymentMethod = value;
                      _paymentTermsDays = _customerHasAccount(customer)
                          ? _customerAccountTerms(customer)
                          : 0;
                    });
                  },
          ),
          if (customer != null && _customerHasAccount(customer)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0DD)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF35613B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Approved account customer • '
                      '${_customerAccountTerms(customer)} day terms',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF35523A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 18),
          const Text(
            'Fulfilment',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'pickup',
                icon: Icon(Icons.store_mall_directory_outlined),
                label: Text('Pickup'),
              ),
              ButtonSegment(
                value: 'delivery',
                icon: Icon(Icons.local_shipping_outlined),
                label: Text('Delivery'),
              ),
            ],
            selected: {_fulfilmentMethod},
            onSelectionChanged: customer == null
                ? null
                : (selection) {
                    setState(() => _fulfilmentMethod = selection.first);
                  },
          ),
          if (_fulfilmentMethod == 'delivery' && customer != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0DD)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _deliveryAddress(customer),
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 650;

              final dateButton = OutlinedButton.icon(
                onPressed: customer == null ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _requestedDate == null
                      ? (_fulfilmentMethod == 'pickup'
                            ? 'Pickup date'
                            : 'Delivery date')
                      : _dateLabel(_requestedDate),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              );

              final timeButton = OutlinedButton.icon(
                onPressed: customer == null ? null : _pickTime,
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  _requestedTime == null
                      ? (_fulfilmentMethod == 'pickup'
                            ? 'Pickup time'
                            : 'Delivery time')
                      : _requestedTime!.format(context),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              );

              if (narrow) {
                return Column(
                  children: [
                    dateButton,
                    const SizedBox(height: 10),
                    timeButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: dateButton),
                  const SizedBox(width: 12),
                  Expanded(child: timeButton),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _deliveryNotesController,
            enabled: customer != null,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: _fulfilmentMethod == 'pickup'
                  ? 'Pickup notes (optional)'
                  : 'Delivery notes (optional)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _internalNotesController,
            enabled: customer != null,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Internal sales notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
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
              const Icon(Icons.error_outline, size: 60, color: _darkRed),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loadPage,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Start New Sale',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose the customer and sale details first. '
                  'The next step will keep this sale open while you continue adding products from the Sales page.',
                  style: TextStyle(color: Color(0xFF666666), height: 1.4),
                ),
                const SizedBox(height: 22),
                _customerSearchSection(),
                const SizedBox(height: 16),
                _saleDetailsSection(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _selectedCustomer == null
                          ? null
                          : _continueToDraft,
                      style: FilledButton.styleFrom(
                        backgroundColor: _darkRed,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue to Sale'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
          'New Sale',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(),
    );
  }
}
