import '../../../shared/widgets/ios_density.dart';

import 'package:flutter/material.dart';

import '../../memberships/services/membership_service.dart';
import '../services/platform_admin_service.dart';
import 'admin_widgets.dart';
import 'admin_theme.dart';

/// Offer controls live inside Billing. Individual memberships live on each account.
class AdminMembershipsPanel extends StatefulWidget {
  const AdminMembershipsPanel({super.key});
  @override
  State<AdminMembershipsPanel> createState() => _AdminMembershipsPanelState();
}

class _AdminMembershipsPanelState extends State<AdminMembershipsPanel> {
  AdminRow _plans = {};
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await MembershipService.publicPricing();
      if (mounted) {
        setState(() {
          _plans = plans;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = PlatformAdminService.error(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _offer(String role, AdminRow plan) async {
    final opening = plan['offer_enabled'] != true;
    final saved = await adminForm(
      context,
      title: '${opening ? 'Open' : 'Pause'} $role founding offer',
      explanation: opening
          ? 'New approved businesses can receive founding places when you confirm their membership.'
          : 'New businesses stop receiving founding places. Existing members keep their offer.',
      fields: const [
        AdminField(
          'reason',
          'Reason (at least 8 characters)',
          required: true,
          lines: 2,
        ),
      ],
      submitLabel: opening ? 'Open offer' : 'Pause offer',
      submit: (data) async {
        await PlatformAdminService.action('set_founding_offer', {
          ...data,
          'role': role,
          'enabled': opening,
        });
      },
    );
    if (saved && mounted) {
      await _load();
    }
  }

  Widget _plan(String role) {
    final plan = MembershipService.map(_plans[role]);
    final supplier = role == 'supplier';
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supplier ? 'Suppliers' : 'Butchers',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const IosGap(height: 8),
          Text(
            '${MembershipService.money(plan['standard_total'])} / month',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const Text('AUD · GST included'),
          const Divider(height: 28),
          const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFF906B2B),
            size: 30,
          ),
          const IosGap(height: 8),
          const Text(
            'Founding offer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const Text('First 6 months free'),
          Text(
            'First 10: then ${MembershipService.money(plan['discounted_total'])}/month for a year.',
          ),
          const IosGap(height: 8),
          Text(
            '${plan['remaining'] ?? '—'} of ${plan['founding_limit'] ?? '—'} founding places left',
          ),
          Text(
            plan['offer_enabled'] == true
                ? 'Open for new members'
                : 'Paused for new members',
          ),
          const IosGap(height: 10),
          OutlinedButton(
            onPressed: plan.isEmpty ? null : () => _offer(role, plan),
            child: Text(
              plan['offer_enabled'] == true ? 'Pause offer' : 'Open offer',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AdminLoading();
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Regular prices & founding offers',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const IosGap(height: 6),
        const Text(
          'Start or change a business’s membership from its billing account.',
        ),
        const IosGap(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 700 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.4) {
              return Column(children: [_plan('supplier'), _plan('butcher')]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _plan('supplier')),
                const SizedBox(width: 16),
                Expanded(child: _plan('butcher')),
              ],
            );
          },
        ),
        const IosGap(height: 10),
        const Text(
          'Remaining founding places: 6 months free, then the regular monthly price. Places follow confirmation order and are not recycled.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh offers'),
          ),
        ),
      ],
    );
  }
}
