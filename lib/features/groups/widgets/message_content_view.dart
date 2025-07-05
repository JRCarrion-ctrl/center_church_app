// File: lib/features/groups/widgets/message_content_view.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../media_cache_service.dart';
import '../models/group_message.dart';

class MessageContentView extends StatelessWidget {
  final GroupMessage message;

  const MessageContentView({super.key, required this.message});

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
                  return Image.asset('assets/image_placeholder.png', height: 200, fit: BoxFit.cover);
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
                        child: Image.file(snapshot.data!),
                      ),
                    );
                  },
                  child: Image.file(snapshot.data!, height: 200, fit: BoxFit.cover),
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
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
                );
              },
            ),
          if (message.content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(message.content, style: const TextStyle(fontSize: 15)),
            ),
        ],
      );
    }

    return Text(message.content);
  }
}
