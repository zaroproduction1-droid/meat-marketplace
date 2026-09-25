import '../../../shared/widgets/phone_layout.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pending_verification_page.dart';
import 'business_details_page.dart';
import 'registration_type_page.dart';
import '../../dashboard/presentation/business_dashboard_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, this.businessType, this.restoreSession = false});

  final BusinessType? businessType;
  final bool restoreSession;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.restoreSession) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSession());
    }
  }

  Future<void> _restoreSession() async {
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (auth.currentSession!.isExpired) await auth.refreshSession();
      if (!mounted) return;
      await _openAccount();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not restore your session. Check your connection and retry.',
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              setState(() => _isLoading = true);
              _restoreSession();
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Please enter your email address.';
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }

    return null;
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      await _openAccount();
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));

      debugPrint('Supabase sign-in error: ${error.message}');
      debugPrint('Supabase error code: ${error.code}');
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));

      debugPrint('Unexpected sign-in error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _openAccount() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('Unable to find the signed-in user.');
    }

    final memberships = await Supabase.instance.client
        .from('business_memberships')
        .select('business_id, businesses(verification_status)')
        .eq('user_id', user.id)
        .limit(1);

    if (!mounted) {
      return;
    }

    if (memberships.isEmpty) {
      BusinessType? selectedBusinessType = widget.businessType;

      final metadataType = user.userMetadata?['business_type'] as String?;

      if (selectedBusinessType == null) {
        if (metadataType == 'supplier') {
          selectedBusinessType = BusinessType.supplier;
        } else if (metadataType == 'butcher') {
          selectedBusinessType = BusinessType.butcher;
        }
      }

      if (selectedBusinessType == null) {
        throw Exception('The business type could not be identified.');
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              BusinessDetailsPage(businessType: selectedBusinessType!),
        ),
      );

      return;
    }

    final membership = Map<String, dynamic>.from(memberships.first);

    final businessData = Map<String, dynamic>.from(membership['businesses']);

    final verificationStatus = businessData['verification_status'] as String?;

    if (verificationStatus == 'pending') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const PendingVerificationPage(),
        ),
        (route) => route.isFirst,
      );

      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const BusinessDashboardPage()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkRed = Color(0xFF741C1C);

    if (widget.restoreSession && _isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 18),
              Text('Opening your CutLink account…'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: phoneAppBar(
        context,
        AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'Sign in',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sign in using your confirmed email address.',
                        style: TextStyle(color: Color(0xFF5E5E5E)),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Password',
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
                        validator: _validatePassword,
                        onFieldSubmitted: (_) {
                          _signIn();
                        },
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _isLoading ? null : _signIn,
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
                                'Sign in',
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
