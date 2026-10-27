import '../../../shared/widgets/ios_density.dart';
import '../../../shared/widgets/cutlink_review_theme.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';
import '../../notifications/presentation/notification_activity_tile.dart';
import 'admin_notification_settings_page.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/presentation/support_center_page.dart';

class AdminProductNotificationsBell extends StatefulWidget {
  const AdminProductNotificationsBell({super.key});
  @override
  State<AdminProductNotificationsBell> createState() =>
      _AdminProductNotificationsBellState();
}

class _AdminProductNotificationsBellState
    extends State<AdminProductNotificationsBell> {
  final _client = Supabase.instance.client;
  final _view = ValueNotifier<Map<String, dynamic>>({});
  RealtimeChannel? _channel;
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    adminNotificationPreferencesRevision.addListener(_load);
    _load();
    _channel = _client
        .channel('admin-product-alerts-$hashCode')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'admin_product_notifications',
          callback: (_) => _load(),
        )
        .subscribe();
    // Polling also recovers after sleeping browsers and missed realtime events.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final raw = await _client.rpc('admin_product_notification_inbox');
      if (mounted) {
        _view.value = Map<String, dynamic>.from(raw as Map);
      }
    } catch (_) {
      if (mounted) {
        _view.value = {..._view.value, 'error': true};
      }
    }
  }

  @override
  void dispose() {
    adminNotificationPreferencesRevision.removeListener(_load);
    _poll?.cancel();
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    _view.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    await _load();
    if (!mounted) {
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => CutLinkReviewTheme(
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 620,
            height: MediaQuery.sizeOf(dialogContext).height < 720
                ? MediaQuery.sizeOf(dialogContext).height - 48
                : 620,
            child: ValueListenableBuilder<Map<String, dynamic>>(
              valueListenable: _view,
              builder: (_, data, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IosPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFF5E9E9),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: CutLinkWorkspaceTheme.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Product reports and corrections',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF66717E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Notification settings',
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            <String, dynamic>{'open_settings': true},
                          ),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (data['enabled'] == false)
                    const IosPadding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Alerts are muted. Your notification history is shown below.',
                      ),
                    ),
                  if (data['error'] == true)
                    TextButton(
                      onPressed: _load,
                      child: const Text(
                        'Could not refresh notifications. Retry',
                      ),
                    ),
                  Expanded(
                    child: ColoredBox(
                      color: CutLinkWorkspaceTheme.canvas,
                      child: (data['notifications'] as List? ?? []).isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    size: 36,
                                    color: CutLinkWorkspaceTheme.red,
                                  ),
                                  IosGap(height: 10),
                                  Text(
                                    'You’re up to date',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(14),
                              itemCount: (data['notifications'] as List).length,
                              separatorBuilder: (_, i) =>
                                  const IosGap(height: 8),
                              itemBuilder: (_, i) {
                                final row = Map<String, dynamic>.from(
                                  (data['notifications'] as List)[i] as Map,
                                );
                                return NotificationActivityTile(
                                  row: {...row, 'category': 'moderation'},
                                  compact: true,
                                  onTap: () =>
                                      Navigator.pop(dialogContext, row),
                                );
                              },
                            ),
                    ),
                  ),
                  const Divider(height: 1),
                  IosPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          try {
                            await _client.rpc(
                              'mark_all_admin_product_notifications_read',
                            );
                            await _load();
                          } catch (_) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not mark notifications as read. Retry.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('Mark all read'),
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
    if (selected == null || !mounted) {
      return;
    }
    if (selected['open_settings'] == true) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const AdminNotificationSettingsPage(),
        ),
      );
      if (mounted) {
        await _load();
      }
      return;
    }
    try {
      await _client
          .from('admin_product_notification_reads')
          .upsert(
            {
              'notification_id': selected['id'],
              'user_id': _client.auth.currentUser!.id,
            },
            onConflict: 'notification_id,user_id',
            ignoreDuplicates: true,
          );
    } catch (_) {
      /* Keep opening the case; the unread alert can be retried. */
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportCenterPage(
          businessId: '',
          adminMode: true,
          initialTicketId: selected['ticket_id'].toString(),
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: _view,
        builder: (_, data, _) {
          final count = data['enabled'] == false
              ? 0
              : (data['unread_count'] as num? ?? 0).toInt();
          return IconButton(
            tooltip: 'Notifications',
            onPressed: _show,
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text(count > 99 ? '99+' : '$count'),
              child: const Icon(Icons.notifications_outlined),
            ),
          );
        },
      );
}
