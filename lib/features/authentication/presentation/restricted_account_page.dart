import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';
import '../../../shared/navigation/page_location.dart';
import '../../dashboard/presentation/business_dashboard_page.dart';
import '../../support/presentation/support_center_page.dart';
import 'pending_verification_page.dart';
import 'sign_in_page.dart';

/// Authentication remains valid for contacting support, while trading is blocked.
class RestrictedAccountPage extends StatefulWidget {
  const RestrictedAccountPage({super.key, required this.access});
  final Map<String, dynamic> access;
  @override
  State<RestrictedAccountPage> createState() => _RestrictedAccountPageState();
}

class _RestrictedAccountPageState extends State<RestrictedAccountPage> {
  late Map<String, dynamic> _access = widget.access;
  bool _busy = false;
  String? _error;
  Future<void> _check() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.rpc(
        'get_my_cutlink_access',
      );
      final access = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (!mounted) {
        return;
      }
      if (access['can_enter'] == true || access['is_admin'] == true) {
        PageLocation.clear();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const BusinessDashboardPage(),
          ),
          (_) => false,
        );
      } else if (access['pending'] == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const PendingVerificationPage(),
          ),
        );
      } else {
        setState(() => _access = access);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'Could not check your account. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      PageLocation.clear();
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const SignInPage()),
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not sign out. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final restrictions =
        (_access['restrictions'] is List
                ? _access['restrictions'] as List
                : const [])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
    return CutLinkWorkspaceTheme(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 52,
                      color: CutLinkWorkspaceTheme.red,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      restrictions.any((r) => r['status'] == 'suspended')
                          ? 'Account suspended'
                          : 'Account access restricted',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You are signed in. Your business workspace is currently unavailable, but you can still contact CutLink Support.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    for (final r in restrictions)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${r['business_name'] ?? 'Your business'}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Reason',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                '${r['reason'] ?? 'Please contact CutLink Support for details.'}',
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => SupportCenterPage(
                                            businessId: '${r['business_id']}',
                                            adminMode: false,
                                          ),
                                        ),
                                      ),
                                icon: const Icon(Icons.support_agent),
                                label: const Text('Contact CutLink Support'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _check,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            _busy ? 'Checking…' : 'Check access again',
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _signOut,
                          child: const Text('Sign out / back to login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
