import 'package:flutter/material.dart';

import 'registration_type_page.dart';

class AccountDetailsPage extends StatefulWidget {
  const AccountDetailsPage({super.key, required this.businessType});

  final BusinessType businessType;

  @override
  State<AccountDetailsPage> createState() => _AccountDetailsPageState();
}

class _AccountDetailsPageState extends State<AccountDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get businessTypeName {
    return widget.businessType == BusinessType.supplier
        ? 'Supplier'
        : 'Butcher';
  }

  void continueRegistration() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$businessTypeName account details are valid. '
          'Business details will be added next.',
        ),
      ),
    );
  }

  String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $fieldName.';
    }

    return null;
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Please enter your email address.';
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  String? validatePhone(String? value) {
    final phone = value?.replaceAll(RegExp(r'\s+'), '') ?? '';

    if (phone.isEmpty) {
      return 'Please enter your phone number.';
    }

    if (phone.length < 8) {
      return 'Please enter a valid phone number.';
    }

    return null;
  }

  String? validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Please enter a password.';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Include at least one capital letter.';
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one number.';
    }

    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }

    if (value != _passwordController.text) {
      return 'The passwords do not match.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    const darkRed = Color(0xFF741C1C);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('$businessTypeName registration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create your login details',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You are registering as a $businessTypeName business.',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF5E5E5E),
                        ),
                      ),
                      const SizedBox(height: 32),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 550;

                          final firstNameField = TextFormField(
                            controller: _firstNameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'First name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              return validateRequired(value, 'first name');
                            },
                          );

                          final lastNameField = TextFormField(
                            controller: _lastNameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Last name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              return validateRequired(value, 'last name');
                            },
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                firstNameField,
                                const SizedBox(height: 18),
                                lastNameField,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: firstNameField),
                              const SizedBox(width: 18),
                              Expanded(child: lastNameField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'name@business.com.au',
                          border: OutlineInputBorder(),
                        ),
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          hintText: '04XX XXX XXX',
                          border: OutlineInputBorder(),
                        ),
                        validator: validatePhone,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText:
                              'At least 8 characters, one capital letter and one number.',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _hidePassword = !_hidePassword;
                              });
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: validatePassword,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _hideConfirmPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _hideConfirmPassword = !_hideConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _hideConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: validateConfirmPassword,
                        onFieldSubmitted: (_) {
                          continueRegistration();
                        },
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: continueRegistration,
                        style: FilledButton.styleFrom(
                          backgroundColor: darkRed,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Back to business type'),
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
