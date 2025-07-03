// File: lib/features/groups/widgets/group_message_bubble.dart
import 'package:flutter/material.dart';
import '../models/group_message.dart';

class GroupMessageBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMe;
  final VoidCallback onLongPress;
  final Widget Function() contentBuilder;
  final String timestamp;
  final List<String> reactions;

  const GroupMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onLongPress,
    required this.contentBuilder,
    required this.timestamp,
    required this.reactions,
  });

  Map<String, int> _groupedReactions(List<String> reactions) {
    final Map<String, int> grouped = {};
    for (var emoji in reactions) {
      grouped[emoji] = (grouped[emoji] ?? 0) + 1;
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              contentBuilder(),
              const SizedBox(height: 4),
              if (reactions.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: _groupedReactions(reactions).entries.map((entry) =>
                    Chip(
                      label: Text('${entry.key} x${entry.value}'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      backgroundColor: Colors.grey[300],
                    )
                  ).toList(),
                ),
              const SizedBox(height: 4),
              Semantics(
                label: 'Sent at $timestamp',
                child: Text(
                  timestamp,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
