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
    this.onMessagesRendered,
    required this.chatService,
  });

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<MessageListView> {
  static const _pageSize = 50;
  static const _cacheCap = 200;
  static const _scrollLoadThreshold = 200.0;

  // Source of truth for messages, ordered newest to oldest.
  final List<GroupMessage> _messages = [];
  // ✅ FIX: List for rendering, includes GroupMessage objects and String date headers.
  final List<dynamic> _displayList = [];

  bool _isLoading = false;
  bool _hasMore = true;
  StreamSubscription<List<GroupMessage>>? _newMsgSub;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    _initialize();
  }

  @override
  void didUpdateWidget(covariant MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groupId != oldWidget.groupId) {
      dev.log('Group ID changed. Reinitializing message list.');
      _resetAndInitialize();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _newMsgSub?.cancel();
    super.dispose();
  }

  void _resetAndInitialize() {
    _newMsgSub?.cancel();
    _messages.clear();
    _displayList.clear();
    _isLoading = false;
    _hasMore = true;
    setState(() {}); // Clear the view immediately
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    final cached = await _loadCachedMessages();
    if (mounted && cached.isNotEmpty) {
      _messages.addAll(cached);
      _rebuildDisplayList();
      setState(() {}); // Render cached messages immediately
    }
    // ✅ FIX: This function now handles the race condition.
    await _fetchAndSubscribe();
  }

  /// ✅ FIX: This function atomically fetches initial messages and subscribes to new ones.
  Future<void> _fetchAndSubscribe() async {
    final syncTime = DateTime.now().toUtc();
    _listenToNewMessages(since: syncTime);
    await _loadMessages(isInitial: true, upTo: syncTime);
  }

  void _onScroll() {
    if (_isLoading || !_hasMore || !widget.scrollController.hasClients) return;
    if (widget.scrollController.position.pixels <= _scrollLoadThreshold) {
      _loadMessages();
    }
  }

  /// Optimistically adds a sent message to the top of the list.
  void addSentMessage(GroupMessage message) {
    if (!mounted || _messages.any((m) => m.id == message.id)) return;
    setState(() {
      _messages.insert(0, message);
      _rebuildDisplayList();
    });
  }

  void _listenToNewMessages({required DateTime since}) {
    _newMsgSub?.cancel();
    _newMsgSub = widget.chatService.streamNewMessages(
      groupId: widget.groupId,
      since: since,
    ).listen((newMessages) {
      if (!mounted || newMessages.isEmpty) return;
      final existingIds = _messages.map((m) => m.id).toSet();
      final uniqueNewMessages = newMessages.where((m) => !existingIds.contains(m.id)).toList();

      if (uniqueNewMessages.isEmpty) return;
      
      setState(() {
        _messages.insertAll(0, uniqueNewMessages);
        _rebuildDisplayList();
      });
    }, onError: (err) {
      dev.log("[STREAM] Error in message stream listener", error: err);
    });
  }

  Future<void> _loadMessages({bool isInitial = false, DateTime? upTo}) async {
    if (_isLoading && !isInitial) return;
    setState(() => _isLoading = true);

    double? oldScrollOffset;
    double? oldMaxScrollExtent;
    
    // 1. Store old scroll metrics before loading new data
    if (!isInitial && widget.scrollController.hasClients) {
      oldScrollOffset = widget.scrollController.offset;
      oldMaxScrollExtent = widget.scrollController.position.maxScrollExtent;
    }

    try {
      final offset = isInitial ? 0 : _messages.length;
      final serverMessages = await widget.chatService.getMessagesPaginated(
        groupId: widget.groupId,
        limit: _pageSize,
        offset: offset,
        upTo: upTo, // Pass the sync timestamp for the initial fetch
      );

      if (!mounted) return;

      final bool newMessagesLoaded = serverMessages.isNotEmpty;
      
      if (isInitial) {
        _messages.clear();
      }
      
      final existingIds = _messages.map((m) => m.id).toSet();
      _messages.addAll(serverMessages.where((m) => !existingIds.contains(m.id)));
      _hasMore = serverMessages.length == _pageSize; 
      _rebuildDisplayList();

      if (isInitial && widget.onMessagesRendered != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onMessagesRendered!();
        });
      }
      
      // 2. Restore scroll position after setState and list rebuild (ONLY if new data loaded)
      if (!isInitial && newMessagesLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.scrollController.hasClients && oldMaxScrollExtent != null) {
            final newMaxScrollExtent = widget.scrollController.position.maxScrollExtent;
            final extentChange = newMaxScrollExtent - oldMaxScrollExtent;
            
            // Adjust the scroll position to keep the current messages in view
            widget.scrollController.jumpTo(oldScrollOffset! + extentChange);
          }
        });
      }
      unawaited(_cacheMessages());
    } catch (e, st) {
      dev.log('Failed to load messages in ListView', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ FIX: Fetches the latest messages by resetting and re-initializing, bypassing cache.
  Future<void> _handleRefresh() async {
    _newMsgSub?.cancel();
    _messages.clear();
    _displayList.clear();
    _hasMore = true;
    setState(() {}); // Show loading indicator
    await _fetchAndSubscribe();
  }
  
  /// ✅ FIX: Pre-processes messages to insert date headers for efficient rendering.
  void _rebuildDisplayList() {
    _displayList.clear();
    if (_messages.isEmpty) return;

    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      final isLastMessage = i == _messages.length - 1;
      bool showHeader = false;

      if (isLastMessage) {
        showHeader = true;
      } else {
        final nextMessage = _messages[i + 1];
        final msgDate = DateUtils.dateOnly(message.createdAt.toLocal());
        final nextMsgDate = DateUtils.dateOnly(nextMessage.createdAt.toLocal());
        showHeader = !DateUtils.isSameDay(msgDate, nextMsgDate);
      }
      
      // Add the message bubble first because the list is reversed.
      _displayList.add(message);
      if (showHeader) {
        _displayList.add(_formatDateHeader(message.createdAt.toLocal()));
      }
    }
  }

  Future<List<GroupMessage>> _loadCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_messages_${widget.groupId}');
      if (cached == null) return [];

      final decoded = jsonDecode(cached) as List;
      return decoded.map((m) => GroupMessage.fromMap(m as Map<String, dynamic>)).toList();
    } catch (e, st) {
      dev.log('Failed to load cached messages', error: e, stackTrace: st);
      return [];
    }
  }

  Future<void> _cacheMessages() async {
    try {
      final toCache = _messages.take(_cacheCap).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_messages_${widget.groupId}',
        jsonEncode(toCache.map((m) => m.toMap()).toList()),
      );
    } catch (e, st) {
      dev.log('Failed to cache messages', error: e, stackTrace: st);
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay == today) return 'Today'.tr();
    if (msgDay == yesterday) return 'Yesterday'.tr();
    return DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_displayList.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_displayList.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          'Be the first to say something!'.tr(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final scrollPhysics = _hasMore
        ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
        : const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
        
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.builder(
        controller: widget.scrollController,
        physics: scrollPhysics,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        reverse: true,
        itemCount: _displayList.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _displayList.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = _displayList[index];

          if (item is String) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                item,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            );
          }
          
          if (item is GroupMessage) {
            final message = item;
            final isMe = message.senderId == widget.userId;
            
            // --- LOGIC START: Determine if name should be shown ---
            bool showName = false;
            
            if (!isMe) {
              // Because list is reversed, index + 1 is the message "above" (older)
              final isTopMessage = index + 1 >= _displayList.length;

              if (isTopMessage) {
                showName = true; // First message ever
              } else {
                final previousItem = _displayList[index + 1];
                
                if (previousItem is String) {
                  showName = true; // Above is a date header
                } else if (previousItem is GroupMessage) {
                  // Only show if the previous sender was different
                  if (previousItem.senderId != message.senderId) {
                    showName = true;
                  }
                }
              }
            }
            // --- LOGIC END ---

            return GroupMessageBubble(
              message: message,
              isMe: isMe,
              
              // --- PASS THE CALCULATED VALUES ---
              showSenderName: showName,
              // This matches the field in your GroupMessage model file
              senderName: message.senderName ?? "Unknown", 
              // ----------------------------------

              onLongPress: () => widget.onLongPress(message),
              contentBuilder: () => MessageContentView(message: message, isMe: isMe),
              formattedTimestamp: widget.formatTimestamp(message.createdAt),
              reactions: widget.reactionMap[message.id] ?? [],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}