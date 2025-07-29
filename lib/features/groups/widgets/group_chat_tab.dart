import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:ccf_app/routes/router_observer.dart';

import '../models/group_message.dart';
import '../group_chat_service.dart';
import '../chat_storage_service.dart';
import '../group_pin_service.dart';
import 'message_list_view.dart';
import 'input_row.dart';

class GroupChatTab extends StatefulWidget {
  final String groupId;
  final bool isAdmin;

  static void scrollToPinnedMessage(BuildContext context) {
    final state = context.findAncestorStateOfType<_GroupChatTabState>();
    state?._scrollToPinnedMessage();
  }

  const GroupChatTab({super.key, required this.groupId, required this.isAdmin});

  @override
  State<GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends State<GroupChatTab> with RouteAware {
  final _reactionMap = <String, List<String>>{};
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final _chatService = GroupChatService();
  final _storageService = ChatStorageService();
  final _pinService = GroupPinService();

  late final RealtimeChannel _reactionChannel;
  bool _showJumpToLatest = false;
  bool _initialScrollDone = false;
  String? _highlightMessageId;
  String? _pinnedPreview;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeChat());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _reactionChannel.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() {}); // Triggers MessageListView to rebuild
  }

  Future<void> _initializeChat() async {
    _reactionMap.addAll(await _chatService.getReactions(widget.groupId));
    await _loadPinnedMessage();

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
            if (mounted) {
              setState(() {
                _reactionMap.putIfAbsent(messageId, () => []).add(emoji);
              });
            }
          },
        )
        .subscribe();

    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final shouldShow = (_scrollController.position.maxScrollExtent - _scrollController.offset) > 300;
    if (_showJumpToLatest != shouldShow && mounted) {
      setState(() => _showJumpToLatest = shouldShow);
    }
  }

  Future<void> _loadPinnedMessage() async {
    final response = await Supabase.instance.client
        .from('groups')
        .select('pinned_message_id')
        .eq('id', widget.groupId)
        .maybeSingle();

    final pinnedId = response?['pinned_message_id'];
    if (pinnedId != null) {
      final message = await Supabase.instance.client
          .from('group_messages')
          .select('content')
          .eq('id', pinnedId)
          .maybeSingle();
      setState(() {
        _highlightMessageId = pinnedId;
        _pinnedPreview = message?['content'];
      });
    } else {
      setState(() {
        _highlightMessageId = null;
        _pinnedPreview = null;
      });
    }
  }

  void _scrollToPinnedMessage() {
    if (_highlightMessageId != null && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  Future<void> _scrollToBottom({bool instant = false}) async {
    await Future.delayed(const Duration(milliseconds: 10));
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    await _chatService.sendMessage(widget.groupId, content);
    _messageController.clear();
    _scrollToBottom();
  }

  void _showMessageOptions(GroupMessage message) {
    final isSender = message.senderId == _userId;
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(children: [
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
      ]),
    );
  }

  void _showReactionPicker(BuildContext context, GroupMessage message) {
    final emojis = ['❤️', '🔥', '🙏', '😂', '👍', '👀'];
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 10,
          children: emojis.map((e) => GestureDetector(
            onTap: () async {
              Navigator.pop(context);
              final userId = Supabase.instance.client.auth.currentUser!.id;
              await Supabase.instance.client
                  .from('message_reactions')
                  .delete()
                  .match({'message_id': message.id, 'user_id': userId});
              await _chatService.addReaction(message.id, e);
              if (mounted) setState(() {});
            },
            child: Text(e, style: const TextStyle(fontSize: 28)),
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels <= 0 &&
            (notification.scrollDelta ?? 0) > 10) {
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
                  if (_highlightMessageId != null && _pinnedPreview != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: GestureDetector(
                        onTap: _scrollToPinnedMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.push_pin, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _pinnedPreview!.length > 80
                                      ? '${_pinnedPreview!.substring(0, 80)}...'
                                      : _pinnedPreview!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: MessageListView(
                      groupId: widget.groupId,
                      userId: _userId ?? '',
                      scrollController: _scrollController,
                      reactionMap: _reactionMap,
                      onLongPress: _showMessageOptions,
                      formatTimestamp: TimeService.formatSmartTimestamp,
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
                      onGifPicked: (gifUrl) async {
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
                bottom: 80,
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
