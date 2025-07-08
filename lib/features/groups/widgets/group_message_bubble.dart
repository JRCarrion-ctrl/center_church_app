// File: lib/features/groups/widgets/group_message_bubble.dart
import 'dart:ui';
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

  bool _isEmojiOnly(String? text) {
    if (text == null) return false;
    final stripped = text.replaceAll(RegExp(r'\s'), '');
    final emojiRegex = RegExp(r'^(?:[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{2600}-\u{26FF}]){1,3}\$', unicode: true);
    return emojiRegex.hasMatch(stripped);
  }

  @override
  Widget build(BuildContext context) {
    final messageText = message.content;
    final showLargeEmoji = _isEmojiOnly(messageText);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color.fromARGB(255, 0, 122, 255)
                              : const Color.fromARGB(255, 230, 230, 235),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isMe
                                ? const Color.fromARGB(255, 0, 112, 230)
                                : const Color.fromARGB(255, 210, 210, 215),
                          ),
                        ),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DefaultTextStyle(
                              style: TextStyle(
                                fontSize: showLargeEmoji ? 32 : 16,
                                height: 1.4,
                                color: isMe ? Colors.white : Colors.black,
                              ),
                              child: contentBuilder(),
                            ),
                            const SizedBox(height: 4),
                            Semantics(
                              label: 'Sent at $timestamp',
                              child: Text(
                                timestamp,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMe
                                      ? const Color.fromARGB(255, 255, 255, 255)
                                      : const Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (reactions.isNotEmpty)
                Transform.translate(
                  offset: const Offset(12, -4),
                  child: Wrap(
                    spacing: 6,
                    children:
                        _groupedReactions(reactions).entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color.fromARGB(255, 0, 122, 255)
                              : const Color.fromARGB(255, 230, 230, 235),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isMe
                                ? const Color.fromARGB(255, 0, 112, 230)
                                : const Color.fromARGB(255, 210, 210, 215),
                          ),
                        ),
                        child: Text(
                          '${entry.key} ${entry.value}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}