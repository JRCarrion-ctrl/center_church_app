// File: lib/features/groups/widgets/group_chat_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/core/graph_provider.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:ccf_app/routes/router_observer.dart'; // Ensure router_observer is available

import '../../../app_state.dart';
import '../models/group_message.dart';
import '../group_chat_service.dart';
import '../chat_storage_service.dart';
import 'message_list_view.dart';
import 'input_row.dart';

class GroupChatTab extends StatefulWidget {
  final String groupId;
  final bool isAdmin;

  const GroupChatTab({super.key, required this.groupId, required this.isAdmin});

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
  
  // FIX 1: Store userId safely here
  String? _safeUserId; 

  late GroupChatService _chatService;
  late ChatStorageService _storageService;
  bool _isInitialized = false;

  bool _showJumpToLatest = false;
  bool _initialScrollDone = false;

  Timer? _reactionsTimer;

  // FIX 2: Use the safe local variable
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
      // 1) FIX 3: Read and store the UserId while context is safe
      _safeUserId = context.read<AppState>().profile?.id;

      // 2) Build and initialize services
      final GraphQLClient gql = GraphProvider.of(context);
      _chatService = GroupChatService(
        gql,
        // Pass the safe ID getter, or simply use the stored ID if preferred
        getCurrentUserId: () => _safeUserId,
      );
      _storageService = ChatStorageService(gql);
      
      _isInitialized = true;

      // 3) Initialize subscriptions and listeners
      _initializeChat();
      _subscribeToMemberStatus();
    }

    // 4) Route observer logic
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
    
    // Signal presence when the chat screen becomes active
    _chatService.updateLastSeen(widget.groupId); 
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _reactionsTimer?.cancel();
    _statusSub?.cancel();
    _typingThrottleTimer?.cancel();
    
    // FIX 4: Safely signal stop typing/viewing using the stored _safeUserId
    // Wrap in a check because the service call might still execute async.
    if (_safeUserId != null) {
      _chatService.updateLastTyped(widget.groupId, isTyping: false);
      _chatService.updateLastSeen(widget.groupId); // Final update for last seen
    }
    
    _messageController.removeListener(_onTypingUpdate);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Signal presence when returning to the chat screen
    _chatService.updateLastSeen(widget.groupId);
    setState(() {});
  }
  
  @override
  void didPushNext() {
    // Signal the user is no longer viewing the chat when navigating away
    // FIX 5: Ensure typing status is cleared when leaving the page
    if (_safeUserId != null) {
      _chatService.updateLastTyped(widget.groupId, isTyping: false);
      _chatService.updateLastSeen(widget.groupId);
    }
    
    // Cancel the timer to prevent spurious updates in the background
    _typingThrottleTimer?.cancel();
    _isTyping = false;
  }


  // --- Status and Presence Logic (Remains mostly unchanged, now uses _safeUserId safely) ---

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
    if (_safeUserId == null) return; // Prevent updates if not authenticated

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

  // --- Existing Chat Logic (Remaining methods use _safeUserId implicitly via _chatService) ---

  Future<void> _initializeChat() async {
    // ... (unchanged)
    _reactionMap.addAll(await _chatService.getReactions(widget.groupId));

    _reactionsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
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
    
    // Clear typing status immediately upon sending
    _isTyping = false;
    _typingThrottleTimer?.cancel();
    await _chatService.updateLastTyped(widget.groupId, isTyping: false);

    await _chatService.sendMessage(widget.groupId, content);
    _messageController.clear();
    _scrollToBottom();
  }

  void _showMessageOptions(GroupMessage message) {
    // ... (rest of _showMessageOptions remains unchanged)
    final isSender = message.senderId == _userId;
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(children: [
        if (widget.isAdmin || isSender)
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text("key_162".tr()),
            onTap: () async {
              Navigator.pop(context);
              await _chatService.deleteMessage(message.id);
            },
          ),
        if (!isSender)
          ListTile(
            leading: const Icon(Icons.report),
            title: Text("key_164".tr()),
            onTap: () async {
              Navigator.pop(context);
              await _chatService.reportMessage(message.id);
            },
          ),
        ListTile(
          leading: const Icon(Icons.emoji_emotions),
          title: Text("key_165".tr()),
          onTap: () {
            Navigator.pop(context);
            _showReactionPicker(context, message);
          },
        ),
      ]),
    );
  }

  void _showReactionPicker(BuildContext context, GroupMessage message) {
    // ... (rest of _showReactionPicker remains unchanged)
    final emojis = ['❤️', '🔥', '🙏', '😂', '👍', '👀'];
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 10,
          children: emojis
              .map(
                (e) => GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await _chatService.addReaction(message.id, e);
                    if (!mounted) return;
                    final latest = await _chatService.getReactions(widget.groupId);
                    if (!mounted) return;
                    setState(() {
                      _reactionMap
                        ..clear()
                        ..addAll(latest);
                    });
                  },
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // --- UI Build ---

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

                  // Typing Indicator (NEW)
                  _buildTypingIndicator(),

                  // Input Row
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InputRow(
                      controller: _messageController,
                      onSend: _sendMessage,
                      onFilePicked: (file) async {
                        final url =
                            await _storageService.uploadFile(file, widget.groupId);
                        final isImage = url.endsWith('.png') ||
                            url.endsWith('.jpg') ||
                            url.endsWith('.jpeg') ||
                            url.endsWith('.webp');
                        
                        // Clear typing status
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
                        // Clear typing status
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
                  ),
                ],
              ),
            ),
            if (_showJumpToLatest)
              Positioned(
                bottom: 80 + (_typingMembers.isNotEmpty ? 18 : 0), // Adjust position based on indicator height
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