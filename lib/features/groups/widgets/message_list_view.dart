// File: lib/features/groups/widgets/message_list_view.dart
import 'package:flutter/material.dart';
import '../../../features/groups/models/group_message.dart';
import 'group_message_bubble.dart';
import '../../../features/groups/group_chat_service.dart';
import 'message_content_view.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MessageListView extends StatefulWidget {
  final String groupId;
  final String userId;
  final ScrollController scrollController;
  final Map<String, List<String>> reactionMap;
  final void Function(GroupMessage) onLongPress;
  final String Function(DateTime) formatTimestamp;
  final String? highlightMessageId;
  final VoidCallback? onMessagesRendered;

  const MessageListView({
    super.key,
    required this.groupId,
    required this.userId,
    required this.scrollController,
    required this.reactionMap,
    required this.onLongPress,
    required this.formatTimestamp,
    this.highlightMessageId,
    this.onMessagesRendered,
  });

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<MessageListView> {
  final GroupChatService _chatService = GroupChatService();
  final List<GroupMessage> _messages = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    widget.scrollController.addListener(_onScroll);
    _listenToNewMessages();
  }

  DateTime _sortDateLabel(String label) {
    final now = DateTime.now();
    if (label == 'Today') return DateTime(now.year, now.month, now.day);
    if (label == 'Yesterday') return DateTime(now.year, now.month, now.day - 1);

    final parts = label.split('/');
    if (parts.length == 3) {
      final month = int.tryParse(parts[0]) ?? 1;
      final day = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? now.year;
      return DateTime(year, month, day);
    }

    return DateTime(2000); // fallback
  }

  void _listenToNewMessages() {
    _chatService.streamNewMessages(widget.groupId).listen((newMessage) {
      if (!_messages.any((m) => m.id == newMessage.id)) {
        setState(() {
          _messages.add(newMessage);
        });
      }
    });
  }

  void _onScroll() {
    if (widget.scrollController.offset <= 200 && !_isLoading && _hasMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    await _loadCachedMessages();
    setState(() => _isLoading = true);
    final newMessages = await _chatService.getMessagesPaginated(
      widget.groupId,
      limit: _pageSize,
      offset: 0,
    );
    setState(() {
      _messages.clear();
      _messages.addAll(newMessages);
      _hasMore = newMessages.length == _pageSize;
      _isLoading = false;
    });
    await _cacheMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMessagesRendered?.call();
    });
  }

  Future<void> _loadMoreMessages() async {
    setState(() => _isLoading = true);
    final newMessages = await _chatService.getMessagesPaginated(
      widget.groupId,
      limit: _pageSize,
      offset: _messages.length,
    );
    setState(() {
      _messages.insertAll(0, newMessages);
      _hasMore = newMessages.length == _pageSize;
      _isLoading = false;
    });
  }

  Future<void> _loadCachedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_messages_${widget.groupId}');
    if (cached != null) {
      final decoded = jsonDecode(cached) as List;
      final cachedMessages = decoded.map((m) => GroupMessage.fromMap(m)).toList();
      setState(() => _messages.addAll(cachedMessages));
      widget.onMessagesRendered?.call();
    }
  }

  Future<void> _cacheMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _messages
        .where((m) => !m.deleted)
        .map((m) => m.toMap())
        .toList();
    await prefs.setString('cached_messages_${widget.groupId}', jsonEncode(jsonList));
  }

  Map<String, List<GroupMessage>> _groupMessagesByDay(List<GroupMessage> messages) {
    final Map<String, List<GroupMessage>> grouped = {};
    final today = DateTime.now();

    for (var msg in messages) {
      final local = msg.createdAt.toLocal();
      final msgDay = DateTime(local.year, local.month, local.day);

      String label;
      if (msgDay == DateTime(today.year, today.month, today.day)) {
        label = 'Today';
      } else if (msgDay == DateTime(today.year, today.month, today.day - 1)) {
        label = 'Yesterday';
      } else {
        label = '${local.month}/${local.day}/${local.year}';
      }

      grouped.putIfAbsent(label, () => []).add(msg);
    }

    return grouped;
  }

  Widget _buildContent(GroupMessage msg, bool isMe) {
    if (msg.deleted) {
      return Text(
        '[Deleted Message]',
        style: TextStyle(
          color: const Color.fromARGB(255, 255, 255, 255),
        ),
      );
    }
    return MessageContentView(message: msg, isMe: isMe);
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final grouped = _groupMessagesByDay(_messages);
    final List<Widget> messageWidgets = [];

    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) => _sortDateLabel(a.key).compareTo(_sortDateLabel(b.key)));

    for (final entry in sortedGroups) {
      messageWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              '— ${entry.key} —',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
        ),
      );

      final sortedMessages = entry.value..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      messageWidgets.addAll(sortedMessages.map((msg) {
        final isMe = msg.senderId == widget.userId;
        final isHighlighted = msg.id == widget.highlightMessageId;

        return Container(
          decoration: isHighlighted
              ? BoxDecoration(
                  border: Border.all(color: Colors.amber, width: 2),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          margin: isHighlighted ? const EdgeInsets.symmetric(vertical: 4) : null,
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && !msg.deleted)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    msg.senderName != null && msg.senderName!.isNotEmpty ? msg.senderName! : 'Unknown',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
              GroupMessageBubble(
                message: msg,
                isMe: isMe,
                onLongPress: () => widget.onLongPress(msg),
                contentBuilder: () => _buildContent(msg, isMe),
                timestamp: widget.formatTimestamp(msg.createdAt),
                reactions: widget.reactionMap[msg.id] ?? [],
              ),
            ],
          ),
        );
      }));
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(12),
      children: [
        if (_isLoading && _messages.isNotEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
        ...messageWidgets,
      ],
    );
  }
}
