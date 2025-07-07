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
    await _loadCachedMessages(); // Load cache first
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
    await _cacheMessages(); // Save to cache
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
    final jsonList = _messages.map((m) => m.toMap()).toList();
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

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final grouped = _groupMessagesByDay(_messages);
    final List<Widget> messageWidgets = [];

    for (final entry in grouped.entries.toList().reversed) {
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
        if (msg.deleted) return const SizedBox.shrink();

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
          child: GroupMessageBubble(
            message: msg,
            isMe: isMe,
            onLongPress: () => widget.onLongPress(msg),
            contentBuilder: () => MessageContentView(message: msg, isMe: isMe),
            timestamp: widget.formatTimestamp(msg.createdAt),
            reactions: widget.reactionMap[msg.id] ?? [],
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
