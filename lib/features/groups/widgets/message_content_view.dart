// File: lib/features/groups/widgets/message_content_view.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:open_filex/open_filex.dart';

import '../media_cache_service.dart';
import '../models/group_message.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:easy_localization/easy_localization.dart';

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
    if (fileUrl == null) {
      _mediaFuture = Future.value(null);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final wifiOnly = prefs.getBool('mediaWifiOnly') ?? true;
    final autoDownloadImages = prefs.getBool('autoDownloadImages') ?? true;
    final autoDownloadVideos = prefs.getBool('autoDownloadVideos') ?? false;
    final ext = fileUrl.split('.').last;

    final canAutoDownload = (ext.isImage && autoDownloadImages) ||
        (ext.isVideo && autoDownloadVideos) ||
        ext.isGif;

    if (canAutoDownload) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (wifiOnly && !connectivityResult.contains(ConnectivityResult.wifi)) {
        _mediaFuture = Future.value(null);
      } else {
        _mediaFuture = MediaCacheService().getMediaFile(fileUrl);
      }
    } else {
      _mediaFuture = Future.value(null);
    }

    if (mounted) setState(() {});
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
    final fileUrl = widget.message.fileUrl;

    if (fileUrl != null) {
      return _buildFileView(fileUrl);
    }

    return _buildTextAndLinkView();
  }

  Widget _buildFileView(String fileUrl) {
    final content = widget.message.content.trim();
    final extension = fileUrl.split('.').last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<File?>(
          future: _mediaFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingIndicator();
            }
            final file = snapshot.data;
            if (file == null || !file.existsSync()) {
              return _buildFileActionCard(fileUrl, extension, onTap: () {
                setState(() {
                  _mediaFuture = MediaCacheService().getMediaFile(fileUrl);
                });
              });
            }
            return (extension.isImage || extension.isGif)
                ? _buildCachedMediaView(file, extension)
                : _buildFileCard(fileUrl, file, extension);
          },
        ),
        if (content.isNotEmpty && !_placeholders.contains(content))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _buildLinkifiedText(content),
          ),
      ],
    );
  }

  Widget _buildTextAndLinkView() {
    final content = widget.message.content.trim();
    final previewUrl = RegExp(r'https?:\/\/[^\s]+').firstMatch(content)?.group(0);
    final remainingText = previewUrl != null ? content.replaceAll(previewUrl, '').trim() : content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (previewUrl != null && remainingText.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LinkPreview(
              enableAnimation: true,
              onPreviewDataFetched: (data) => WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _previewData = data);
              }),
              previewData: _previewData,
              text: previewUrl,
              width: MediaQuery.of(context).size.width * 0.75,
              padding: const EdgeInsets.all(12),
              textStyle: _getTextStyle(),
              metadataTextStyle: _getMetadataTextStyle(),
              metadataTitleStyle: _getMetadataTitleStyle(),
              linkStyle: const TextStyle(color: Colors.blue),
            ),
          ),
        _buildLinkifiedText(remainingText),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildFileActionCard(
    String fileUrl,
    String extension, {
    required VoidCallback onTap,
  }) {
    final textColor = widget.isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
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
                Icon(Icons.download, size: 28, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "key_download_file".tr(args: [fileUrl.split('/').last]),
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
  }

  Widget _buildCachedMediaView(File file, String extension) {
    if (extension.isImage || extension.isGif) {
      return GestureDetector(
        onTap: () => _showFullscreenImage(file),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(file, height: 200, fit: BoxFit.cover),
        ),
      );
    } else if (extension.isVideo) {
      // TODO: Implement video player preview
      return Container(height: 200, color: Colors.black, child: const Center(child: Icon(Icons.play_arrow, color: Colors.white, size: 48)));
    }
    return const SizedBox.shrink();
  }

  Widget _buildFileCard(String fileUrl, File file, String extension) {
    final textColor = widget.isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () async {
        try {
          await OpenFilex.open(file.path);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("key_file_open_failed".tr())),
            );
          }
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
  }

  Widget _buildLinkifiedText(String content) {
    return Linkify(
      text: content,
      style: _getTextStyle(),
      linkStyle: const TextStyle(color: Colors.blueAccent),
      onOpen: (link) async {
        final uri = Uri.parse(link.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("key_173".tr())),
          );
        }
      },
    );
  }

  void _showFullscreenImage(File file) {
    showDialog(
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
    );
  }

  TextStyle _getTextStyle() {
    final scaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final effectiveFontSize = (widget.fontSize ?? 15) * scaleFactor;
    return TextStyle(fontSize: effectiveFontSize, fontWeight: FontWeight.w400, color: textColor);
  }

  TextStyle _getMetadataTextStyle() {
    final scaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    return TextStyle(
      fontSize: (widget.fontSize ?? 13) * scaleFactor,
      color: textColor.withAlpha((0.8 * 255).toInt()),
    );
  }

  TextStyle _getMetadataTitleStyle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    return TextStyle(fontWeight: FontWeight.bold, color: textColor);
  }
}