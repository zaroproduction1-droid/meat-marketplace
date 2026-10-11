import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/presentation/subscription_billing_page.dart';
import '../services/membership_service.dart';

class MembershipSettingsLink extends StatefulWidget {
  const MembershipSettingsLink({super.key});
  @override
  State<MembershipSettingsLink> createState() => _MembershipSettingsLinkState();
}

class _MembershipSettingsLinkState extends State<MembershipSettingsLink> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) {
      return;
    }
    setState(() => _opening = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        return;
      }
      final rows = await client
          .from('business_memberships')
          .select('business_id,businesses(trading_name,legal_name)')
          .eq('user_id', uid)
          .inFilter('status', ['active', 'suspended'])
          .limit(50);
      if (!mounted) {
        return;
      }
      if (rows.isEmpty) {
        throw StateError('No business membership');
      }
      String? id;
      if (rows.length == 1) {
        id = '${rows.first['business_id']}';
      } else {
        id = await showDialog<String>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: const Text('Choose your business'),
            children: [
              for (var i = 0; i < rows.length; i++)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop('${rows[i]['business_id']}'),
                  child: Text(
                    '${MembershipService.map(rows[i]['businesses'])['trading_name'] ?? MembershipService.map(rows[i]['businesses'])['legal_name'] ?? 'Business ${i + 1}'}',
                  ),
                ),
            ],
          ),
        );
      }
      final businessId = id;
      if (!mounted || businessId == null) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubscriptionBillingPage(businessId: businessId),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open membership. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.workspace_premium_outlined),
    title: const Text('CutLink membership'),
    subtitle: const Text(
      'Your plan, founding timeline and subscription invoices',
    ),
    trailing: _opening
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.chevron_right),
    onTap: _opening ? null : _open,
  );
}
