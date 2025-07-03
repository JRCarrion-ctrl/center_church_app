// File: lib/features/groups/widgets/group_chat_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../models/group_message.dart';
import '../group_chat_service.dart';
import '../chat_storage_service.dart';
import '../pages/group_info_page.dart';
import 'message_list_view.dart';
import 'input_row.dart';

class GroupChatTab extends StatefulWidget {
  final String groupId;
  final bool isAdmin;

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

  bool _showJumpToLatest = false;

  @override
  void initState() {
    super.initState();

    _chatService.getReactions(widget.groupId).then((map) {
      setState(() => _reactionMap.addAll(map));
    });

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
      final shouldShow = (_scrollController.position.maxScrollExtent - _scrollController.offset) > 300;

      if (_showJumpToLatest != shouldShow) {
        setState(() => _showJumpToLatest = shouldShow);
      }
    });
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
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
          children: emojis.map((e) => GestureDetector(
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
          )).toList(),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildTopHeader(context),
            Expanded(
              child: MessageListView(
                groupId: widget.groupId,
                userId: _userId ?? '',
                scrollController: _scrollController,
                reactionMap: _reactionMap,
                onLongPress: _showMessageOptions,
                formatTimestamp: _formatSmartTimestamp,
              ),
          ),
          InputRow(
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
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return FutureBuilder<PostgrestMap?>(
      future: Supabase.instance.client
          .from('groups')
          .select('name, photo_url')
          .eq('id', widget.groupId)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox(height: 60, child: Center(child: Text('Failed to load group info')));
        }

        final group = snapshot.data!;
        final groupName = group['name'] ?? 'Group';
        final photoUrl = group['photo_url'] ?? 'https://via.placeholder.com/100';

        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupInfoPage(
                groupId: widget.groupId,
                isAdmin: widget.isAdmin,
              ),
            ),
          ),
          child: Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(photoUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    groupName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }
} 
