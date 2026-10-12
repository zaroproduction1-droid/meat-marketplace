import 'package:flutter/material.dart';

import '../../memberships/services/membership_service.dart';
import '../services/platform_admin_service.dart';
import 'admin_widgets.dart';

Future<bool> confirmCutLinkMembership(
  BuildContext context,
  AdminRow business,
) async {
  AdminRow plan;
  try {
    final pricing = await MembershipService.publicPricing();
    plan = MembershipService.map(
      pricing[business['business_type'] ?? business['role']],
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PlatformAdminService.error(error))),
      );
    }
    return false;
  }
  if (!context.mounted) {
    return false;
  }
  final founding =
      plan['offer_enabled'] == true &&
      PlatformAdminService.amount(plan['remaining']) > 0;
  return adminForm(
    context,
    title: 'Start ${PlatformAdminService.name(business)} membership',
    explanation: founding
        ? 'Founding: your first 6 months are free. The first 10 confirmed businesses also get a half-price year. The offer starts today. This creates the billing account automatically.'
        : 'Standard membership starts today. This creates the billing account automatically. Founding enrolment is paused or full.',
    initial: {'selection': founding ? 'founding_if_available' : 'standard'},
    fields: [
      const AdminField(
        'genuine_business_confirmed',
        'I have checked this is a real business, not a test or admin account.',
        required: true,
        checkbox: true,
      ),
      AdminField(
        'selection',
        'Choose membership',
        required: true,
        options: [if (founding) 'founding_if_available', 'standard'],
        optionLabels: const {
          'founding_if_available': 'Founding offer, if a place is available',
          'standard': 'Standard monthly membership',
        },
      ),
      const AdminField(
        'reason',
        'Reason for approval (at least 8 characters)',
        required: true,
        lines: 2,
      ),
    ],
    submitLabel: 'Start membership',
    submit: (data) async {
      await PlatformAdminService.action('activate_membership', {
        ...data,
        'business_id': business['id'] ?? business['business_id'],
      });
    },
  );
}

Future<bool> changeCutLinkFoundingOffer(
  BuildContext context,
  AdminRow business,
  AdminRow membership, {
  required bool revoke,
}) => adminForm(
  context,
  title: revoke ? 'End founding discount' : 'Change founding offer',
  explanation: revoke
      ? 'Future billing returns to the regular price. Existing invoices stay unchanged. The founding place is retained and business access stays unchanged.'
      : 'The original start date and founding place stay the same. Existing invoices stay unchanged. The first-10 limit still applies.',
  initial: {'tier': membership['tier']},
  fields: [
    if (!revoke)
      const AdminField(
        'tier',
        'Offer',
        required: true,
        options: ['founding_tier_1', 'founding_tier_2'],
        optionLabels: {
          'founding_tier_1': '6 months free + a half-price year',
          'founding_tier_2': '6 months free, then regular price',
        },
      ),
    const AdminField(
      'reason',
      'Reason (at least 8 characters)',
      required: true,
      lines: 2,
    ),
  ],
  submitLabel: revoke ? 'End discount' : 'Save offer',
  submit: (data) async {
    await PlatformAdminService.action(
      revoke ? 'revoke_founding' : 'set_founding_tier',
      {...data, 'business_id': business['id'] ?? business['business_id']},
    );
  },
);

Future<bool> editCutLinkInvoiceDetails(
  BuildContext context, {
  AdminRow? current,
}) async {
  AdminRow details;
  try {
    details =
        current ??
        PlatformAdminService.map(await PlatformAdminService.query('settings'));
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PlatformAdminService.error(error))),
      );
    }
    return false;
  }
  if (!context.mounted) {
    return false;
  }
  return adminForm(
    context,
    title: 'Your CutLink invoice details',
    explanation:
        'Your business details and bank instructions appear on new CutLink invoices. Already issued invoices keep their original details.',
    initial: {
      ...details,
      'gst_registered': '${details['gst_registered'] ?? false}',
    },
    fields: const [
      AdminField('legal_name', 'Legal business name', required: true),
      AdminField('abn', 'ABN'),
      AdminField('email', 'Billing email', required: true),
      AdminField('phone', 'Phone'),
      AdminField('address', 'Business address', lines: 2),
      AdminField(
        'gst_registered',
        'Are you registered for GST?',
        required: true,
        options: ['false', 'true'],
        optionLabels: {'false': 'No', 'true': 'Yes'},
      ),
      AdminField('bank_name', 'Bank'),
      AdminField('account_name', 'Bank account name'),
      AdminField('bsb', 'BSB'),
      AdminField('account_number', 'Bank account number'),
      AdminField('payment_instructions', 'Payment instructions', lines: 2),
    ],
    submit: (data) async {
      await PlatformAdminService.action('save_settings', {
        'details': {
          ...details,
          ...data,
          'gst_registered': data['gst_registered'] == 'true',
        },
      });
    },
  );
}
