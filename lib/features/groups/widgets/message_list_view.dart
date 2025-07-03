// File: lib/features/groups/widgets/message_list_view.dart
import 'package:flutter/material.dart';
import '../../../features/groups/models/group_message.dart';
import 'group_message_bubble.dart';
import '../../../features/groups/group_chat_service.dart';
import 'message_content_view.dart';

class MessageListView extends StatelessWidget {
  final String groupId;
  final String userId;
  final ScrollController scrollController;
  final Map<String, List<String>> reactionMap;
  final void Function(GroupMessage) onLongPress;
  final String Function(DateTime) formatTimestamp;

  const MessageListView({
    super.key,
    required this.groupId,
    required this.userId,
    required this.scrollController,
    required this.reactionMap,
    required this.onLongPress,
    required this.formatTimestamp,
  });

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
    final chatService = GroupChatService();

    return StreamBuilder<List<GroupMessage>>(
      stream: chatService.streamMessages(groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!;
        if (messages.isEmpty) return const Center(child: Text("No messages yet."));

        final grouped = _groupMessagesByDay(messages);
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

            final isMe = msg.senderId == userId;

            return GroupMessageBubble(
              message: msg,
              isMe: isMe,
              onLongPress: () => onLongPress(msg),
              contentBuilder: () => MessageContentView(message: msg),
              timestamp: formatTimestamp(msg.createdAt),
              reactions: reactionMap[msg.id] ?? [],
            );
          }));
        }

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(12),
          children: messageWidgets,
        );
      },
    );
  }
}