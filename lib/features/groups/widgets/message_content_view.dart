// File: lib/features/groups/widgets/message_content_view.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ADDED for Network Image

import '../media_cache_service.dart';
import '../models/group_message.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:easy_localization/easy_localization.dart';

// --- Utility Extensions ---

extension FileExtension on String {
  String get _ext => toLowerCase();
  bool get isImage => ['png', 'jpg', 'jpeg', 'webp', 'heic'].contains(_ext);
  bool get isVideo => ['mp4', 'mov', 'webm'].contains(_ext);
  bool get isGif => _ext == 'gif';
  bool get isViewableMedia => isImage || isGif || isVideo;
  String get fileName => split('/').last;
  String get extension => split('.').last;
}

// --- Main Widget ---

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
  static const _placeholderTexts = {'[Image]', '[GIF]', '[File]'};
  Future<File?>? _mediaFuture;

  @override
  void initState() {
    super.initState();
    _mediaFuture = _prepareAutoDownload();
  }

  // Helper to trigger download manually/retry
  void _startManualDownload(String fileUrl) {
    setState(() {
      _mediaFuture = MediaCacheService().getMediaFile(fileUrl);
    });
  }

  Future<File?> _prepareAutoDownload() async {
    final fileUrl = widget.message.fileUrl;
    if (fileUrl == null) return null; // No file, no action

    final ext = fileUrl.extension;
    final prefs = await SharedPreferences.getInstance();
    final wifiOnly = prefs.getBool('mediaWifiOnly') ?? true;
    final autoDownloadImages = prefs.getBool('autoDownloadImages') ?? true;
    final autoDownloadVideos = prefs.getBool('autoDownloadVideos') ?? false;

    final canAutoDownload = (ext.isImage && autoDownloadImages) ||
        (ext.isVideo && autoDownloadVideos) ||
        ext.isGif;

    if (canAutoDownload) {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      // Check if we should download based on connectivity setting
      if (wifiOnly && !connectivityResult.contains(ConnectivityResult.wifi)) {
        // Condition not met: Skip auto-download, resolve the future immediately to null.
        return null;
      } else {
        // Condition met: Initiate the full process (check cache OR fetch/cache).
        // The FutureBuilder will show the loading indicator while this runs.
        return MediaCacheService().getMediaFile(fileUrl);
      }
    }
    
    // Auto-download preference is off for this file type, resolve immediately to null.
    return null;
  }

  // --- File Icon Helper ---

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

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    final fileUrl = widget.message.fileUrl;
    return fileUrl != null ? _buildFileView(fileUrl) : _buildTextAndLinkView();
  }

  Widget _buildFileView(String fileUrl) {
    final content = widget.message.content.trim();
    final extension = fileUrl.extension;
    final isViewableMedia = extension.isViewableMedia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<File?>(
          future: _mediaFuture,
          builder: (context, snapshot) {
            // 1. Still waiting for the initial auto-download check to resolve
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingIndicator();
            }

            final file = snapshot.data;
            final isFileCached = file != null && file.existsSync();

            // 2. If cached, show the media/file locally
            if (isFileCached) {
              return isViewableMedia
                  ? _buildCachedMediaView(file, extension)
                  : _buildFileCard(fileUrl, file, extension);
            }
            
            // 3. If NOT cached AND it's an image/GIF, SHOW THE CDN CONTENT
            if (extension.isImage || extension.isGif) {
              return _buildNetworkMediaView(fileUrl, extension);
            }

            // 4. Fallback: If not cached and not viewable media (e.g., PDF, ZIP) 
            //    or if video, show the dedicated download button/action card.
            return _buildFileActionCard(
              fileUrl, 
              extension, 
              onTap: () => _startManualDownload(fileUrl),
            );
          },
        ),
        if (content.isNotEmpty && !_placeholderTexts.contains(content))
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
    final remainingText = previewUrl != null ? content.replaceFirst(previewUrl, '').trim() : content;

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
  
  // --- NEW: View media from the CDN URL using CachedNetworkImage ---
  Widget _buildNetworkMediaView(String fileUrl, String extension) {
    // Tapping the network image should trigger the local download/cache
    final onDoubleTapAction = () => _startManualDownload(fileUrl);
    final onTapAction = () => _showFullscreenMedia(context, url: fileUrl);
    
    if (extension.isImage || extension.isGif) {
      return GestureDetector(
        onTap: onTapAction,
        onDoubleTap: onDoubleTapAction,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CachedNetworkImage( // Use CachedNetworkImage for better performance/caching
                imageUrl: fileUrl,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildLoadingIndicator(),
                errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.red)),
              ),
              // Overlay a subtle icon to indicate it's not locally saved and tapping downloads it
              const Icon(Icons.cloud_download, color: Colors.white70, size: 40),
            ],
          ),
        ),
      );
    } 
    // Fallback for non-image media (like video)
    return _buildFileActionCard(fileUrl, extension, onTap: onTapAction);
  }


  Widget _buildFileActionCard(
    String fileUrl,
    String extension, {
    required VoidCallback onTap,
  }) {
    final textColor = widget.isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final themeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color.fromARGB(64, 255, 255, 255)
        : const Color.fromARGB(64, 0, 0, 0);

    return InkWell(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: themeColor,
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.download, size: 28, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "key_download_file".tr(args: [fileUrl.fileName]),
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
        onTap: () => _showFullscreenMedia(context, file: file, url: widget.message.fileUrl!), 
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
    final themeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color.fromARGB(64, 255, 255, 255)
        : const Color.fromARGB(64, 0, 0, 0);

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
              color: themeColor,
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(_getFileIcon(extension), size: 28, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileUrl.fileName,
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

  void _showFullscreenMedia(BuildContext context, {File? file, required String url}) {
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
                // Check if a local file exists, otherwise use the network URL
                child: file != null 
                    ? Image.file(file) 
                    : CachedNetworkImage(imageUrl: url, fit: BoxFit.contain), // Use CachedNetworkImage for network URL
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

  // --- Text Style Helpers ---

  // Extracted logic to determine text color based on theme and isMe flag
  Color get _resolvedTextColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
  }

  TextStyle _getTextStyle() {
    final scaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final effectiveFontSize = (widget.fontSize ?? 15) * scaleFactor;
    return TextStyle(fontSize: effectiveFontSize, fontWeight: FontWeight.w400, color: _resolvedTextColor);
  }

  TextStyle _getMetadataTextStyle() {
    final scaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    return TextStyle(
      fontSize: (widget.fontSize ?? 13) * scaleFactor,
      color: _resolvedTextColor.withAlpha((0.8 * 255).toInt()),
    );
  }

  TextStyle _getMetadataTitleStyle() {
    return TextStyle(fontWeight: FontWeight.bold, color: _resolvedTextColor);
  }
}