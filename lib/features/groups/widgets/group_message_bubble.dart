// File: lib/features/groups/widgets/group_message_bubble.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/group_message.dart';
import 'message_content_view.dart' show isEmojiOnlyMessage;

/// A stable, readable accent color per sender, tuned for the current
/// brightness so names stay legible in light and dark mode.
Color senderAccent(BuildContext context, String key) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  var hash = 0;
  for (final c in key.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, dark ? 0.55 : 0.6, dark ? 0.72 : 0.36).toColor();
}

class GroupMessageBubble extends StatefulWidget {
  final GroupMessage message;
  final bool isMe;

  /// First (oldest) message of a run from the same sender: shows the name.
  final bool showSenderName;

  /// Last (newest) message of a run: shows the avatar and the bubble tail,
  /// and leaves a little more room below.
  final bool isLastInRun;
  final String? senderName;
  final Function(GroupMessage, Offset) onLongPress;
  final Function(GroupMessage, Offset) onDoubleTap;
  final VoidCallback? onReactionsTap;
  final Widget Function() contentBuilder;
  final String formattedTimestamp;
  final List<String> reactions;

  const GroupMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSenderName = false,
    this.isLastInRun = true,
    this.senderName,
    required this.onLongPress,
    required this.onDoubleTap,
    this.onReactionsTap,
    required this.contentBuilder,
    required this.formattedTimestamp,
    required this.reactions,
  });

  @override
  State<GroupMessageBubble> createState() => _GroupMessageBubbleState();
}

class _GroupMessageBubbleState extends State<GroupMessageBubble> {
  static const double _avatarSize = 32;

  Offset? _tapPosition;
  bool _hovering = false;

  void _openMenuAt(Offset globalPosition) => widget.onLongPress(widget.message, globalPosition);

  /// "⋯" next to the bubble on hover (mouse only), opening the same menu as
  /// long-press / right-click: Copy, React, Delete, Report.
  Widget _hoverMenuButton(ColorScheme colorScheme) {
    return AnimatedOpacity(
      opacity: _hovering ? 1 : 0,
      duration: const Duration(milliseconds: 120),
      child: IgnorePointer(
        ignoring: !_hovering,
        child: Builder(
          builder: (ctx) => IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: 'chat_message_options'.tr(),
            icon: Icon(Icons.more_horiz, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              final box = ctx.findRenderObject() as RenderBox;
              _openMenuAt(box.localToGlobal(box.size.center(Offset.zero)));
            },
          ),
        ),
      ),
    );
  }

  Map<String, int> _groupedReactions(List<String> reactions) {
    final Map<String, int> grouped = {};
    for (var emoji in reactions) {
      grouped[emoji] = (grouped[emoji] ?? 0) + 1;
    }
    return grouped;
  }

  Widget _avatar(BuildContext context) {
    if (!widget.isLastInRun) return const SizedBox(width: _avatarSize);
    final name = (widget.senderName ?? '').trim();
    final accent = senderAccent(context, widget.message.senderId);
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: _avatarSize,
        height: _avatarSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.18), shape: BoxShape.circle),
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final isMe = widget.isMe;

    final emojiOnly = isEmojiOnlyMessage(widget.message);

    // Own messages: solid primary. Others: a clean card that stands off the
    // chat background (white with a hairline in light mode, a raised surface
    // in dark mode).
    final Color backgroundColor;
    final Color textColor;
    final Border? border;
    if (isMe) {
      backgroundColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
      border = null;
    } else {
      backgroundColor = dark ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainerLowest;
      textColor = colorScheme.onSurface;
      border = Border.all(color: colorScheme.onSurface.withValues(alpha: dark ? 0.06 : 0.09));
    }

    // Rounded everywhere; only the last bubble of a run gets the small "tail"
    // corner toward the sender, so a run reads as one block.
    const r = Radius.circular(20);
    const joined = Radius.circular(8);
    final tail = widget.isLastInRun ? const Radius.circular(6) : joined;
    final top = widget.showSenderName || isMe ? r : joined;
    final bubbleRadius = isMe
        ? BorderRadius.only(topLeft: r, topRight: widget.showSenderName ? r : joined, bottomLeft: r, bottomRight: tail)
        : BorderRadius.only(topLeft: top, topRight: r, bottomLeft: tail, bottomRight: r);

    final maxBubbleWidth = (MediaQuery.of(context).size.width * 0.78).clamp(0.0, 560.0);
    final timeStyle = TextStyle(
      fontSize: 11.5,
      height: 1.1,
      color: textColor.withValues(alpha: isMe ? 0.75 : 0.6),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final Widget bubble = emojiOnly
        // Big emoji float on their own, no bubble behind them.
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.contentBuilder(),
                Text(widget.formattedTimestamp, style: timeStyle.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          )
        : Container(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: bubbleRadius,
              border: border,
              boxShadow: (!isMe && !dark)
                  ? [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: textColor),
                    child: widget.contentBuilder(),
                  ),
                ),
                const SizedBox(height: 3),
                Semantics(
                  label: 'chat_sent_at'.tr(namedArgs: {'time': widget.formattedTimestamp}),
                  excludeSemantics: true,
                  child: Text(widget.formattedTimestamp, style: timeStyle),
                ),
              ],
            ),
          );

    final reactions = widget.reactions.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: widget.onReactionsTap,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _groupedReactions(widget.reactions).entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: dark ? colorScheme.surfaceContainerHighest : colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      '${entry.key} ${entry.value}',
                      style: TextStyle(fontSize: 13.5, color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ),
          );

    final senderLabel = (widget.showSenderName && !isMe && widget.senderName != null)
        ? Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 3),
            child: Text(
              widget.senderName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: senderAccent(context, widget.message.senderId),
              ),
            ),
          )
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onLongPressStart: (details) {
          HapticFeedback.mediumImpact();
          widget.onLongPress(widget.message, details.globalPosition);
        },
        // Right-click on desktop / web opens the same menu.
        onSecondaryTapDown: (details) => _openMenuAt(details.globalPosition),
        onDoubleTapDown: (details) => _tapPosition = details.globalPosition,
        onDoubleTap: () {
          if (_tapPosition != null) {
            HapticFeedback.mediumImpact();
            widget.onDoubleTap(widget.message, _tapPosition!);
          }
        },
        child: Padding(
          // Tight inside a run, more room between people.
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            top: widget.showSenderName || (isMe && widget.isLastInRun) ? 8 : 1.5,
            bottom: widget.isLastInRun ? 6 : 1.5,
          ),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[_avatar(context), const SizedBox(width: 8)],
              if (isMe) _hoverMenuButton(colorScheme),
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?senderLabel,
                    bubble,
                    ?reactions,
                  ],
                ),
              ),
              if (!isMe) _hoverMenuButton(colorScheme),
            ],
          ),
        ),
      ),
    );
  }
}
