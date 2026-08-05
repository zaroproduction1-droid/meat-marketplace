import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'registration_type_page.dart';

class BusinessDetailsPage extends StatefulWidget {
  const BusinessDetailsPage({super.key, required this.businessType});

  final BusinessType businessType;

  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  final _legalNameController = TextEditingController();
  final _tradingNameController = TextEditingController();
  final _abnController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _suburbController = TextEditingController();
  final _postcodeController = TextEditingController();

  bool _isLoading = false;
  String _state = 'NSW';

  @override
  void initState() {
    super.initState();

    final user = Supabase.instance.client.auth.currentUser;

    _businessEmailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _tradingNameController.dispose();
    _abnController.dispose();
    _businessEmailController.dispose();
    _businessPhoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _suburbController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName.';
    }

    return null;
  }

  String? _validateAbn(String? value) {
    final abn = value?.replaceAll(RegExp(r'\s+'), '') ?? '';

    if (abn.isEmpty) {
      return 'Please enter the ABN.';
    }

    if (!RegExp(r'^\d{11}$').hasMatch(abn)) {
      return 'ABN must contain exactly 11 digits.';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Please enter the business email.';
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  String? _validatePostcode(String? value) {
    final postcode = value?.trim() ?? '';

    if (!RegExp(r'^\d{4}$').hasMatch(postcode)) {
      return 'Please enter a four-digit postcode.';
    }

    return null;
  }

  Future<void> _submitBusinessDetails() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.rpc(
        'create_business_for_current_user',
        params: {
          'p_business_type': widget.businessType.name,
          'p_legal_name': _legalNameController.text,
          'p_trading_name': _tradingNameController.text,
          'p_abn': _abnController.text,
          'p_business_email': _businessEmailController.text,
          'p_business_phone': _businessPhoneController.text,
          'p_address_line_1': _addressLine1Controller.text,
          'p_address_line_2': _addressLine2Controller.text,
          'p_suburb': _suburbController.text,
          'p_state': _state,
          'p_postcode': _postcodeController.text,
        },
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Business details submitted'),
            content: const Text(
              'Your business account has been created and is now pending verification.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while saving the business.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkRed = Color(0xFF741C1C);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Business details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Tell us about your business',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'These details will be reviewed before marketplace access is approved.',
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _legalNameController,
                        decoration: const InputDecoration(
                          labelText: 'Legal business name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          return _requiredValidator(
                            value,
                            'the legal business name',
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _tradingNameController,
                        decoration: const InputDecoration(
                          labelText: 'Trading name (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _abnController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ABN',
                          hintText: '11 digits',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateAbn,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _businessEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Business email',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _businessPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Business phone',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          return _requiredValidator(
                            value,
                            'the business phone number',
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _addressLine1Controller,
                        decoration: const InputDecoration(
                          labelText: 'Address line 1',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          return _requiredValidator(
                            value,
                            'the business address',
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _addressLine2Controller,
                        decoration: const InputDecoration(
                          labelText: 'Address line 2 (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _suburbController,
                        decoration: const InputDecoration(
                          labelText: 'Suburb',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          return _requiredValidator(value, 'the suburb');
                        },
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _state,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'NSW', child: Text('NSW')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _state = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _postcodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Postcode',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validatePostcode,
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _isLoading ? null : _submitBusinessDetails,
                        style: FilledButton.styleFrom(
                          backgroundColor: darkRed,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit business details',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
