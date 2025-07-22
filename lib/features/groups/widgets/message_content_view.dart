// File: lib/features/groups/widgets/message_content_view.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../media_cache_service.dart';
import '../models/group_message.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

class MessageContentView extends StatefulWidget {
  final GroupMessage message;
  final bool isMe;
  final double? fontSize;

  const MessageContentView({
    super.key,
    required this.message,
    required this.isMe,
    this.fontSize,
  });

  @override
  State<MessageContentView> createState() => _MessageContentViewState();
}

class _MessageContentViewState extends State<MessageContentView> {
  dynamic _previewData;
  static const _placeholders = {'[Image]', '[GIF]', '[File]'};

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
    final content = widget.message.content.trim();
    final fileUrl = widget.message.fileUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.isMe
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    final urlRegex = RegExp(r'https?:\/\/[^\s]+');
    final previewUrl = urlRegex.firstMatch(content)?.group(0);

    if (fileUrl != null) {
      final extension = fileUrl.split('.').last;
      final isImage = ['png', 'jpg', 'jpeg', 'webp', 'heic']
          .contains(extension.toLowerCase());
      final isGif = extension.toLowerCase() == 'gif';

      if (isGif) {
        return _buildGifView(fileUrl, content, textColor);
      }

      final mediaFuture = MediaCacheService().getMediaFile(fileUrl);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<File>(
            future: mediaFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _buildPlaceholderImage();
              }
              if (snapshot.hasError || snapshot.data == null) {
                return _buildErrorFileView();
              }

              final file = snapshot.data!;
              return isImage
                  ? _buildImageView(file)
                  : _buildFileCard(fileUrl, file, extension, textColor);
            },
          ),
          if (content.isNotEmpty && !_placeholders.contains(content))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: widget.fontSize ?? 15,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (previewUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () async {
                final uri = Uri.parse(previewUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: LinkPreview(
                enableAnimation: true,
                onPreviewDataFetched: (data) {
                  setState(() {
                    _previewData = data;
                  });
                },
                previewData: _previewData,
                text: previewUrl,
                width: MediaQuery.of(context).size.width * 0.75,
                padding: const EdgeInsets.all(12),
                textStyle: TextStyle(
                  fontSize: widget.fontSize ?? 15,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                ),
                metadataTextStyle: TextStyle(
                  fontSize: 13,
                  color: textColor.withAlpha((0.8 * 255).toInt()),
                ),
                metadataTitleStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                linkStyle: const TextStyle(color: Colors.blue),
              ),
            ),
          ),
        if (content.isNotEmpty && !_placeholders.contains(content))
          Linkify(
            text: previewUrl != null ? content.replaceFirst(previewUrl, '').trim() : content,
            style: TextStyle(
              fontSize: widget.fontSize ?? 15,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
            linkStyle: const TextStyle(color: Colors.blueAccent),
            onOpen: (link) async {
              final uri = Uri.parse(link.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch link')),
                  );
                }
              }
            },
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage() => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/image_placeholder.png',
          height: 200,
          fit: BoxFit.cover,
        ),
      );

  Widget _buildErrorFileView() => Column(
        children: const [
          Icon(Icons.broken_image, size: 48, color: Colors.grey),
          Text('Failed to load file', style: TextStyle(fontSize: 12)),
        ],
      );

  Widget _buildImageView(File file) => GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(file),
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(file, height: 200, fit: BoxFit.cover),
        ),
      );

  Widget _buildFileCard(String fileUrl, File file, String extension, Color textColor) {
    return InkWell(
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await launchUrl(Uri.file(file.path));
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color.fromARGB(64, 255, 255, 255)
                  : const Color.fromARGB(64, 0, 0, 0),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(_getFileIcon(extension), size: 28, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileUrl.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGifView(String gifUrl, String content, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(gifUrl),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              gifUrl,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => const Column(
                children: [
                  Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  Text('Failed to load GIF', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        if (content.isNotEmpty && !_placeholders.contains(content))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              content,
              style: TextStyle(
                fontSize: widget.fontSize ?? 15,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
      ],
    );
  }
}