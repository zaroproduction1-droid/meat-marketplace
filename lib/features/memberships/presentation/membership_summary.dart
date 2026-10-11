import 'package:flutter/material.dart';

import '../services/membership_service.dart';

class MembershipSummary extends StatelessWidget {
  const MembershipSummary({super.key, required this.membership});
  final Map<String, dynamic> membership;
  String _date(dynamic value) {
    final date = DateTime.tryParse('$value');
    return date == null ? '—' : '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (membership.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Your CutLink membership is awaiting admin review.'),
        ),
      );
    }
    final legacy = membership['legacy'] == true;
    final price =
        membership['effective_total'] ?? membership['scheduled_total'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              legacy
                  ? 'Existing CutLink subscription'
                  : MembershipService.stage(membership['stage']),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${MembershipService.money(price)} AUD / month · ${membership['gst_inclusive'] == true ? 'GST inclusive' : 'excluding GST'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('Billing status: ${membership['subscription_status']}'),
            if (!legacy) ...[
              Text(
                'Standard price: ${MembershipService.money(membership['standard_total'])} AUD / month, GST inclusive',
              ),
              if (membership['position'] != null)
                Text(
                  'Founding ${membership['role']} #${membership['position']}',
                ),
              Text('Membership started: ${_date(membership['started_on'])}'),
              if (membership['free_end'] != null)
                Text('Free period ends: ${_date(membership['free_end'])}'),
              if (membership['discount_end'] != null)
                Text('50% period ends: ${_date(membership['discount_end'])}'),
              if (membership['tier'] == 'founding_tier_1')
                Text(
                  'Months 1–6: free · Months 7–18: ${MembershipService.money((num.tryParse('${membership['standard_total']}') ?? 0) / 2)}/month · Month 19 onward: ${MembershipService.money(membership['standard_total'])}/month.',
                ),
              if (membership['tier'] == 'founding_tier_2')
                Text(
                  'Months 1–6: free · Month 7 onward: ${MembershipService.money(membership['standard_total'])}/month.',
                ),
              if (membership['revoked_at'] != null)
                const Text(
                  'Founding eligibility has been revoked. Standard membership pricing applies.',
                ),
            ],
          ],
        ),
      ),
    );
  }
}
