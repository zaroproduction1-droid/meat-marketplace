import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportCenterPage extends StatefulWidget {
  const SupportCenterPage({
    super.key,
    required this.businessId,
    required this.adminMode,
  });

  final String businessId;
  final bool adminMode;

  @override
  State<SupportCenterPage> createState() => _SupportCenterPageState();
}

class _SupportCenterPageState extends State<SupportCenterPage> {
  static const _darkRed = Color(0xFF8B1E2D);
  static const _navy = Color(0xFF081625);

  bool _loading = true;
  bool _sending = false;
  bool _uploading = false;
  String? _error;
  String _statusFilter = 'active';
  String _search = '';
  String? _activeAdminAction;

  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _messages = [];
  final List<PlatformFile> _pendingAttachments = [];
  Map<String, dynamic>? _selectedTicket;

  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _messagesScrollController = ScrollController();

  RealtimeChannel? _ticketsChannel;
  RealtimeChannel? _messagesChannel;
  Timer? _ticketRefreshDebounce;
  Timer? _messageRefreshDebounce;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _subscribeToTickets();
  }

  @override
  void dispose() {
    _ticketRefreshDebounce?.cancel();
    _messageRefreshDebounce?.cancel();
    _messageController.dispose();
    _searchController.dispose();
    _messagesScrollController.dispose();
    final ticketsChannel = _ticketsChannel;
    if (ticketsChannel != null) {
      Supabase.instance.client.removeChannel(ticketsChannel);
    }
    final messagesChannel = _messagesChannel;
    if (messagesChannel != null) {
      Supabase.instance.client.removeChannel(messagesChannel);
    }
    super.dispose();
  }

  void _subscribeToTickets() {
    final client = Supabase.instance.client;
    var channel = client.channel(
      'support-tickets-${widget.adminMode ? 'admin' : widget.businessId}',
    );

    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_tickets',
      filter: widget.adminMode
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'business_id',
              value: widget.businessId,
            ),
      callback: (_) {
        _ticketRefreshDebounce?.cancel();
        _ticketRefreshDebounce = Timer(
          const Duration(milliseconds: 350),
          () => _loadTickets(showLoading: false),
        );
      },
    );

    _ticketsChannel = channel.subscribe();
  }

  Future<void> _subscribeToMessages(String ticketId) async {
    final previous = _messagesChannel;
    if (previous != null) {
      await Supabase.instance.client.removeChannel(previous);
    }

    _messagesChannel = Supabase.instance.client
        .channel('support-messages-$ticketId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_ticket_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: ticketId,
          ),
          callback: (_) {
            _messageRefreshDebounce?.cancel();
            _messageRefreshDebounce = Timer(
              const Duration(milliseconds: 200),
              () => _loadMessages(ticketId, markRead: true),
            );
          },
        )
        .subscribe();
  }

  Future<void> _loadTickets({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      var query = Supabase.instance.client.from('support_tickets').select('''
        id,
        ticket_number,
        business_id,
        created_by_user_id,
        requester_name,
        business_name,
        requester_type,
        subject,
        category,
        priority,
        status,
        assigned_admin_user_id,
        last_message_at,
        last_message_by_user_id,
        requester_last_read_at,
        admin_last_read_at,
        resolved_at,
        closed_at,
        created_at,
        updated_at
      ''');

      if (!widget.adminMode) {
        query = query.eq('business_id', widget.businessId);
      }

      final response = await query.order('updated_at', ascending: false);
      final tickets = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      final selectedId = _selectedTicket?['id']?.toString();
      Map<String, dynamic>? refreshedSelected;
      if (selectedId != null) {
        for (final ticket in tickets) {
          if (ticket['id']?.toString() == selectedId) {
            refreshedSelected = ticket;
            break;
          }
        }
      }

      setState(() {
        _tickets = tickets;
        _selectedTicket = refreshedSelected ?? _selectedTicket;
        _loading = false;
        _error = null;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openTicket(Map<String, dynamic> ticket) async {
    final ticketId = ticket['id']?.toString();
    if (ticketId == null) return;

    setState(() {
      _selectedTicket = ticket;
      _messages = [];
      _pendingAttachments.clear();
      _messageController.clear();
      _activeAdminAction = null;
    });

    await _subscribeToMessages(ticketId);
    await _loadMessages(ticketId, markRead: true, scrollToBottom: false);
  }

  Future<void> _loadMessages(
    String ticketId, {
    required bool markRead,
    bool scrollToBottom = true,
  }) async {
    try {
      final response = await Supabase.instance.client
          .from('support_ticket_messages')
          .select('''
            id,
            ticket_id,
            sender_user_id,
            sender_role,
            sender_name,
            message,
            created_at,
            support_ticket_attachments (
              id,
              file_name,
              storage_path,
              mime_type,
              file_size,
              created_at
            )
          ''')
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);

      if (markRead) {
        await Supabase.instance.client.rpc(
          'mark_support_ticket_read',
          params: {'p_ticket_id': ticketId},
        );
      }

      if (!mounted || _selectedTicket?['id']?.toString() != ticketId) return;

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_messagesScrollController.hasClients) return;
        if (!scrollToBottom) {
          _messagesScrollController.jumpTo(
            _messagesScrollController.position.minScrollExtent,
          );
          return;
        }
        _messagesScrollController.animateTo(
          _messagesScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _createTicket() async {
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    var category = 'technical';
    var priority = 'normal';

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _darkRed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.support_agent,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contact CutLink Support',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tell us what happened and we will help you here.',
                                  style: TextStyle(
                                    color: Color(0xFF666A70),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: subjectController,
                        autofocus: true,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'What do you need help with?',
                          hintText: 'Example: Unable to dispatch an order',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final fields = [
                            DropdownButtonFormField<String>(
                              initialValue: category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: _categoryValues
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(_categoryLabel(value)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => category = value);
                                }
                              },
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: priority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'low',
                                  child: Text('Low'),
                                ),
                                DropdownMenuItem(
                                  value: 'normal',
                                  child: Text('Normal'),
                                ),
                                DropdownMenuItem(
                                  value: 'high',
                                  child: Text('High'),
                                ),
                                DropdownMenuItem(
                                  value: 'urgent',
                                  child: Text('Urgent'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => priority = value);
                                }
                              },
                            ),
                          ];

                          if (constraints.maxWidth < 560) {
                            return Column(
                              children: [
                                fields.first,
                                const SizedBox(height: 12),
                                fields.last,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: fields.first),
                              const SizedBox(width: 12),
                              Expanded(child: fields.last),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        minLines: 5,
                        maxLines: 8,
                        maxLength: 8000,
                        decoration: const InputDecoration(
                          labelText: 'Describe the issue',
                          hintText:
                              'Include what you were doing, what you expected and what happened.',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _darkRed,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                            ),
                            onPressed: () {
                              final subject = subjectController.text.trim();
                              final description = descriptionController.text
                                  .trim();
                              if (subject.length < 4 || description.isEmpty) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter a subject and describe the issue.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(dialogContext).pop({
                                'subject': subject,
                                'category': category,
                                'priority': priority,
                                'message': description,
                              });
                            },
                            icon: const Icon(Icons.send_outlined, size: 18),
                            label: const Text('Submit Ticket'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    subjectController.dispose();
    descriptionController.dispose();
    if (result == null) return;

    setState(() => _sending = true);
    try {
      final response = await Supabase.instance.client.rpc(
        'create_support_ticket',
        params: {
          'p_business_id': widget.businessId,
          'p_subject': result['subject'],
          'p_category': result['category'],
          'p_priority': result['priority'],
          'p_message': result['message'],
        },
      );

      await _loadTickets(showLoading: false);

      if (response is Map && mounted) {
        await _openTicket(Map<String, dynamic>.from(response));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support ticket submitted.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendMessage() async {
    final ticket = _selectedTicket;
    final ticketId = ticket?['id']?.toString();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final message = _messageController.text.trim();
    final pendingFiles = List<PlatformFile>.from(_pendingAttachments);
    if (ticketId == null ||
        userId == null ||
        (message.isEmpty && pendingFiles.isEmpty) ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
      _uploading = pendingFiles.isNotEmpty;
    });
    final uploadedPaths = <String>[];
    try {
      final attachments = <Map<String, dynamic>>[];
      for (var index = 0; index < pendingFiles.length; index++) {
        final file = pendingFiles[index];
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('${file.name} could not be read.');
        }
        if (bytes.length > 15 * 1024 * 1024) {
          throw Exception('${file.name} is larger than 15 MB.');
        }

        final safeName = _safeFileName(file.name);
        final storagePath =
            '$ticketId/$userId/${DateTime.now().microsecondsSinceEpoch}_$index-$safeName';
        final mimeType = _mimeTypeForFile(file.name);

        await Supabase.instance.client.storage
            .from('support-attachments')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: false),
            );
        uploadedPaths.add(storagePath);
        attachments.add({
          'file_name': file.name,
          'storage_path': storagePath,
          'mime_type': mimeType,
          'file_size': bytes.length,
        });
      }

      await Supabase.instance.client.rpc(
        'send_support_ticket_message_with_attachments',
        params: {
          'p_ticket_id': ticketId,
          'p_message': message.isEmpty ? null : message,
          'p_attachments': attachments,
        },
      );

      _messageController.clear();
      if (mounted) {
        setState(() => _pendingAttachments.clear());
      }
      await _loadMessages(ticketId, markRead: true);
      await _loadTickets(showLoading: false);
    } on PostgrestException catch (error) {
      await _removeUnsentUploads(uploadedPaths);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on StorageException catch (error) {
      await _removeUnsentUploads(uploadedPaths);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      await _removeUnsentUploads(uploadedPaths);
      if (mounted) {
        final errorMessage = error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _uploading = false;
        });
      }
    }
  }

  Future<void> _pickAttachments() async {
    if (_sending) return;
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'pdf',
        'txt',
        'csv',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'zip',
      ],
    );
    if (selection.isEmpty) return;

    final existingNames = _pendingAttachments
        .map((file) => file.name.toLowerCase())
        .toSet();
    final additions = selection
        .where((file) => !existingNames.contains(file.name.toLowerCase()))
        .toList();

    if (_pendingAttachments.length + additions.length > 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attach up to 5 files at a time.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _pendingAttachments.addAll(additions));
    }
  }

  Future<void> _removeUnsentUploads(List<String> storagePaths) async {
    if (storagePaths.isEmpty) return;
    try {
      await Supabase.instance.client.storage
          .from('support-attachments')
          .remove(storagePaths);
    } catch (_) {
      // Unlinked objects remain private and inaccessible to other businesses.
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final storagePath = attachment['storage_path']?.toString();
    if (storagePath == null || storagePath.isEmpty) return;

    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('support-attachments')
          .createSignedUrl(storagePath, 300);
      final opened = await launchUrl(
        Uri.parse(signedUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('The attachment could not be opened.');
    } on StorageException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _adminUpdate({
    String? status,
    String? priority,
    bool assignToMe = false,
    bool unassign = false,
  }) async {
    final ticketId = _selectedTicket?['id']?.toString();
    if (!widget.adminMode || ticketId == null || _sending) return;

    setState(() => _sending = true);
    try {
      final response = await Supabase.instance.client.rpc(
        'update_support_ticket_admin',
        params: {
          'p_ticket_id': ticketId,
          'p_status': status,
          'p_priority': priority,
          'p_assign_to_me': assignToMe,
          'p_unassign': unassign,
        },
      );
      if (response is Map && mounted) {
        setState(() {
          _selectedTicket = Map<String, dynamic>.from(response);
        });
      }
      await _loadTickets(showLoading: false);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<Map<String, dynamic>> get _visibleTickets {
    final query = _search.trim().toLowerCase();
    return _tickets.where((ticket) {
      final status = ticket['status']?.toString() ?? '';
      final statusMatches = switch (_statusFilter) {
        'active' => status != 'resolved' && status != 'closed',
        'resolved' => status == 'resolved',
        'closed' => status == 'closed',
        _ => true,
      };
      if (!statusMatches) return false;
      if (query.isEmpty) return true;
      return [
        ticket['ticket_number'],
        ticket['subject'],
        ticket['business_name'],
        ticket['requester_name'],
      ].any((value) => value?.toString().toLowerCase().contains(query) == true);
    }).toList();
  }

  bool _isUnread(Map<String, dynamic> ticket) {
    final lastMessageAt = _date(ticket['last_message_at']);
    final readAt = _date(
      widget.adminMode
          ? ticket['admin_last_read_at']
          : ticket['requester_last_read_at'],
    );
    if (lastMessageAt == null) return false;
    return readAt == null || lastMessageAt.isAfter(readAt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.support_agent, color: _darkRed),
            const SizedBox(width: 10),
            Text(
              widget.adminMode ? 'Support Administration' : 'CutLink Support',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          if (!widget.adminMode)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: FilledButton.icon(
                onPressed: _sending ? null : _createTicket,
                style: FilledButton.styleFrom(backgroundColor: _darkRed),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Ticket'),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _loadTickets(),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E5E8)),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _darkRed, size: 56),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _loadTickets(),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        if (!desktop && _selectedTicket != null) {
          return _ticketDetail(showBack: true);
        }

        if (!desktop) {
          return _ticketList();
        }

        return Row(
          children: [
            SizedBox(width: 390, child: _ticketList()),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selectedTicket == null
                  ? _emptySelection()
                  : _ticketDetail(showBack: false),
            ),
          ],
        );
      },
    );
  }

  Widget _ticketList() {
    final tickets = _visibleTickets;
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: widget.adminMode
                    ? 'Search tickets or businesses'
                    : 'Search your tickets',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('Active')),
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'resolved', label: Text('Resolved')),
                ButtonSegment(value: 'closed', label: Text('Closed')),
              ],
              selected: {_statusFilter},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                setState(() => _statusFilter = value.first);
              },
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          Expanded(
            child: tickets.isEmpty
                ? _emptyTickets()
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (_, index) => _ticketCard(tickets[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _ticketCard(Map<String, dynamic> ticket) {
    final selected = _selectedTicket?['id'] == ticket['id'];
    final unread = _isUnread(ticket);
    return Material(
      color: selected ? const Color(0xFFF9EEEE) : const Color(0xFFFDFDFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openTicket(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _darkRed : const Color(0xFFE3E5E8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket['ticket_number']?.toString() ?? 'Support Ticket',
                      style: const TextStyle(
                        color: _darkRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (unread)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: _darkRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 8),
                  _statusChip(ticket['status']?.toString() ?? 'open'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ticket['subject']?.toString() ?? 'Support request',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: unread ? FontWeight.w900 : FontWeight.w800,
                ),
              ),
              if (widget.adminMode) ...[
                const SizedBox(height: 5),
                Text(
                  '${ticket['business_name'] ?? 'Business'} • ${ticket['requester_name'] ?? 'User'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF666A70),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 9),
              Row(
                children: [
                  _priorityChip(ticket['priority']?.toString() ?? 'normal'),
                  const Spacer(),
                  Text(
                    _relativeDate(ticket['updated_at']),
                    style: const TextStyle(
                      color: Color(0xFF777B82),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ticketDetail({required bool showBack}) {
    final ticket = _selectedTicket;
    if (ticket == null) return _emptySelection();

    final closed = ticket['status']?.toString() == 'closed';
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBack) ...[
                IconButton(
                  tooltip: 'Back to tickets',
                  onPressed: () => setState(() => _selectedTicket = null),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ticket['ticket_number']?.toString() ?? 'Ticket',
                          style: const TextStyle(
                            color: _darkRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusChip(ticket['status']?.toString() ?? 'open'),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ticket['subject']?.toString() ?? 'Support request',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.adminMode
                          ? '${ticket['business_name']} • ${ticket['requester_name']} • ${_categoryLabel(ticket['category']?.toString() ?? 'other')}'
                          : '${_categoryLabel(ticket['category']?.toString() ?? 'other')} • Opened ${_formatDate(ticket['created_at'])}',
                      style: const TextStyle(
                        color: Color(0xFF666A70),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _messagesScrollController,
                  reverse: false,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  itemCount: _messages.length,
                  itemBuilder: (_, index) => _messageBubble(_messages[index]),
                ),
        ),
        if (widget.adminMode) _adminActionBar(ticket),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE1E4E7))),
          ),
          child: closed
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Color(0xFF666A70),
                    ),
                    SizedBox(width: 8),
                    Text('This ticket is closed.'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_pendingAttachments.isNotEmpty) ...[
                      _pendingAttachmentStrip(),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton.outlined(
                          tooltip: 'Attach files',
                          onPressed: _sending ? null : _pickAttachments,
                          icon: const Icon(Icons.attach_file_rounded),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            enabled: !_sending,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 8000,
                            decoration: InputDecoration(
                              hintText: widget.adminMode
                                  ? 'Reply as CutLink Support…'
                                  : 'Reply to CutLink Support…',
                              counterText: '',
                              filled: true,
                              fillColor: const Color(0xFFF7F8FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDDE1E5),
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          tooltip: 'Send message',
                          style: IconButton.styleFrom(
                            backgroundColor: _darkRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                          ),
                          onPressed: _sending ? null : _sendMessage,
                          icon: _uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _adminActionBar(Map<String, dynamic> ticket) {
    final assigned = ticket['assigned_admin_user_id'] != null;
    final status = ticket['status']?.toString() ?? 'open';
    final priority = ticket['priority']?.toString() ?? 'normal';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E4E7))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _adminActionButton(
                  icon: assigned
                      ? Icons.person_remove_outlined
                      : Icons.person_add_alt_outlined,
                  label: assigned ? 'Unassign' : 'Assign to me',
                  active: false,
                  onPressed: _sending
                      ? null
                      : () => _adminUpdate(
                          assignToMe: !assigned,
                          unassign: assigned,
                        ),
                ),
                const SizedBox(width: 8),
                _adminActionButton(
                  icon: Icons.change_circle_outlined,
                  label: 'Status: ${_adminStatusLabel(status)}',
                  active: _activeAdminAction == 'status',
                  onPressed: _sending
                      ? null
                      : () => _toggleAdminAction('status'),
                ),
                const SizedBox(width: 8),
                _adminActionButton(
                  icon: Icons.flag_outlined,
                  label: 'Priority: ${_titleCase(priority)}',
                  active: _activeAdminAction == 'priority',
                  onPressed: _sending
                      ? null
                      : () => _toggleAdminAction('priority'),
                ),
              ],
            ),
          ),
          if (_activeAdminAction == 'status') ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _adminChoice('Open', status == 'open', () {
                  _applyAdminStatus('open');
                }),
                _adminChoice(
                  'Waiting on CutLink',
                  status == 'awaiting_support',
                  () {
                    _applyAdminStatus('awaiting_support');
                  },
                ),
                _adminChoice(
                  'Waiting on Customer',
                  status == 'waiting_on_customer',
                  () => _applyAdminStatus('waiting_on_customer'),
                ),
                _adminChoice('Resolved', status == 'resolved', () {
                  _applyAdminStatus('resolved');
                }),
                _adminChoice('Closed', status == 'closed', () {
                  _applyAdminStatus('closed');
                }),
              ],
            ),
          ],
          if (_activeAdminAction == 'priority') ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final value in const ['low', 'normal', 'high', 'urgent'])
                  _adminChoice(
                    _titleCase(value),
                    priority == value,
                    () => _applyAdminPriority(value),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _adminActionButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? Colors.white : _navy,
        backgroundColor: active ? _darkRed : Colors.white,
        side: BorderSide(color: active ? _darkRed : const Color(0xFFD6DADF)),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _adminChoice(String label, bool selected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _sending ? null : (_) => onSelected(),
      selectedColor: const Color(0xFFF3DDE0),
      side: BorderSide(color: selected ? _darkRed : const Color(0xFFD6DADF)),
      labelStyle: TextStyle(
        color: selected ? _darkRed : _navy,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  void _toggleAdminAction(String action) {
    setState(() {
      _activeAdminAction = _activeAdminAction == action ? null : action;
    });
  }

  void _applyAdminStatus(String status) {
    setState(() => _activeAdminAction = null);
    _adminUpdate(status: status);
  }

  void _applyAdminPriority(String priority) {
    setState(() => _activeAdminAction = null);
    _adminUpdate(priority: priority);
  }

  String _adminStatusLabel(String status) => switch (status) {
    'awaiting_support' => 'Waiting on CutLink',
    'waiting_on_customer' => 'Waiting on Customer',
    'resolved' => 'Resolved',
    'closed' => 'Closed',
    _ => 'Open',
  };

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final fromAdmin = message['sender_role']?.toString() == 'admin';
    final mine = widget.adminMode ? fromAdmin : !fromAdmin;
    final attachmentData = message['support_ticket_attachments'];
    final attachments = attachmentData is List
        ? attachmentData
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final messageText = message['message']?.toString() ?? '';
    final showMessageText =
        messageText.isNotEmpty &&
        !(messageText == 'Shared an attachment.' && attachments.isNotEmpty);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
        decoration: BoxDecoration(
          color: mine ? _navy : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
          border: mine ? null : Border.all(color: const Color(0xFFE0E3E6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x09000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fromAdmin
                      ? 'CutLink Support'
                      : message['sender_name']?.toString() ?? 'Customer',
                  style: TextStyle(
                    color: mine ? Colors.white70 : _darkRed,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatMessageTime(message['created_at']),
                  style: TextStyle(
                    color: mine ? Colors.white54 : const Color(0xFF888B90),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
            if (showMessageText) ...[
              const SizedBox(height: 5),
              Text(
                messageText,
                style: TextStyle(
                  color: mine ? Colors.white : const Color(0xFF202327),
                  height: 1.38,
                ),
              ),
            ],
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 7),
              for (final attachment in attachments)
                _attachmentCard(attachment, mine: mine),
            ],
          ],
        ),
      ),
    );
  }

  Widget _attachmentCard(
    Map<String, dynamic> attachment, {
    required bool mine,
  }) {
    final fileName = attachment['file_name']?.toString() ?? 'Attachment';
    final size = int.tryParse(attachment['file_size']?.toString() ?? '') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: mine
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _openAttachment(attachment),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                Icon(
                  _attachmentIcon(fileName),
                  size: 22,
                  color: mine ? Colors.white : _darkRed,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mine ? Colors.white : const Color(0xFF202327),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatFileSize(size)} • Open attachment',
                        style: TextStyle(
                          color: mine
                              ? Colors.white70
                              : const Color(0xFF6E7379),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: mine ? Colors.white70 : const Color(0xFF6E7379),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingAttachmentStrip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (
              var index = 0;
              index < _pendingAttachments.length;
              index++
            ) ...[
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDE1E5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _attachmentIcon(_pendingAttachments[index].name),
                      size: 18,
                      color: _darkRed,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        _pendingAttachments[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove attachment',
                      visualDensity: VisualDensity.compact,
                      onPressed: _sending
                          ? null
                          : () {
                              setState(
                                () => _pendingAttachments.removeAt(index),
                              );
                            },
                      icon: const Icon(Icons.close, size: 17),
                    ),
                  ],
                ),
              ),
              if (index != _pendingAttachments.length - 1)
                const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  String _safeFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'attachment' : safe;
  }

  String _mimeTypeForFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  IconData _attachmentIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'webp' => Icons.image_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'doc' || 'docx' => Icons.description_outlined,
      'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
      'zip' => Icons.folder_zip_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _emptyTickets() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 58, color: _darkRed),
            const SizedBox(height: 14),
            Text(
              widget.adminMode ? 'No matching tickets' : 'No support tickets',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              widget.adminMode
                  ? 'New supplier and butcher requests will appear here.'
                  : 'If you need help, create a ticket and chat with CutLink.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666A70)),
            ),
            if (!widget.adminMode) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _createTicket,
                style: FilledButton.styleFrom(backgroundColor: _darkRed),
                icon: const Icon(Icons.add),
                label: const Text('Create Ticket'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptySelection() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.support_agent, size: 72, color: Color(0xFF8B1E2D)),
          SizedBox(height: 16),
          Text(
            'Select a support ticket',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'The full conversation and ticket controls will appear here.',
            style: TextStyle(color: Color(0xFF666A70)),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, colour) = switch (status) {
      'awaiting_support' => ('Waiting on CutLink', const Color(0xFF9A5B00)),
      'waiting_on_customer' => ('Waiting on You', const Color(0xFF315A8C)),
      'resolved' => ('Resolved', const Color(0xFF2E7D32)),
      'closed' => ('Closed', const Color(0xFF666A70)),
      _ => ('Open', _darkRed),
    };

    final displayLabel = widget.adminMode && status == 'waiting_on_customer'
        ? 'Waiting on Customer'
        : label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          color: colour,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _priorityChip(String priority) {
    final colour = switch (priority) {
      'urgent' => const Color(0xFFB3261E),
      'high' => const Color(0xFFB85F00),
      'low' => const Color(0xFF607080),
      _ => const Color(0xFF315A8C),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag_outlined, size: 13, color: colour),
        const SizedBox(width: 4),
        Text(
          '${priority.substring(0, 1).toUpperCase()}${priority.substring(1)}',
          style: TextStyle(
            color: colour,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _formatDate(dynamic value) {
    final date = _date(value);
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatMessageTime(dynamic value) {
    final date = _date(value);
    if (date == null) return '';
    return '${_formatDate(value)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _relativeDate(dynamic value) {
    final date = _date(value);
    if (date == null) return '';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return _formatDate(value);
  }

  static const _categoryValues = [
    'account',
    'billing',
    'orders',
    'invoices',
    'products',
    'delivery',
    'technical',
    'other',
  ];

  static String _categoryLabel(String value) => switch (value) {
    'account' => 'Account & Access',
    'billing' => 'Billing & Payments',
    'orders' => 'Orders',
    'invoices' => 'Invoices',
    'products' => 'Products & Pricing',
    'delivery' => 'Delivery',
    'technical' => 'Technical Issue',
    _ => 'Other',
  };
}
