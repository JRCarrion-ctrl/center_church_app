// File: lib/features/groups/widgets/group_message_bubble.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/group_message.dart';

class GroupMessageBubble extends StatefulWidget {
  final GroupMessage message;
  final bool isMe;
  final bool showSenderName; 
  final String? senderName; 
  final Function(GroupMessage, Offset) onLongPress;
  final Function(GroupMessage, Offset) onDoubleTap;
  final VoidCallback? onReactionsTap; // <--- 1. Add Callback
  final Widget Function() contentBuilder;
  final String formattedTimestamp;
  final List<String> reactions;

  const GroupMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSenderName = false,
    this.senderName,
    required this.onLongPress,
    required this.onDoubleTap,
    this.onReactionsTap, // <--- Add to constructor
    required this.contentBuilder,
    required this.formattedTimestamp,
    required this.reactions,
  });

  @override
  State<GroupMessageBubble> createState() => _GroupMessageBubbleState();
}

class _GroupMessageBubbleState extends State<GroupMessageBubble> {
  Offset? _tapPosition;

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
    final emojiRegex = RegExp(
      r'^(?:[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F1E6}-\u{1F1FF}]){1,3}$',
      unicode: true,
    );
    return emojiRegex.hasMatch(stripped);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final messageText = widget.message.content; 
    final showLargeEmoji = _isEmojiOnly(messageText);

    final backgroundColor = widget.isMe
        ? const Color.fromARGB(255, 0, 122, 255)
        : (isDark
            ? const Color.fromARGB(255, 44, 44, 48)
            : const Color.fromARGB(255, 230, 230, 235));

    final borderColor = widget.isMe
        ? const Color.fromARGB(255, 0, 112, 230)
        : (isDark
            ? const Color.fromARGB(255, 70, 70, 75)
            : const Color.fromARGB(255, 210, 210, 215));

    final textColor = widget.isMe
        ? Colors.white
        : (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      onLongPressStart: (details) {
        HapticFeedback.mediumImpact();
        widget.onLongPress(widget.message, details.globalPosition);
      },
      onDoubleTapDown: (details) {
        _tapPosition = details.globalPosition;
      },
      onDoubleTap: () {
        if (_tapPosition != null) {
          HapticFeedback.mediumImpact();
          widget.onDoubleTap(widget.message, _tapPosition!);
        }
      },
      child: Align(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Column(
            crossAxisAlignment:
                widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (widget.showSenderName && !widget.isMe && widget.senderName != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                  child: Text(
                    widget.senderName!, 
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ),

              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DefaultTextStyle(
                              style: TextStyle(
                                fontSize: showLargeEmoji ? 32 : 16,
                                height: 1.4,
                                color: textColor,
                              ),
                              child: widget.contentBuilder(), 
                            ),
                            const SizedBox(height: 4),
                            Semantics(
                              label: 'Sent at ${widget.formattedTimestamp}', 
                              child: Text(
                                widget.formattedTimestamp, 
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.isMe
                                    ? const Color.fromARGB(160, 255, 255, 255)
                                    : isDark
                                      ? const Color.fromARGB(160, 255, 255, 255)
                                      : const Color.fromARGB(160, 0, 0, 0),
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
              if (widget.reactions.isNotEmpty)
                Transform.translate(
                  offset: widget.isMe ? const Offset(-12, -4) : const Offset(12, -4),
                  // 2. Wrap in GestureDetector
                  child: GestureDetector(
                    onTap: widget.onReactionsTap, 
                    child: Wrap(
                      spacing: 6,
                      children: _groupedReactions(widget.reactions).entries.map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            '${entry.key} ${entry.value}',
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}