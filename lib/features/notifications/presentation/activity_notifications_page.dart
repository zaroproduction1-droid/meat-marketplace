import '../../../shared/theme/cutlink_appearance.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';
import 'activity_inbox.dart';
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

  Future<void> _load({bool more = false}) async {
    if (more && _loading) return;
    final request = ++_request;
    final targetPage = more ? _page + 1 : _page;
    final unread = _unread;
    final category = _category;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Refresh all pages already on screen so read/dismiss/realtime changes
      // cannot leave stale rows behind. Load-more keeps existing rows in place.
      final pages = await Future.wait([
        for (var page = more ? targetPage : 0; page <= targetPage; page++)
          _client.rpc(
            'list_business_notifications',
            params: {
              'p_business_id': widget.businessId,
              'p_offset': page * 50,
              'p_unread_only': unread,
              'p_category': category,
            },
          ),
      ]);
      if (!mounted || request != _request) return;
      final incoming = <Map<String, dynamic>>[];
      for (final result in pages) {
        incoming.addAll(
          (result as List)
              .take(50)
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
      setState(() {
        final unique = <String, Map<String, dynamic>>{};
        for (final row in [
          ...(more ? _rows : <Map<String, dynamic>>[]),
          ...incoming,
        ]) {
          unique[row['id'].toString()] = row;
        }
        _rows = unique.values.toList();
        _page = targetPage;
        _more = (pages.last as List).length > 50;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = 'Could not load activity. Please retry.');
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
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return CutLinkWorkspaceTheme(
      child: Scaffold(
        appBar: phoneAppBar(
          context,
          AppBar(
            leading: const WorkspaceBackButton(),
            title: const Text('Notifications'),
            actions: [
              if (MediaQuery.sizeOf(context).width < 600)
                IconButton(
                  tooltip: 'Mark all read',
                  onPressed: _loading ? null : _markAll,
                  icon: const Icon(Icons.done_all_rounded),
                )
              else
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
            constraints: const BoxConstraints(maxWidth: 1400),
            child: ActivityInbox(
              rows: _rows,
              loading: _loading || _opening,
              unreadOnly: _unread,
              category: _category,
              error: _error,
              hasMore: _more,
              onRefresh: () async {
                _page = 0;
                await _load();
              },
              onMore: () => _load(more: true),
              onFilter: (unread, category) {
                setState(() {
                  _unread = unread;
                  _category = category;
                  _page = 0;
                  _rows = [];
                });
                _load();
              },
              onOpen: (row) {
                if (!_opening) _open(row);
              },
              onDismiss: _deleteNotification,
              onRead: (events) async {
                try {
                  for (final row in events.where((e) => e['read_at'] == null)) {
                    await _read(row['id']?.toString());
                    if (mounted) {
                      setState(
                        () => row['read_at'] = DateTime.now().toIso8601String(),
                      );
                    }
                  }
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => _error =
                          'Could not mark activity as read. Please retry.',
                    );
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
