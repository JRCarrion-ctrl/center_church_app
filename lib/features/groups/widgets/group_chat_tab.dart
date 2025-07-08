// File: lib/features/groups/widgets/group_chat_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../models/group_message.dart';
import '../group_chat_service.dart';
import '../chat_storage_service.dart';
import 'message_list_view.dart';
import 'input_row.dart';
import '../group_pin_service.dart';

class GroupChatTab extends StatefulWidget {
  final String groupId;
  final bool isAdmin;
  static void scrollToPinnedMessage(BuildContext context) {
    final state = context.findAncestorStateOfType<_GroupChatTabState>();
    state?._scrollToPinnedMessage();
  }

  const GroupChatTab({
    super.key,
    required this.groupId,
    required this.isAdmin,
  });

  @override
  State<GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends State<GroupChatTab> {
  late final RealtimeChannel _reactionChannel;
  final Map<String, List<String>> _reactionMap = {};
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = GroupChatService();
  final _storageService = ChatStorageService();
  final _pinService = GroupPinService();


  bool _showJumpToLatest = false;
  bool _initialScrollDone = false;
  String? _highlightMessageId;

  @override
  void initState() {
    super.initState();

    _chatService.getReactions(widget.groupId).then((map) {
      setState(() => _reactionMap.addAll(map));
    });

    _loadPinnedMessage();

    _reactionChannel = Supabase.instance.client
        .channel('public:message_reactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'message_reactions',
          callback: (payload) {
            final data = payload.newRecord;
            final messageId = data['message_id'];
            final emoji = data['emoji'];
            setState(() {
              _reactionMap.putIfAbsent(messageId, () => []).add(emoji);
            });
          },
        )
        .subscribe();

    _scrollController.addListener(() {
      final shouldShow =
          (_scrollController.position.maxScrollExtent - _scrollController.offset) > 300;

      if (_showJumpToLatest != shouldShow) {
        setState(() => _showJumpToLatest = shouldShow);
      }
    });

  }

  Future<void> _loadPinnedMessage() async {
    final response = await Supabase.instance.client
        .from('groups')
        .select('pinned_message_id')
        .eq('id', widget.groupId)
        .maybeSingle();

    setState(() {
      _highlightMessageId = response?['pinned_message_id'];
    });
  }

  void _scrollToPinnedMessage() {
    if (_highlightMessageId != null && _scrollController.hasClients) {
      // Delay to wait for messages to render
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  String _formatSmartTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final local = timestamp.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(local.year, local.month, local.day);

    final timePart = DateFormat.jm().format(local);

    if (messageDay == today) {
      return 'Today, $timePart';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $timePart';
    } else {
      return DateFormat('MMMM d, y – h:mm a').format(local);
    }
  }

  @override
  void dispose() {
    _reactionChannel.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    await _chatService.sendMessage(widget.groupId, content);
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final position = _scrollController.position.maxScrollExtent;
        if (instant) {
          _scrollController.jumpTo(position);
        } else {
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }


  void _showMessageOptions(GroupMessage message) {
    final isSender = message.senderId == _userId;

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Wrap(
          children: [
            if (widget.isAdmin || isSender)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Message'),
                onTap: () async {
                  Navigator.pop(context);
                  await _chatService.deleteMessage(message.id);
                },
              ),
            if (widget.isAdmin && message.id != _highlightMessageId)
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Pin Message'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pinService.pinMessage(widget.groupId, message.id);
                  await _loadPinnedMessage();
                },
              ),
            if (!isSender)
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Report Message'),
                onTap: () async {
                  Navigator.pop(context);
                  await _chatService.reportMessage(message.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions),
                title: const Text('React to Message'),
                onTap: () {
                  Navigator.pop(context);
                  _showReactionPicker(context, message);
                },
              ),
            if (widget.isAdmin && message.id == _highlightMessageId)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Unpin Message'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pinService.unpinMessage(widget.groupId);
                  await _loadPinnedMessage();
                },
              ),
          ],
        );
      },
    );
  }

  void _showReactionPicker(BuildContext context, GroupMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final emojis = ['❤️', '🔥', '🙏', '😂', '👍', '👀'];
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            spacing: 10,
            children: emojis
                .map((e) => GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        final userId = Supabase.instance.client.auth.currentUser!.id;
                        await Supabase.instance.client
                            .from('message_reactions')
                            .delete()
                            .match({'message_id': message.id, 'user_id': userId});
                        await _chatService.addReaction(message.id, e);
                        setState(() {});
                      },
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          if (notification.metrics.pixels <= 0 && notification.scrollDelta != null && notification.scrollDelta! > 10) {
            // User is at top and pulled down
            FocusManager.instance.primaryFocus?.unfocus();
          }
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox.shrink(),
                  Expanded(
                    child: MessageListView(
                      groupId: widget.groupId,
                      userId: _userId ?? '',
                      scrollController: _scrollController,
                      reactionMap: _reactionMap,
                      onLongPress: _showMessageOptions,
                      formatTimestamp: _formatSmartTimestamp,
                      highlightMessageId: _highlightMessageId,
                      onMessagesRendered: () {
                        if (!_initialScrollDone) {
                          _scrollToBottom(instant: true);
                          _initialScrollDone = true;
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InputRow(
                      controller: _messageController,
                      onSend: _sendMessage,
                      onFilePicked: (file) async {
                        final url = await _storageService.uploadFile(file, widget.groupId);
                        final isImage = url.endsWith('.png') || url.endsWith('.jpg') || url.endsWith('.jpeg');
                        await _chatService.sendMessage(
                          widget.groupId,
                          isImage ? '[Image]' : '[File]',
                          fileUrl: url,
                        );
                        _scrollToBottom();
                      },
                    ),
                  ),
                ],
              ),
              if (_showJumpToLatest)
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: FloatingActionButton.small(
                    onPressed: _scrollToBottom,
                    child: const Icon(Icons.arrow_downward),
                  ),
                ),
            ],
          ),
      ),
    );
  }
}
