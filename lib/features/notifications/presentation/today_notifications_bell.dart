import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';
import 'notification_activity_tile.dart';

class TodayNotificationsBell extends StatefulWidget {
  const TodayNotificationsBell({
    super.key,
    required this.businessId,
    required this.onOpenAll,
    required this.onOpenNotification,
    this.revision = 0,
    this.onRead,
  });
  final String businessId;
  final VoidCallback onOpenAll;
  final ValueChanged<Map<String, dynamic>> onOpenNotification;
  final VoidCallback? onRead;
  final int revision;
  @override
  State<TodayNotificationsBell> createState() => _TodayNotificationsBellState();
}

class _TodayNotificationsBellState extends State<TodayNotificationsBell>
    with WidgetsBindingObserver {
  final _view = ValueNotifier<Map<String, dynamic>>({});
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _debounce, _midnight, _resetTimer;
  DateTime? _nextReset;
  int _request = 0;
  bool _panelOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _channel = _client
        .channel('today-bell-${widget.businessId}-$hashCode')
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
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), _load);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'business_app_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: widget.businessId,
          ),
          callback: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), _load);
          },
        )
        .subscribe();
    _midnight = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_nextReset != null && !DateTime.now().isBefore(_nextReset!)) {
        _view.value = {
          'notifications': <Map<String, dynamic>>[],
          'unread_count': 0,
        };
        _load();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TodayNotificationsBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _midnight?.cancel();
    _resetTimer?.cancel();
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    _view.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final result = await _client.rpc(
        'today_business_notifications',
        params: {'p_business_id': widget.businessId},
      );
      if (!mounted || request != _request) {
        return;
      }
      final data = Map<String, dynamic>.from(result as Map);
      _nextReset = DateTime.tryParse(data['next_reset']?.toString() ?? '');
      _view.value = data;
      _resetTimer?.cancel();
      if (_nextReset != null) {
        final delay = _nextReset!.difference(DateTime.now());
        _resetTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
          if (mounted) {
            _view.value = {
              'notifications': <Map<String, dynamic>>[],
              'unread_count': 0,
            };
            _load();
          }
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        _view.value = {
          ..._view.value,
          'error': 'Notifications could not refresh. Please try again.',
        };
      }
    }
  }

  Future<void> _dismiss(Map<String, dynamic> row) async {
    try {
      await _client.rpc(
        'dismiss_today_business_notification',
        params: {'p_id': row['id']},
      );
      if (!mounted) {
        return;
      }
      widget.onRead?.call();
      await _load();
    } catch (_) {
      if (mounted) {
        _view.value = {
          ..._view.value,
          'error': 'Could not dismiss notification. Please try again.',
        };
      }
    }
  }

  Future<void> _showPanel() async {
    if (_panelOpen) {
      return;
    }
    _panelOpen = true;
    _load();
    final box = context.findRenderObject() as RenderBox?;
    final top = box == null
        ? 64.0
        : box.localToGlobal(Offset.zero).dy + box.size.height + 8;
    final screen = MediaQuery.sizeOf(context);
    final panelHeight = math.min(
      580.0,
      math.max(180.0, screen.height - top - 24),
    );
    final choice = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .15),
      builder: (dialogContext) => CutLinkWorkspaceTheme(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(
              top: math.min(top, screen.height * .25),
              right: 12,
              left: 12,
              bottom: 12,
            ),
            child: Material(
              color: CutLinkWorkspaceTheme.canvas,
              elevation: 12,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: math.min(430, screen.width - 24),
                height: panelHeight,
                child: ValueListenableBuilder<Map<String, dynamic>>(
                  valueListenable: _view,
                  builder: (_, data, _) {
                    final rows = (data['notifications'] as List? ?? [])
                        .map((r) => Map<String, dynamic>.from(r as Map))
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Today’s notifications',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: CutLinkWorkspaceTheme.ink,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Today in Sydney • live activity',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6A6E75),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        if (data['error'] != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextButton(
                              onPressed: _load,
                              child: Text(data['error'].toString()),
                            ),
                          ),
                        Expanded(
                          child: data.isEmpty
                              ? const Center(child: CircularProgressIndicator())
                              : rows.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.notifications_none_rounded,
                                        size: 36,
                                        color: CutLinkWorkspaceTheme.red,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'No activity today yet',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'New updates will appear here.',
                                        style: TextStyle(
                                          color: Color(0xFF6A6E75),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: rows.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, i) =>
                                      NotificationActivityTile(
                                        row: rows[i],
                                        compact: true,
                                        onDelete: () => _dismiss(rows[i]),
                                        onTap: () => Navigator.pop(
                                          dialogContext,
                                          rows[i],
                                        ),
                                      ),
                                ),
                        ),
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(12),
                          child: TextButton.icon(
                            onPressed: () => Navigator.pop(dialogContext, {
                              'open_all': true,
                            }),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: const Text('All notifications'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _panelOpen = false;
    if (!mounted || choice == null) {
      return;
    }
    if (choice['open_all'] == true) {
      widget.onOpenAll();
      return;
    }
    // Only the chosen notification is read; opening the panel leaves others unread.
    try {
      await _client.rpc(
        'mark_business_notifications_read',
        params: {'p_business_id': widget.businessId, 'p_id': choice['id']},
      );
      if (!mounted) {
        return;
      }
      widget.onRead?.call();
      _load();
    } catch (_) {
      // The full inbox retries the read and shows any connection error.
    }
    if (mounted) {
      widget.onOpenNotification(choice);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: _view,
        builder: (_, data, _) {
          final count = (data['unread_count'] as num?)?.toInt() ?? 0;
          return IconButton(
            tooltip: 'Today’s notifications ($count unread)',
            onPressed: _showPanel,
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text(count > 99 ? '99+' : '$count'),
              backgroundColor: CutLinkWorkspaceTheme.red,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          );
        },
      );
}
