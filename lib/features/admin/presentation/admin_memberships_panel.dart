import 'dart:async';

import 'package:flutter/material.dart';

import '../../memberships/services/membership_service.dart';
import '../services/platform_admin_service.dart';
import 'admin_widgets.dart';
import 'admin_business_page.dart';

class AdminMembershipsPanel extends StatefulWidget {
  const AdminMembershipsPanel({super.key});
  @override
  State<AdminMembershipsPanel> createState() => _AdminMembershipsPanelState();
}

class _AdminMembershipsPanelState extends State<AdminMembershipsPanel> {
  AdminRow _data = {};
  List<AdminRow> _rows = [];
  final _searchController = TextEditingController();
  String _search = '';
  String? _error;
  bool _loading = true;
  int _offset = 0, _request = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await MembershipService.admin(
        search: _search,
        offset: _offset,
      );
      if (mounted && request == _request) {
        setState(() {
          _data = data;
          _rows = PlatformAdminService.rows(data['rows']);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _error =
              'Could not load memberships. Check access and that the membership migration has been applied.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _offer(String role, AdminRow plan) async {
    final enabling = plan['offer_enabled'] != true;
    final changed = await adminForm(
      context,
      title: '${enabling ? 'Open' : 'Pause'} $role founding enrolment',
      explanation:
          'Opening permits only deliberate genuine-business confirmations. Existing members retain their agreed timeline. '
          'Pausing stops new founding allocations; it does not cancel existing offers.',
      fields: const [
        AdminField(
          'reason',
          'Reason (8–1000 characters)',
          required: true,
          lines: 3,
        ),
      ],
      submitLabel: enabling ? 'Confirm opening' : 'Confirm pause',
      submit: (data) => PlatformAdminService.action('set_founding_offer', {
        ...data,
        'role': role,
        'enabled': enabling,
      }).then((_) {}),
    );
    if (changed && mounted) {
      await _load();
    }
  }

  Future<void> _enrol(AdminRow row) async {
    final changed = await adminForm(
      context,
      title: 'Confirm ${row['business']} membership',
      explanation:
          'Confirm this is a genuine active approved business. Test/demo/admin businesses must not use founding places. '
          'Activation starts today in Sydney. Founding places follow confirmation order; if full, standard pricing applies. '
          'Existing invoices covering this or a future period must be resolved first.',
      initial: const {'selection': 'founding_if_available'},
      fields: const [
        AdminField(
          'genuine_business_confirmed',
          'I have checked this is a genuine business',
          required: true,
          options: ['true'],
        ),
        AdminField(
          'selection',
          'Membership',
          required: true,
          options: ['founding_if_available', 'standard'],
        ),
        AdminField(
          'reason',
          'Review reason (8–1000 characters)',
          required: true,
          lines: 3,
        ),
      ],
      submitLabel: 'Confirm activation',
      submit: (data) => PlatformAdminService.action('activate_membership', {
        ...data,
        'business_id': row['business_id'],
      }).then((_) {}),
    );
    if (changed && mounted) {
      await _load();
    }
  }

  Future<void> _change(AdminRow row, {required bool revoke}) async {
    final membership = MembershipService.map(row['membership']);
    final changed = await adminForm(
      context,
      title: revoke ? 'Revoke founding eligibility' : 'Change founding tier',
      explanation: revoke
          ? 'The allocated position stays recorded and is not reused. Standard pricing applies to future billing. '
                'Invoices already issued are unchanged. This does not suspend the business.'
          : 'This changes the offer without restarting its original clock or changing its position. '
                'The ten-place first-tier limit still applies. Existing invoices are unchanged.',
      initial: {'tier': membership['tier']},
      fields: [
        if (!revoke)
          const AdminField(
            'tier',
            'Founding tier',
            required: true,
            options: ['founding_tier_1', 'founding_tier_2'],
          ),
        const AdminField(
          'reason',
          'Reason (8–1000 characters)',
          required: true,
          lines: 3,
        ),
      ],
      submitLabel: revoke ? 'Confirm revocation' : 'Confirm tier change',
      submit: (data) => PlatformAdminService.action(
        revoke ? 'revoke_founding' : 'set_founding_tier',
        {...data, 'business_id': row['business_id']},
      ).then((_) {}),
    );
    if (changed && mounted) {
      await _load();
    }
  }

  Widget _overview(String role) {
    final plan = MembershipService.map(
      MembershipService.map(_data['plans'])[role],
    );
    return SizedBox(
      width: 340,
      child: AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role == 'supplier' ? 'Suppliers' : 'Butchers',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              '${MembershipService.money(plan['standard_total'])} AUD / month · GST inclusive',
            ),
            const SizedBox(height: 8),
            Text(
              'Allocated ${plan['allocated'] ?? '—'} of ${plan['founding_limit'] ?? '—'} · Remaining ${plan['remaining'] ?? '—'}',
            ),
            Text(
              'First tier: ${plan['first_tier_limit'] ?? '—'} · Second tier: ${role == 'supplier' ? 5 : 15}',
            ),
            Text(
              plan['offer_enabled'] == true
                  ? 'Founding enrolment open'
                  : 'Founding enrolment paused',
            ),
            TextButton(
              onPressed: plan.isEmpty ? null : () => _offer(role, plan),
              child: Text(
                plan['offer_enabled'] == true
                    ? 'Pause enrolment'
                    : 'Open enrolment',
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataCell _cell(String value) => DataCell(Text(value));
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [_overview('supplier'), _overview('butcher')],
        ),
        const SizedBox(height: 12),
        const Text(
          'Existing businesses are unallocated until reviewed. Revoked places remain in the allocated count.',
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search business or role',
            prefixIcon: Icon(Icons.search),
          ),
          controller: _searchController,
          onChanged: (value) {
            _search = value;
            _offset = 0;
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), _load);
          },
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Business')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Position / tier')),
              DataColumn(label: Text('Approved')),
              DataColumn(label: Text('Offer start')),
              DataColumn(label: Text('Free ends')),
              DataColumn(label: Text('50% ends')),
              DataColumn(label: Text('Current / standard')),
              DataColumn(label: Text('Membership stage')),
              DataColumn(label: Text('Billing / payment')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Review')),
            ],
            rows: [for (final row in _rows.take(50)) _row(row)],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _offset == 0
                  ? null
                  : () {
                      _offset -= 50;
                      _load();
                    },
              child: const Text('Previous'),
            ),
            Text('Page ${_offset ~/ 50 + 1}'),
            TextButton(
              onPressed: _rows.length > 50
                  ? () {
                      _offset += 50;
                      _load();
                    }
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }

  DataRow _row(AdminRow row) {
    final m = MembershipService.map(row['membership']);
    final founding = m['position'] != null;
    final revoked = m['revoked_at'] != null;
    final eligible =
        row['active'] == true &&
        row['verification_status'] == 'approved' &&
        row['admin_business'] != true;
    return DataRow(
      cells: [
        DataCell(
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AdminBusinessPage(businessId: '${row['business_id']}'),
              ),
            ),
            child: Text('${row['business']}'),
          ),
        ),
        _cell('${row['role']}'),
        _cell(
          founding
              ? '#${m['position']} · ${m['tier']}'.replaceAll('_', ' ')
              : m.isEmpty
              ? 'Unallocated'
              : 'Standard',
        ),
        _cell(
          m['approved_on'] != null
              ? PlatformAdminService.date(m['approved_on'])
              : m['approval_confirmed_on'] != null
              ? 'Confirmed ${PlatformAdminService.date(m['approval_confirmed_on'])}'
              : '—',
        ),
        _cell(PlatformAdminService.date(m['started_on'])),
        _cell(PlatformAdminService.date(m['free_end'])),
        _cell(PlatformAdminService.date(m['discount_end'])),
        _cell(
          m.isEmpty
              ? 'Legacy / not enrolled'
              : '${MembershipService.money(m['effective_total'])} / ${MembershipService.money(m['standard_total'])}',
        ),
        _cell(MembershipService.stage(m['stage'])),
        _cell(
          '${row['subscription_status'] ?? 'Not configured'} · ${PlatformAdminService.amount(row['overdue']) > 0
              ? 'Past due'
              : PlatformAdminService.amount(row['outstanding']) > 0
              ? 'Payment pending'
              : 'No balance'}',
        ),
        _cell(
          '${row['verification_status']}${revoked ? ' · offer revoked' : ''}${row['admin_business'] == true ? ' · admin business' : ''}${row['review_state'] == 'development_business' ? ' · development' : ''}',
        ),
        DataCell(
          m.isEmpty
              ? TextButton(
                  onPressed: eligible ? () => _enrol(row) : null,
                  child: const Text('Confirm membership'),
                )
              : founding && !revoked
              ? PopupMenuButton<String>(
                  tooltip: 'Membership actions',
                  onSelected: (action) =>
                      _change(row, revoke: action == 'revoke'),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'tier', child: Text('Change tier')),
                    PopupMenuItem(value: 'revoke', child: Text('Revoke offer')),
                  ],
                )
              : const Text('Tracked'),
        ),
      ],
    );
  }
}
