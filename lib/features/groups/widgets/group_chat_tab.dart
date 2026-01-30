// File: lib/features/groups/widgets/group_chat_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/core/graph_provider.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:ccf_app/routes/router_observer.dart';

import '../../../app_state.dart';
import '../models/group_message.dart';
import '../group_chat_service.dart';
import '../chat_storage_service.dart';
import 'message_list_view.dart';
import 'input_row.dart';

class GroupChatTab extends StatefulWidget {
  final String groupId;
  final bool isAdmin;
  final bool onlyAdminsCanMessage;

  const GroupChatTab({super.key, required this.groupId, required this.isAdmin, this.onlyAdminsCanMessage = false});

  @override
  State<GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends State<GroupChatTab> with RouteAware {
  // --- Real-time Status ---
  final _typingMembers = <String>[];
  StreamSubscription<List<Map<String, dynamic>>>? _statusSub;
  Timer? _typingThrottleTimer;
  bool _isTyping = false;
  
  // --- Existing State ---
  final _reactionMap = <String, List<String>>{};
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  String? _safeUserId; 

  late GroupChatService _chatService;
  late ChatStorageService _storageService;
  bool _isInitialized = false;

  bool _showJumpToLatest = false;
  bool _initialScrollDone = false;

  Timer? _reactionsTimer;

  String? get _userId => _safeUserId;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTypingUpdate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      _safeUserId = context.read<AppState>().profile?.id;

      final GraphQLClient gql = GraphProvider.of(context);
      _chatService = GroupChatService(
        gql,
        getCurrentUserId: () => _safeUserId,
      );
      _storageService = ChatStorageService(gql);
      
      _isInitialized = true;

      _initializeChat();
      _subscribeToMemberStatus();
    }

    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
    
    _chatService.updateLastSeen(widget.groupId); 
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _reactionsTimer?.cancel();
    _statusSub?.cancel();
    _typingThrottleTimer?.cancel();
    
    if (_safeUserId != null) {
      _chatService.updateLastTyped(widget.groupId, isTyping: false);
      _chatService.updateLastSeen(widget.groupId); 
    }
    
