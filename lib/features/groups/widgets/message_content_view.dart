// File: lib/features/groups/widgets/message_content_view.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../media_cache_service.dart';
import '../models/group_message.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

extension FileExtension on String {
  bool get isImage => ['png', 'jpg', 'jpeg', 'webp', 'heic'].contains(toLowerCase());
  bool get isVideo => ['mp4', 'mov', 'webm'].contains(toLowerCase());
  bool get isGif => toLowerCase() == 'gif';
}

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
  Future<File?>? _mediaFuture;

  @override
  void initState() {
    super.initState();
    _prepareAutoDownload();
  }

  Future<void> _prepareAutoDownload() async {
    final fileUrl = widget.message.fileUrl;
    if (fileUrl == null) return;

    final prefs = await SharedPreferences.getInstance();
    final wifiOnly = prefs.getBool('mediaWifiOnly') ?? true;
    final autoDownloadImages = prefs.getBool('autoDownloadImages') ?? true;
    final autoDownloadVideos = prefs.getBool('autoDownloadVideos') ?? false;

    final ext = fileUrl.split('.').last;

    if ((ext.isImage && autoDownloadImages) || (ext.isVideo && autoDownloadVideos)) {
      if (wifiOnly) {
        final result = await Connectivity().checkConnectivity();
        if (!result.contains(ConnectivityResult.wifi)) {
          setState(() => _mediaFuture = Future.value(null));
          return;
        }
      }
      setState(() {
        _mediaFuture = MediaCacheService().getMediaFile(fileUrl)
            .then<File?>((file) => file)
            .onError((error, _) {
              debugPrint('Media download error: \$error');
              return Future.value(null);
            });
      });
    } else {
      setState(() => _mediaFuture = Future.value(null));
    }
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc':
      case 'docx': return Icons.description;
      case 'mp3':
      case 'wav': return Icons.audiotrack;
      case 'zip':
      case 'rar': return Icons.archive;
      case 'xls':
      case 'xlsx': return Icons.table_chart;
      case 'ppt':
      case 'pptx': return Icons.slideshow;
      case 'txt': return Icons.text_snippet;
      default: return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.message.content.trim();
    final fileUrl = widget.message.fileUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    final previewUrl = RegExp(r'https?:\/\/[^\s]+').firstMatch(content)?.group(0);
    final scaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final effectiveFontSize = (widget.fontSize ?? 15) * scaleFactor;

    if (fileUrl != null) {
      final extension = fileUrl.split('.').last;

      if (extension.isGif) {
        return _buildGifView(fileUrl, content, textColor, effectiveFontSize);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<File?>(
            future: _mediaFuture ?? MediaCacheService().getMediaFile(fileUrl),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _buildPlaceholderImage();
              }
              final file = snapshot.data;
              if (file == null) return _buildErrorFileView();
              return extension.isImage
                  ? _buildImageView(file)
                  : _buildFileCard(fileUrl, file, extension, textColor);
            },
          ),
          if (content.isNotEmpty && !_placeholders.contains(content))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                content,
                style: TextStyle(fontSize: effectiveFontSize, fontWeight: FontWeight.w400, color: textColor),
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
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: LinkPreview(
                enableAnimation: true,
                onPreviewDataFetched: (data) => WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _previewData = data);
                }),
                previewData: _previewData,
                text: previewUrl,
                width: MediaQuery.of(context).size.width * 0.75,
                padding: const EdgeInsets.all(12),
                textStyle: TextStyle(fontSize: effectiveFontSize, fontWeight: FontWeight.w400, color: textColor),
                metadataTextStyle: TextStyle(
                  fontSize: (widget.fontSize ?? 13) * scaleFactor,
                  color: textColor.withAlpha((0.8 * 255).toInt()),
                ),
                metadataTitleStyle: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                linkStyle: const TextStyle(color: Colors.blue),
              ),
            ),
          ),
        if (content.isNotEmpty && !_placeholders.contains(content))
          Linkify(
            text: previewUrl != null ? content.replaceAll(previewUrl, '').trim() : content,
            style: TextStyle(fontSize: effectiveFontSize, fontWeight: FontWeight.w400, color: textColor),
            linkStyle: const TextStyle(color: Colors.blueAccent),
            onOpen: (link) async {
              final uri = Uri.parse(link.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not launch link')),
                );
              }
            },
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage() => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset('assets/image_placeholder.png', height: 200, fit: BoxFit.cover),
      );

  Widget _buildErrorFileView() => const Column(
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey),
          Text('Failed to load file', style: TextStyle(fontSize: 12)),
        ],
      );

  Widget _buildImageView(File file) => GestureDetector(
    onTap: () => showDialog(
      context: context,
      builder: (_) => Stack(
        children: [
          Container(
            color: Colors.black,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.file(file),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 16,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(file, height: 200, fit: BoxFit.cover),
    ),
  );

  Widget _buildFileCard(String fileUrl, File file, String extension, Color textColor) => InkWell(
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await launchUrl(Uri.file(file.path));
          } catch (e) {
            debugPrint('Error opening file: \$e\n\$s');
            messenger.showSnackBar(const SnackBar(content: Text('Failed to open file')));
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
                      style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildGifView(String gifUrl, String content, Color textColor, double fontSize) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(gifUrl)),
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
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w400, color: textColor),
              ),
            ),
        ],
      );
}
