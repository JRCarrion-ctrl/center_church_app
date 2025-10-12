// File: lib/features/groups/widgets/group_chat_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:developer' as dev;

import 'package:ccf_app/core/graph_provider.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:ccf_app/routes/router_observer.dart';

import '../../../app_state.dart';
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
  StreamSubscription<GroupMessage>? _msgSub;
  final _live = <GroupMessage>[];

  late GroupChatService _chatService;
  late ChatStorageService _storageService;
  late GroupPinService _pinService;
  bool _isInitialized = false;

  bool _showJumpToLatest = false;
  bool _initialScrollDone = false;
  String? _highlightMessageId;
  String? _pinnedPreview;

  Timer? _reactionsTimer;

  String? get _userId => context.read<AppState>().profile?.id;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      // 1) Build and initialize services
      final GraphQLClient gql = GraphProvider.of(context);
      _chatService = GroupChatService(
        gql,
        getCurrentUserId: () => context.read<AppState>().profile?.id ?? '',
      );
      _storageService = ChatStorageService(gql);
      _pinService = GroupPinService(gql);
      
      _isInitialized = true;

      // 2) Wire the stream for new messages
      _msgSub = _chatService
          .streamNewMessages(widget.groupId, since: DateTime.utc(2000, 1, 1))
          .listen((m) {
            dev.log('[TAB] stream msg id=${m.id} content=${m.content}', name: 'TAB');
            if (!mounted) return;
            setState(() => _live.add(m));
            _scrollToBottom();
          }, onError: (e, st) {
            dev.log('[TAB] stream error: $e', name: 'TAB', stackTrace: st);
          });
      
      // 3) Other initializations
      _initializeChat();
    }

    // 4) Route observer logic
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    routeObserver.unsubscribe(this);
    _reactionsTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() {});
  }

  Future<void> _initializeChat() async {
    _reactionMap.addAll(await _chatService.getReactions(widget.groupId));
    await _loadPinnedMessage();

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

  Future<void> _loadPinnedMessage() async {
    final client = GraphProvider.of(context);

    const qPinned = r'''
      query PinnedMsg($gid: uuid!) {
        groups_by_pk(id: $gid) { pinned_message_id }
      }
    ''';
    final res = await client.query(QueryOptions(
      document: gql(qPinned),
      variables: {'gid': widget.groupId},
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (res.hasException) {
      setState(() {
        _highlightMessageId = null;
        _pinnedPreview = null;
      });
      return;
    }

    final pinnedId = res.data?['groups_by_pk']?['pinned_message_id'] as String?;
    if (pinnedId == null) {
      setState(() {
        _highlightMessageId = null;
        _pinnedPreview = null;
      });
      return;
    }

    const qContent = r'''
      query PinnedContent($mid: uuid!) {
        group_messages_by_pk(id: $mid) { content }
      }
    ''';
    final res2 = await client.query(QueryOptions(
      document: gql(qContent),
      variables: {'mid': pinnedId},
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    final content = res2.data?['group_messages_by_pk']?['content'] as String?;
    setState(() {
      _highlightMessageId = pinnedId;
      _pinnedPreview = content;
    });
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
    if (_scrollController.hasClients) {
      // jump to bottom (maxScrollExtent) for non-reversed ListView
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = _scrollController.position.maxScrollExtent;
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
            title: Text("key_162".tr()),
            onTap: () async {
              Navigator.pop(context);
              await _chatService.deleteMessage(message.id);
            },
          ),
        if (widget.isAdmin && message.id != _highlightMessageId)
          ListTile(
            leading: const Icon(Icons.push_pin_outlined),
            title: Text("key_163".tr()),
            onTap: () async {
              Navigator.pop(context);
              await _pinService.pinMessage(widget.groupId, message.id);
              await _loadPinnedMessage();
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
        if (widget.isAdmin && message.id == _highlightMessageId)
          ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: Text("key_166".tr()),
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
                      userId: userId,
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
                      chatService: _chatService,
                    ),
                  ),
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