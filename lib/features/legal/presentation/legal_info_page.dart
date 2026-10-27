import '../../../shared/widgets/ios_density.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/supplier_photo_policy.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Pre-launch notices. Replace operator/contact details before public release.
class LegalInfoPage extends StatefulWidget {
  const LegalInfoPage({super.key});
  static const version = 'development-2026-10-17';
  @override
  State<LegalInfoPage> createState() => _LegalInfoPageState();
}

class _LegalInfoPageState extends State<LegalInfoPage> {
  bool _sending = false;
  Future<void> _request(String kind) async {
    if (_sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        throw const FormatException(
          'Sign in and open these notices to submit a request. If you cannot sign in, contact the project owner through your existing contact channel.',
        );
      }
      final memberships = await client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', client.auth.currentUser!.id)
          .inFilter('status', ['active', 'suspended'])
          .limit(50);
      final ids = memberships
          .map((row) => row['business_id'].toString())
          .toSet()
          .toList();
      if (ids.isEmpty) {
        throw const FormatException(
          'No business membership was found. Contact the project owner through your existing contact channel.',
        );
      }
      if (!mounted) {
        return;
      }
      final businesses = await client
          .from('businesses')
          .select('id,trading_name,legal_name')
          .inFilter('id', ids);
      if (!mounted) {
        return;
      }
      final selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text('Request $kind'),
          children: [
            const IosPadding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose the business for this request. CutLink Support will verify your identity and review it. Deletion is subject to financial, dispute and other lawful retention requirements; this does not immediately erase your account.',
              ),
            ),
            for (final id in ids)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, id),
                child: Text(
                  businesses
                          .where((row) => row['id'] == id)
                          .map(
                            (row) =>
                                row['trading_name'] ??
                                row['legal_name'] ??
                                'Your business',
                          )
                          .firstOrNull
                          ?.toString() ??
                      'Your business',
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (selected == null) {
        return;
      }
      await client.rpc(
        'create_support_ticket',
        params: {
          'p_business_id': selected,
          'p_subject': 'Privacy request: $kind',
          'p_category': 'account',
          'p_priority': 'normal',
          'p_message':
              'I request $kind for my personal information and account. Please verify my identity, explain applicable retention requirements and respond through this support ticket. Notice version: ${LegalInfoPage.version}.',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request submitted to CutLink Support. Track it in Support Centre.',
            ),
          ),
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The request could not be submitted. Try again or contact the project owner through your existing contact channel.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  static const notices = <String, String>{
    'Supplier photos, copyright and content reports': SupplierPhotoPolicy.terms,
    'Privacy notice':
        'CutLink is a pre-launch business platform in NSW, Australia. CutlinkTrade is the intended web identity; the legal operator and public privacy contact are still to be confirmed. These development notices are not a statement that the service is ready for public launch.\n\nWe process login and contact details, business profiles and addresses, wholesale products and prices, photo-rights confirmations and content reports, orders, invoices, payment records, delivery details, trade applications and their supporting documents, support messages and technical activity needed to operate the service. Provide only information needed for the transaction. Do not upload passwords, identity documents or consumer credit reports unless a specific lawful, necessary process has been established.\n\nInformation is shared with the relevant trading businesses and authorised support staff according to business access controls. Publicly featured business names, logos and product photos are public. Exact supplier stock quantities and available stock weights are restricted to that supplier\'s authorised members; buyers see availability labels. Authorised administrators may access business information for a legitimate support, security or compliance purpose, with trade-record access logged in the admin workspace. Ordinary database-owner access is not made invisible by these app controls. Private support and trade documents require authorised access. Supabase provides authentication, database and file storage; the connected project is in Sydney. Any further provider, overseas processing and retention details must be confirmed before launch.\n\nCutLink does not store card credentials or transfer money through the payment-recording screens. Keep passwords and private API keys out of uploads and messages. We keep records needed for active business services and lawful financial or dispute obligations; retention periods and recovery procedures are still being verified. Request access, correction or deletion below. We verify requests and explain information that must be retained. Before launch the operator must publish a working contact, complaint process and final retention schedule.',
    'Terms of use':
        'Development terms: CutLink connects wholesale suppliers and butchers and provides inventory, ordering, invoicing, accounts and delivery tools. Use is intended for adults aged 18 or over who are authorised to act for a business. Keep login credentials private and provide accurate business and licensing information. Approval in CutLink is platform access approval; it does not independently guarantee food safety, product quality, creditworthiness or regulatory compliance.\n\nThe trading parties are responsible for agreeing product specifications, availability, catch-weight pricing, applicable tax, delivery charges, payment terms and fulfilment. Review these before confirming an order. Recording payment in CutLink is not a bank transfer or card charge. Do not upload unlawful content, impersonate a business or attempt unauthorised access.\n\nOperator identity, service charges, subscription cancellation, suspension, dispute procedures and final contractual terms must be confirmed before public launch or accepting platform fees. Nothing in these notices excludes rights or remedies that cannot lawfully be excluded under Australian law.',
    'Refund and dispute notice':
        'Development notice: platform subscription refund and cancellation terms have not yet been finalised. Do not rely on an unpublished platform refund policy. Meat-order issues are handled between the supplier and buyer through the order issue, credit and refund-recording workflows. Raise an issue promptly and preserve relevant records. A credit note or recorded refund does not itself transfer money.\n\nAny launch policy must clearly distinguish platform fees from supplier transactions and disclose charges and cancellation terms before purchase. Applicable non-excludable Australian rights remain available. Wholesale resale transactions may have different legal treatment; CutLink must not present a blanket no-refunds rule.',
    'Cookies and browser storage':
        'The inspected app uses storage needed for sign-in sessions and platform operation. It includes an embedded local video and application assets. No advertising or analytics tracking SDK was found in the supplied dependencies. Essential session storage is needed to stay signed in; sign out before using a shared device. Payment recording also saves hashed request fingerprints and random retry keys on this device to help avoid duplicates after an uncertain response or refresh. It does not save payment amounts, names, bank details or notes in that retry storage. Clearing site data removes the local session and retry keys but does not delete your account or business records. Check account history for any unconfirmed payment before clearing site data, changing devices or recording it again with different details.\n\nNo optional tracking consent banner is added while there are no optional trackers. If analytics, advertising or third-party embeds are introduced, audit their actual behaviour, publish the relevant details and gate optional tracking behind a clear choice where required. Do not claim that every browser request has been verified; renderer and hosting requests need a release-build check before launch.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy & policies')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'CutLink development notices',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const IosGap(height: 12),
            const Text(
              'Pre-launch • NSW, Australia • Version development-2026-10-17',
            ),
            const IosGap(height: 16),
            for (final entry in notices.entries)
              ExpansionTile(
                title: Text(entry.key),
                childrenPadding: const EdgeInsets.all(16),
                children: [SelectableText(entry.value)],
              ),
            const IosGap(height: 20),
            const Text(
              'Your information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const IosGap(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final kind in ['access', 'correction', 'deletion'])
                  OutlinedButton(
                    onPressed: _sending ? null : () => _request(kind),
                    child: Text('Request $kind'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
