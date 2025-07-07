// File: lib/features/groups/widgets/message_content_view.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../media_cache_service.dart';
import '../models/group_message.dart';

class MessageContentView extends StatelessWidget {
  final GroupMessage message;
  final bool isMe;

  const MessageContentView({super.key, required this.message, required this.isMe,});
  

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'mp3':
      case 'wav':
        return Icons.audiotrack;
      case 'zip':
      case 'rar':
        return Icons.archive;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (message.fileUrl != null) {
      final fileUrl = message.fileUrl!;
      final extension = fileUrl.split('.').last;
      final isImage = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'heic'].contains(extension.toLowerCase());

      final mediaFuture = MediaCacheService().getMediaFile(fileUrl);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage)
            FutureBuilder<File>(
              future: mediaFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/image_placeholder.png', height: 200, fit: BoxFit.cover),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Column(
                    children: const [
                      Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      Text('Failed to load image', style: TextStyle(fontSize: 12)),
                    ],
                  );
                }
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(snapshot.data!),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(snapshot.data!, height: 200, fit: BoxFit.cover),
                  ),
                );
              },
            )
          else
            FutureBuilder<File>(
              future: mediaFuture,
              builder: (context, snapshot) {
                return InkWell(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final localFile = await mediaFuture;
                      await launchUrl(Uri.file(localFile.path));
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Failed to open file')),
                      );
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(64, 255, 255, 255),
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(_getFileIcon(extension), size: 28),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                fileUrl.split('/').last,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (message.content.trim().isNotEmpty && message.content.trim() != "[Image]")

            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 15, 
                  fontWeight: FontWeight.w400, 
                  color: isMe ? Colors.white : Colors.black87,
                  ),
              ),
            ),
        ],
      );
    }

    return Text(
      message.content,
      style: TextStyle(
        fontSize: 15, 
        fontWeight: FontWeight.w400,
        color: isMe ? Colors.white : Colors.black87,
      ),
    );
  }
}
