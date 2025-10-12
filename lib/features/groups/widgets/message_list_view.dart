// File: lib/features/groups/widgets/message_list_view.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../features/groups/models/group_message.dart';
import '../../../features/groups/group_chat_service.dart';
import 'group_message_bubble.dart';
import 'message_content_view.dart';

class MessageListView extends StatefulWidget {
  final String groupId;
  final String userId;
  final ScrollController scrollController;
  final Map<String, List<String>> reactionMap;
  final void Function(GroupMessage) onLongPress;
  final String Function(DateTime) formatTimestamp;
  final String? highlightMessageId;
  final VoidCallback? onMessagesRendered;
  final GroupChatService chatService;

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
    required this.chatService,
  });

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<MessageListView> {
  static const _pageSize = 30;
  static const _cacheCap = 200;
  static const _scrollLoadThreshold = 200.0;

  late GroupChatService _chatService;
  StreamSubscription<GroupMessage>? _newMsgSub;

  final List<GroupMessage> _messages = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0; // New variable to track the offset

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    _chatService = widget.chatService;

    _initialize();
  }

  void _initialize() async {
    final cached = await _loadCachedMessages();
    _messages.addAll(cached);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (_messages.isEmpty) {
      setState(() => _isLoading = true);
    }
    
    _currentOffset = _messages.length; // Initialize offset with cached messages
    await _loadMessages(limit: _pageSize, offset: _currentOffset, isInitial: true);
    
    _listenToNewMessages(
      since: _messages.isNotEmpty
          ? _messages.last.createdAt.toUtc()
          : DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
    );
  }

  @override
  void didUpdateWidget(covariant MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groupId != oldWidget.groupId) {
      dev.log('Group ID changed. Reinitializing message list.');
      _messages.clear();
      _isLoading = false;
      _hasMore = true;
      _currentOffset = 0; // Reset offset on group change
      _newMsgSub?.cancel();
      _initialize();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _newMsgSub?.cancel();
    super.dispose();
  }

  void _listenToNewMessages({required DateTime since}) {
    _newMsgSub?.cancel();
    _newMsgSub = _chatService
        .streamNewMessages(widget.groupId, since: since)
        .listen((newMessage) {
          if (!mounted) return;

          dev.log('[UI] newMessage arrived id=${newMessage.id} createdAt=${newMessage.createdAt} content=${newMessage.content}', name: 'UI');

          final existingIndex = _messages.indexWhere((m) => m.id == newMessage.id);
          if (existingIndex != -1) {
            _messages[existingIndex] = newMessage;
            dev.log('[UI] replaced existing message at index $existingIndex', name: 'UI');
          } else {
            _messages.add(newMessage);
            dev.log('[UI] appended message; _messages length=${_messages.length}', name: 'UI');
          }

          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          setState(() {});
          unawaited(_cacheMessages());
        }, onError: (e, st) => dev.log('STREAM ERR: $e', stackTrace: st));
  }
  
  void _onScroll() {
    if (_isLoading || !_hasMore || !widget.scrollController.hasClients) return;
    
    // Check if user is near the top of the list to load older messages
    if (widget.scrollController.offset >=
        widget.scrollController.position.maxScrollExtent - _scrollLoadThreshold) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    setState(() => _isLoading = true);
    await _loadMessages(limit: _pageSize, offset: _currentOffset);
  }
  
  Future<void> _loadMessages({
    required int limit,
    required int offset,
    bool isInitial = false,
  }) async {
    try {
      final serverMessages = await _chatService.getMessagesPaginated(
        widget.groupId,
        limit: limit,
        offset: offset,
      );

      if (!mounted) return;

      final messageMap = <String, GroupMessage>{
        for (final m in _messages) m.id: m,
      };
      for (final m in serverMessages) {
        messageMap[m.id] = m;
      }

      _messages.clear();
      _messages.addAll(messageMap.values);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      _currentOffset = _messages.length; // Update the offset after loading
      _hasMore = serverMessages.length == limit;
      
      setState(() {});

      if (isInitial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onMessagesRendered?.call();
        });
      }
      unawaited(_cacheMessages());
    } catch (e, st) {
      dev.log('Failed to load messages: $e', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<GroupMessage>> _loadCachedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_messages_${widget.groupId}');
    if (cached == null) return [];
    try {
      final decoded = jsonDecode(cached) as List;
      return decoded
          .map((m) => GroupMessage.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      dev.log('Failed to load cached messages: $e', error: e, stackTrace: st);
      return [];
    }
  }

  Future<void> _cacheMessages() async {
    final toCache = _messages
        .where((m) => !m.deleted)
        .toList();

    final start = toCache.length > _cacheCap ? toCache.length - _cacheCap : 0;
    final sliced = toCache.sublist(start);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cached_messages_${widget.groupId}',
      jsonEncode(sliced.map((m) => m.toMap()).toList()),
    );
  }

  List<_ListItem> _buildListItems() {
    final listItems = <_ListItem>[];
    String? lastDate;

    // Add loading indicator at the top for "load more" functionality
    if (_isLoading) {
      listItems.add(_ListItem(type: _ItemType.loading));
    }
    
    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      final date = message.createdAt.toLocal();
      final formattedDate = _formatDateHeader(date);
      
      // Add date header if the date has changed
      if (formattedDate != lastDate) {
        listItems.add(_ListItem(type: _ItemType.dateHeader, data: formattedDate));
        lastDate = formattedDate;
      }
      
      listItems.add(_ListItem(type: _ItemType.message, data: message));
    }

    return listItems;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay == today) return 'Today';
    if (msgDay == yesterday) return 'Yesterday';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final listItems = _buildListItems();

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(12),
      reverse: true,
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        final item = listItems[index];

        switch (item.type) {
          case _ItemType.loading:
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            );

          case _ItemType.dateHeader:
            return Padding(
              key: ValueKey('header-${item.data}'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  '— ${item.data} —',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            );

          case _ItemType.message:
            final message = item.data as GroupMessage;
            final isMe = message.senderId == widget.userId;
            final isHighlighted = message.id == widget.highlightMessageId;

            return Container(
              key: ValueKey(message.id),
              decoration: isHighlighted
                  ? BoxDecoration(
                      border: Border.all(color: Colors.amber, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              margin: isHighlighted
                  ? const EdgeInsets.symmetric(vertical: 4)
                  : null,
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && !message.deleted)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        (message.senderName != null &&
                                message.senderName!.isNotEmpty)
                            ? message.senderName!
                            : 'Unknown',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  GroupMessageBubble(
                    message: message,
                    isMe: isMe,
                    onLongPress: () => widget.onLongPress(message),
                    contentBuilder: () {
                      if (message.deleted) {
                        return Text(
                          "key_174b".tr(),
                          style: const TextStyle(
                            color: Color.fromARGB(255, 135, 59, 0),
                          ),
                        );
                      }
                      return MessageContentView(message: message, isMe: isMe);
                    },
                    formattedTimestamp:
                        widget.formatTimestamp(message.createdAt),
                    reactions: widget.reactionMap[message.id] ?? [],
                  ),
                ],
              ),
            );
        }
      },
    );
  }
}

enum _ItemType { loading, dateHeader, message }

class _ListItem {
  final _ItemType type;
  final dynamic data;
  _ListItem({required this.type, this.data});
}