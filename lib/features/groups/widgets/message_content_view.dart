// File: lib/features/groups/widgets/message_content_view.dart
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:omni_video_player/omni_video_player.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:easy_localization/easy_localization.dart';

// Mobile-only imports, guarded at call sites with kIsWeb
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:open_filex/open_filex.dart';

import '../media_cache_service.dart';
import '../models/group_message.dart';

// --- Utility Extensions ---

extension FileExtension on String {
  String get extension => split('?').first.split('.').last.toLowerCase();

  bool get isImage => ['png', 'jpg', 'jpeg', 'webp', 'heic'].contains(extension);
  bool get isGif => extension == 'gif';
  bool get isImageOrGif => isImage || isGif;

  bool get isVideo => ['mp4', 'mov', 'webm'].contains(extension);
  bool get isPdf => extension == 'pdf';
  bool get isDoc =>
      ['doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'].contains(extension);

  bool get isSupportedDocument => isVideo || isPdf || isDoc;

  String get fileName => split('?').first.split('/').last;
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
  static const _placeholderTexts = {'[Image]', '[GIF]', '[File]'};

  // Only used on mobile — null on web
  Future<dynamic>? _mediaFuture; // dynamic = File? on mobile, null on web

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _mediaFuture = _prepareAutoDownload();
  }

  void _startManualDownload(String fileUrl) {
    if (kIsWeb) return;
    setState(() {
      _mediaFuture = MediaCacheService().getMediaFile(fileUrl);
    });
  }

  /// Mobile only: checks wifi/auto-download prefs before caching.
  Future<dynamic> _prepareAutoDownload() async {
    final fileUrl = widget.message.fileUrl;
    if (fileUrl == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final wifiOnly = prefs.getBool('mediaWifiOnly') ?? true;
    final autoDownloadImages = prefs.getBool('autoDownloadImages') ?? true;
    final autoDownloadVideos = prefs.getBool('autoDownloadVideos') ?? false;

    final canAutoDownload = (fileUrl.isImage && autoDownloadImages) ||
        (fileUrl.isVideo && autoDownloadVideos) ||
        fileUrl.isGif;

    if (!canAutoDownload) return null;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (wifiOnly && !connectivityResult.contains(ConnectivityResult.wifi)) {
      return null;
    }
    return MediaCacheService().getMediaFile(fileUrl);
  }

  @override
  Widget build(BuildContext context) {
    final fileUrl = widget.message.fileUrl;
    return fileUrl != null
        ? _buildFileView(fileUrl)
        : _buildTextAndLinkView();
  }

  // --- File view ---

  Widget _buildFileView(String fileUrl) {
    final content = widget.message.content.trim();

    // On web: skip FutureBuilder entirely, go straight to network widgets
    if (kIsWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fileUrl.isImageOrGif)
            _buildNetworkMediaView(fileUrl)
          else if (fileUrl.isSupportedDocument)
            _buildFileActionCard(
              fileUrl,
              onTap: () => _showFullscreenMedia(context, url: fileUrl),
              customText: "View ${fileUrl.fileName}",
            )
          else
            _buildGenericFileCard(fileUrl),
          if (content.isNotEmpty && !_placeholderTexts.contains(content))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildLinkifiedText(content),
            ),
        ],
      );
    }

    // On mobile: use FutureBuilder with cached File
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<dynamic>(
          future: _mediaFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingIndicator();
            }

            final file = snapshot.data;
            final isFileCached = file != null && file.existsSync();

            if (isFileCached) {
              if (fileUrl.isImageOrGif) {
                return _buildCachedMediaView(file, fileUrl);
              } else if (fileUrl.isSupportedDocument) {
                return _buildFileActionCard(
                  fileUrl,
                  onTap: () =>
                      _showFullscreenMedia(context, file: file, url: fileUrl),
                  customText: "Open ${fileUrl.fileName}",
                );
              } else {
                return _buildMobileFileCard(fileUrl, file);
              }
            }

            if (fileUrl.isImageOrGif) return _buildNetworkMediaView(fileUrl);

            if (fileUrl.isSupportedDocument) {
              return _buildFileActionCard(
                fileUrl,
                onTap: () => _showFullscreenMedia(context, url: fileUrl),
                customText: "View ${fileUrl.fileName}",
              );
            }

            return _buildFileActionCard(
              fileUrl,
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

  // --- Individual content builders ---

  Widget _buildNetworkMediaView(String fileUrl) {
    return GestureDetector(
      onTap: () => _showFullscreenMedia(context, url: fileUrl),
      onDoubleTap: kIsWeb ? null : () => _startManualDownload(fileUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CachedNetworkImage(
              imageUrl: fileUrl,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (_, _) => _buildLoadingIndicator(),
              errorWidget: (_, _, _) =>
                  const Center(child: Icon(Icons.error, color: Colors.red)),
            ),
            if (!kIsWeb)
              const Icon(Icons.cloud_download, color: Colors.white70, size: 40),
          ],
        ),
      ),
    );
  }

  /// Mobile only: shows cached image from local File.
  Widget _buildCachedMediaView(dynamic file, String fileUrl) {
    return GestureDetector(
      onTap: () => _showFullscreenMedia(context, file: file, url: fileUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(file, height: 200, fit: BoxFit.cover),
      ),
    );
  }

  /// Mobile only: opens a generic file with OpenFilex.
  Widget _buildMobileFileCard(String fileUrl, dynamic file) {
    final textColor =
        widget.isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
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
                SnackBar(content: Text("key_file_open_failed".tr())));
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
                Icon(_getFileIcon(fileUrl.extension), size: 28, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileUrl.fileName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w500, color: textColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Web fallback: opens generic file via url_launcher.
  Widget _buildGenericFileCard(String fileUrl) {
    return _buildFileActionCard(
      fileUrl,
      customText: fileUrl.fileName,
      onTap: () async {
        final uri = Uri.parse(fileUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  Widget _buildFileActionCard(
    String fileUrl, {
    required VoidCallback onTap,
    String? customText,
  }) {
    final textColor =
        widget.isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final themeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color.fromARGB(64, 255, 255, 255)
        : const Color.fromARGB(64, 0, 0, 0);

    final icon = fileUrl.isVideo
        ? Icons.play_circle_fill
        : (fileUrl.isPdf
            ? Icons.picture_as_pdf
            : _getFileIcon(fileUrl.extension));

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
                Icon(icon, size: 28, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customText ??
                        "key_download_file".tr(args: [fileUrl.fileName]),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w500, color: textColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Text / link view ---

  Widget _buildTextAndLinkView() {
    final content = widget.message.content.trim();
    final previewUrl =
        RegExp(r'https?:\/\/[^\s]+').firstMatch(content)?.group(0);
    final remainingText = previewUrl != null
        ? content.replaceFirst(previewUrl, '').trim()
        : content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (previewUrl != null && remainingText.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.75,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LinkPreview(
                  enableAnimation: true,
                  onLinkPreviewDataFetched: (_) {},
                  text: previewUrl,
                ),
              ),
            ),
          ),
        _buildLinkifiedText(remainingText),
      ],
    );
  }

  // --- Fullscreen viewer ---

  void _showFullscreenMedia(BuildContext context,
      {dynamic file, required String url}) {
    Widget viewerContent;

    if (url.isVideo) {
      viewerContent = Center(
        child: Material(
          color: Colors.transparent,
          child: OmniVideoPlayer(
            configuration: VideoPlayerConfiguration(
              videoSourceConfiguration:
                  VideoSourceConfiguration.network(videoUrl: Uri.parse(url)),
            ),
            callbacks: VideoPlayerCallbacks(),
          ),
        ),
      );
    } else if (url.isPdf) {
      viewerContent = Material(
        // Mobile: prefer local file; web/uncached: network
        child: (!kIsWeb && file != null && file.existsSync())
            ? SfPdfViewer.file(file)
            : SfPdfViewer.network(url),
      );
    } else if (url.isDoc) {
      final gviewUrl =
          'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(url)}';
      viewerContent = SafeArea(
        child: Material(
          child: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..loadRequest(Uri.parse(gviewUrl)),
          ),
        ),
      );
    } else {
      // Image / GIF
      viewerContent = InteractiveViewer(
        panEnabled: true,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: (!kIsWeb && file != null && file.existsSync())
                ? Image.file(file)
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, _) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, _, _) => const Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.white),
                  ),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (_) => Stack(
        children: [
          Container(
            color: Colors.black,
            padding: url.isPdf || url.isDoc
                ? const EdgeInsets.only(top: 80)
                : EdgeInsets.zero,
            child: viewerContent,
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

  // --- Helpers ---

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
              SnackBar(content: Text("key_173".tr())));
        }
      },
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':  return Icons.picture_as_pdf;
      case 'doc':
      case 'docx': return Icons.description;
      case 'mp3':
      case 'wav':  return Icons.audiotrack;
      case 'zip':
      case 'rar':  return Icons.archive;
      case 'xls':
      case 'xlsx': return Icons.table_chart;
      case 'ppt':
      case 'pptx': return Icons.slideshow;
      case 'txt':  return Icons.text_snippet;
      default:     return Icons.insert_drive_file;
    }
  }

  Color get _resolvedTextColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
  }

  TextStyle _getTextStyle() {
    final scaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final effectiveFontSize = (widget.fontSize ?? 15) * scaleFactor;
    return TextStyle(
        fontSize: effectiveFontSize,
        fontWeight: FontWeight.w400,
        color: _resolvedTextColor);
  }
}