    _messageController.removeListener(_onTypingUpdate);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _chatService.updateLastSeen(widget.groupId);
    setState(() {});
  }
  
  @override
  void didPushNext() {
    if (_safeUserId != null) {
      _chatService.updateLastTyped(widget.groupId, isTyping: false);
      _chatService.updateLastSeen(widget.groupId);
    }
    _typingThrottleTimer?.cancel();
    _isTyping = false;
  }

  void _subscribeToMemberStatus() {
    _statusSub = _chatService.streamMemberMetadata(groupId: widget.groupId).listen((statuses) {
      final currentUserId = _safeUserId;
      final newTypingMembers = <String>[];
      final fiveSecondsAgo = DateTime.now().subtract(const Duration(seconds: 5));
      
      for (final status in statuses) {
        final userId = status['user_id'] as String?;
        if (userId == null || userId == currentUserId) continue;

        final lastTypedStr = status['last_typed'] as String?;
        if (lastTypedStr != null) {
          final lastTyped = DateTime.tryParse(lastTypedStr);
          if (lastTyped != null && lastTyped.isAfter(fiveSecondsAgo)) {
            final displayName = status['profile']?['display_name'] as String? ?? 'A member';
            newTypingMembers.add(displayName);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _typingMembers
          ..clear()
          ..addAll(newTypingMembers.toSet().toList());
      });
    });
  }
  
  void _onTypingUpdate() {
    if (_safeUserId == null) return; 

    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _chatService.updateLastTyped(widget.groupId, isTyping: true);
      _resetTypingThrottle();
    } else if (_messageController.text.isEmpty && _isTyping) {
      _isTyping = false;
      _typingThrottleTimer?.cancel();
      _chatService.updateLastTyped(widget.groupId, isTyping: false);
    }
    
    if (_isTyping) {
      _resetTypingThrottle();
    }
  }

  void _resetTypingThrottle() {
    _typingThrottleTimer?.cancel();
    _typingThrottleTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _isTyping = false;
      _chatService.updateLastTyped(widget.groupId, isTyping: false);
    });
  }

  Future<void> _initializeChat() async {
    _reactionMap.addAll(await _chatService.getReactions(widget.groupId));

    _reactionsTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted) return;
      final latest = await _chatService.getReactions(widget.groupId);
      if (!mounted) return;
      setState(() {
        _reactionMap
          ..clear()
          ..addAll(latest);
      });
    });

    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    
    final distanceFromBottom = _scrollController.offset;
    final shouldShow = distanceFromBottom > 300; 

    if (_showJumpToLatest != shouldShow && mounted) {
      setState(() => _showJumpToLatest = shouldShow);
    }
  }

  Future<void> _scrollToBottom({bool instant = false}) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (_scrollController.hasClients) {
      final target = 0.0;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          if (instant) {
            _scrollController.jumpTo(target);
          } else {
            _scrollController.animateTo(
              target,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    _isTyping = false;
    _typingThrottleTimer?.cancel();
    await _chatService.updateLastTyped(widget.groupId, isTyping: false);

    await _chatService.sendMessage(widget.groupId, content);
    _messageController.clear();
    _scrollToBottom();
  }

  void _showMessageOptions(GroupMessage message, Offset tapPosition) {
    final isSender = message.senderId == _userId;
  
    final position = RelativeRect.fromLTRB(
      tapPosition.dx,
      tapPosition.dy,
      tapPosition.dx + 1, 
      tapPosition.dy + 1, 
    );

    showMenu(
      context: context,
      position: position,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          value: 'react',
          child: Row(
            children: [
              const Icon(Icons.emoji_emotions, color: Colors.grey),
              const SizedBox(width: 12),
              Text("key_165".tr()), 
            ],
          ),
        ),
      
        if (widget.isAdmin || isSender)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete, color: Colors.red),
                const SizedBox(width: 12),
                Text("key_162".tr(), style: const TextStyle(color: Colors.red)), 
              ],
            ),
          ),

        if (!isSender)
          PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                const Icon(Icons.report, color: Colors.orange),
                const SizedBox(width: 12),
                Text("key_164".tr()), 
              ],
            ),
          ),
      ],
    ).then((value) async {
      if (value == null) return;

      if (value == 'react') {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) _showFloatingReactionPicker(context, message, tapPosition);
      } else if (value == 'delete') {
        await _chatService.deleteMessage(message.id);
      } else if (value == 'report') {
        try {
          await _chatService.reportMessage(message.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Successfully Reported"),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Failed to report message."),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  void _handleMessageDoubleTap(GroupMessage message, Offset position) {
    _showFloatingReactionPicker(context, message, position);
  }

  void _showFloatingReactionPicker(BuildContext context, GroupMessage message, Offset tapPosition) {
    final emojis = ['❤️', '🔥', '🙏', '😂', '👍', '👀'];
  
    final screenWidth = MediaQuery.of(context).size.width;
    double leftPos = tapPosition.dx - 100; 
    if (leftPos < 10) leftPos = 10;
    if (leftPos + 220 > screenWidth) leftPos = screenWidth - 230;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black12, 
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              top: tapPosition.dy - 70, 
              left: leftPos,
              child: Material(
                color: Colors.transparent,
                child: ScaleTransition(
                  scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: emojis.map((e) {
                        return GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);
                            await _chatService.addReaction(message.id, e);
                            final latest = await _chatService.getReactions(widget.groupId);
                            if(mounted) setState(() => _reactionMap..clear()..addAll(latest));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(e, style: const TextStyle(fontSize: 24)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    if (_typingMembers.isEmpty) {
      return const SizedBox(height: 18);
    }
    
    String text;
    if (_typingMembers.length == 1) {
      text = "${_typingMembers.first} is typing...";
    } else if (_typingMembers.length == 2) {
      text = "${_typingMembers.first} and ${_typingMembers.last} are typing...";
    } else {
      text = "Several members are typing...";
    }
    
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontStyle: FontStyle.italic,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = _userId ?? '';
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canSendMessage = !widget.onlyAdminsCanMessage || widget.isAdmin;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels >= notification.metrics.maxScrollExtent &&
            (notification.scrollDelta ?? 0) < -10) { 
          FocusManager.instance.primaryFocus?.unfocus();
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  // Message List
                  Expanded(
                    child: MessageListView(
                      groupId: widget.groupId,
                      userId: userId,
                      scrollController: _scrollController,
                      reactionMap: _reactionMap,
                      onLongPress: _showMessageOptions,
                      onDoubleTap: _handleMessageDoubleTap,
                      formatTimestamp: TimeService.formatSmartTimestamp,
                      onMessagesRendered: () {
                        if (!_initialScrollDone) {
                          _scrollToBottom(instant: true); 
                          _initialScrollDone = true;
                        }
                      },
                      chatService: _chatService,
                    ),
                  ),

                  // Typing Indicator
                  _buildTypingIndicator(),

                  // Input Row - FIX: Removed curly braces from else block
                  if (canSendMessage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InputRow(
                        controller: _messageController,
                        onSend: _sendMessage,
                        onFilePicked: (file) async {
                          final url = await _storageService.uploadFile(file, widget.groupId);
                          final isImage = url.endsWith('.png') ||
                              url.endsWith('.jpg') ||
                              url.endsWith('.jpeg') ||
                              url.endsWith('.webp');
                        
                          _isTyping = false;
                          _typingThrottleTimer?.cancel();
                          await _chatService.updateLastTyped(widget.groupId, isTyping: false);

                          await _chatService.sendMessage(
                            widget.groupId,
                            isImage ? '[Image]' : '[File]',
                            fileUrl: url,
                          );
                          _scrollToBottom();
                        },
                        onGifPicked: (gifUrl) async {
                          _isTyping = false;
                          _typingThrottleTimer?.cancel();
                          await _chatService.updateLastTyped(widget.groupId, isTyping: false);
                        
                          await _chatService.sendMessage(
                            widget.groupId,
                            '[GIF]',
                            fileUrl: gifUrl,
                            type: 'gif',
                          );
                          _scrollToBottom();
                        },
                      ),
                    )
                  else
                    // ✅ Fixed syntax here
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      alignment: Alignment.center,
                      child: Text(
                        "Only admins can send messages.",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_showJumpToLatest)
              Positioned(
                bottom: 80 + (_typingMembers.isNotEmpty ? 18 : 0), 
                right: 16,
                child: FloatingActionButton.small(
                  onPressed: _scrollToBottom,
                  backgroundColor: isDark
                      ? const Color.fromARGB(255, 60, 60, 65)
                      : const Color.fromARGB(255, 230, 230, 240),
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  child: const Icon(Icons.arrow_downward),
                ),
              ),
          ],
        ),
      ),
    );
  }
}