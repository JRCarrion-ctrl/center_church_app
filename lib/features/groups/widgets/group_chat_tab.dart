// File: lib/features/groups/widgets/group_chat_tab.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../models/group_message.dart';
import '../group_chat_service.dart';
import '../chat_storage_service.dart';
import '../media_cache_service.dart';

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
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = GroupChatService();
  final _storageService = ChatStorageService();

  bool _showJumpToLatest = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      final threshold = 300; // pixels from bottom
      final maxScroll = _scrollController.position.maxScrollExtent;
      final current = _scrollController.position.pixels;

      setState(() {
        _showJumpToLatest = (maxScroll - current) > threshold;
      });
    });
  }

  Map<String, List<GroupMessage>> _groupMessagesByDay(List<GroupMessage> messages) {
    final Map<String, List<GroupMessage>> grouped = {};

    for (var msg in messages) {
      final local = msg.createdAt.toLocal();
      final today = DateTime.now();
      final msgDay = DateTime(local.year, local.month, local.day);

      String label;
      if (msgDay == DateTime(today.year, today.month, today.day)) {
        label = 'Today';
      } else if (msgDay == DateTime(today.year, today.month, today.day - 1)) {
        label = 'Yesterday';
      } else {
        label = DateFormat('MMMM d, y').format(local);
      }

      grouped.putIfAbsent(label, () => []).add(msg);
    }

    return grouped;
  }

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

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

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    final url = await _storageService.uploadFile(file, widget.groupId);
    final isImage = url.endsWith('.png') || url.endsWith('.jpg') || url.endsWith('.jpeg');

    await _chatService.sendMessage(
      widget.groupId,
      isImage ? '[Image]' : '[File]',
      fileUrl: url,
    );

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
          ],
        );
      },
    );
  }

  Widget _buildMessageContent(GroupMessage msg) {
    if (msg.fileUrl != null) {
      final isImage = msg.fileUrl!.endsWith('.png') || msg.fileUrl!.endsWith('.jpg') || msg.fileUrl!.endsWith('.jpeg');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage)
            FutureBuilder<File>(
              future: MediaCacheService().getMediaFile(msg.fileUrl!),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return const Icon(Icons.broken_image);
                }
                return Image.file(snapshot.data!, height: 200, fit: BoxFit.cover);
              },
            )
          else
            InkWell(
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final localFile = await MediaCacheService().getMediaFile(msg.fileUrl!);
                  await launchUrl(Uri.file(localFile.path));
                } catch (e) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Failed to open file')),
                  );
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_file),
                  const SizedBox(width: 4),
                  Flexible(child: Text(msg.fileUrl!.split('/').last)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(msg.content, style: const TextStyle(fontSize: 15)),
        ],
      );
    }

    return Text(msg.content);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: StreamBuilder<List<GroupMessage>>(
                stream: _chatService.streamMessages(widget.groupId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!;
                  final grouped = _groupMessagesByDay(messages);
                  if (messages.isEmpty) return const Center(child: Text("No messages yet."));

                  return ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    children: grouped.entries
                    .toList()
                    .reversed
                    .expand((entry) {
                      final section = <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Text(
                              '— ${entry.key} —',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          ),
                        ),
                      ];

                      final sortedMessages = entry.value.toList()
                        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                      
                      section.addAll(sortedMessages.map((msg) {
                        if (msg.deleted) return const SizedBox.shrink();

                        final isMe = msg.senderId == _userId;

                        return GestureDetector(
                          onLongPress: () => _showMessageOptions(msg),
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
                                  _buildMessageContent(msg),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatSmartTimestamp(msg.createdAt),
                                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }));

                      return section;
                    }).toList(),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _sendFile,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
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
}
