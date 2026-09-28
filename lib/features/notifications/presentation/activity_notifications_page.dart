import '../../../shared/widgets/cutlink_workspace_theme.dart';
import 'notification_activity_tile.dart';
import '../../customers/presentation/supplier_customer_requests_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/phone_layout.dart';
import '../../../shared/widgets/workspace_back_button.dart';
import '../../../shared/widgets/order_issue_chat.dart';
import '../../orders/presentation/supplier_invoice_page.dart';
import '../../orders/presentation/supplier_marketplace_order_detail_page.dart';
import '../../orders/presentation/submitted_orders_page.dart';
import '../../orders/presentation/butcher_accounts_page.dart';
import '../../customers/presentation/supplier_customer_account_page.dart';
import '../../credits/presentation/credit_notes_page.dart';
import '../../support/presentation/support_center_page.dart';

class ActivityNotificationsPage extends StatefulWidget {
  const ActivityNotificationsPage({
    super.key,
    required this.businessId,
    required this.supplierView,
    this.onRead,
    this.initialNotification,
  });
  final String businessId;
  final bool supplierView;
  final VoidCallback? onRead;
  final Map<String, dynamic>? initialNotification;
  @override
  State<ActivityNotificationsPage> createState() =>
      _ActivityNotificationsPageState();
}

class _ActivityNotificationsPageState extends State<ActivityNotificationsPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true, _unread = false, _more = false, _opening = false;
  int _page = 0, _request = 0;
  String? _category, _error;
  RealtimeChannel? _channel;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    _load().then((_) {
      final initial = widget.initialNotification;
      if (mounted && initial != null) {
        _open(initial);
      }
    });
    _channel = _client
        .channel('notification-inbox-${widget.businessId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'business_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: widget.businessId,
          ),
          callback: (_) {
            _refresh?.cancel();
            _refresh = Timer(const Duration(milliseconds: 400), () {
              if (mounted) {
                _load();
              }
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _client.rpc(
        'list_business_notifications',
        params: {
          'p_business_id': widget.businessId,
          'p_offset': _page * 50,
          'p_unread_only': _unread,
          'p_category': _category,
        },
      );
      if (!mounted || request != _request) {
        return;
      }
      final rows = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _rows = rows.take(50).toList();
        _more = rows.length > 50;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _read([String? id]) async {
    await _client.rpc(
      'mark_business_notifications_read',
      params: {'p_business_id': widget.businessId, 'p_id': id},
    );
    widget.onRead?.call();
  }

  Future<void> _markAll() async {
    try {
      await _read();
      if (mounted) {
        await _load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _deleteNotification(
    Map<String, dynamic> row, {
    bool undo = false,
  }) async {
    try {
      await _client.rpc(
        'dismiss_business_notification',
        params: {'p_id': row['id'], 'p_deleted': !undo},
      );
      if (!mounted) {
        return;
      }
      widget.onRead?.call();
      if (!undo) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification deleted.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _deleteNotification(row, undo: true),
            ),
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (_opening) {
      return;
    }
    setState(() => _opening = true);
    try {
      await _read(row['id'].toString());
      if (!mounted) {
        return;
      }
      final id = row['reference_id'].toString();
      Widget? page;
      switch (row['reference_type']) {
        case 'announcement':
          await showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(row['title']?.toString() ?? 'CutLink announcement'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: SelectableText(row['detail']?.toString() ?? ''),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        case 'invoice':
          page = widget.supplierView
              ? SupplierInvoicePage(invoiceId: id)
              : ButcherInvoiceDetailPage(
                  invoiceId: id,
                  initialInvoice: const {},
                  supplierName: 'Supplier',
                  onChanged: () async {},
                );
        case 'order':
          page = widget.supplierView
              ? SupplierMarketplaceOrderDetailPage(orderId: id)
              : SubmittedOrdersPage(initialOrderId: id);
        case 'credit_note':
          page = CreditNoteDetail(
            noteId: id,
            supplierView: widget.supplierView,
          );
        case 'accounts':
          page = widget.supplierView
              ? const SupplierCustomerRequestsPage()
              : const ButcherAccountsPage();
        case 'account':
          page = widget.supplierView
              ? SupplierCustomerAccountPage(supplierCustomerAccountId: id)
              : const ButcherAccountsPage();
        case 'support':
          page = SupportCenterPage(
            businessId: widget.businessId,
            adminMode: false,
            initialTicketId: id,
          );
        case 'issue':
          final issue = await _client
              .from('order_issues')
              .select()
              .eq('id', id)
              .single();
          if (!mounted) {
            return;
          }
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => OrderIssueChat(
              issue: Map<String, dynamic>.from(issue),
              businessId: widget.businessId,
              role: widget.supplierView ? 'supplier' : 'butcher',
              orderReference: row['detail']?.toString() ?? 'Order',
              otherParty: widget.supplierView ? 'Customer' : 'Supplier',
            ),
          );
      }
      if (page != null && mounted) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => page!));
      }
      if (mounted) {
        await _load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => CutLinkWorkspaceTheme(
    child: Scaffold(
      appBar: phoneAppBar(
        context,
        AppBar(
          leading: const WorkspaceBackButton(),
          title: const Text('Notifications'),
          actions: [
            TextButton.icon(
              onPressed: _loading ? null : _markAll,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark all read'),
            ),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CutLinkSectionHeading(
                          title: 'Your activity inbox',
                          subtitle:
                              'Orders, conversations, invoices and account updates — all in one place.',
                          icon: Icons.notifications_active_outlined,
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: CutLinkWorkspaceTheme.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: CutLinkWorkspaceTheme.red,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Activity',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  FilterChip(
                                    label: const Text('Unread only'),
                                    selected: _unread,
                                    onSelected: (v) {
                                      setState(() {
                                        _unread = v;
                                        _page = 0;
                                      });
                                      _load();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final cat in <String?>[
                                      null,
                                      'orders',
                                      'quotes',
                                      'invoices',
                                      'messages',
                                      'payments',
                                      'credits',
                                      'delivery',
                                      'support',
                                      'platform',
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 7,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(
                                            cat == null
                                                ? 'All activity'
                                                : cat == 'platform'
                                                ? 'CutLink'
                                                : '${cat[0].toUpperCase()}${cat.substring(1)}',
                                          ),
                                          selected: _category == cat,
                                          onSelected: (_) {
                                            setState(() {
                                              _category = cat;
                                              _page = 0;
                                            });
                                            _load();
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_loading || _opening)
                          const LinearProgressIndicator(minHeight: 2),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_rows.isEmpty && !_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.done_all_rounded,
                            size: 38,
                            color: CutLinkWorkspaceTheme.red,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'You’re all caught up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'No notifications match this view.',
                            style: TextStyle(color: Color(0xFF6A6E75)),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: NotificationActivityTile(
                          row: _rows[i],
                          onDelete: _opening
                              ? null
                              : () => _deleteNotification(_rows[i]),
                          onTap: _opening ? null : () => _open(_rows[i]),
                        ),
                      ),
                      childCount: _rows.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _page == 0 || _loading
                              ? null
                              : () {
                                  _page--;
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text('Previous'),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Page ${_page + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: !_more || _loading
                              ? null
                              : () {
                                  _page++;
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('Next'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
