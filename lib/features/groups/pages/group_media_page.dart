// File: lib/features/groups/pages/group_media_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:omni_video_player/omni_video_player.dart';

import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../group_service.dart';
import '../chat_storage_service.dart';
import '../group_chat_service.dart';

final Logger _logger = Logger();

class GroupMediaPage extends StatefulWidget {
  final String groupId;
  const GroupMediaPage({super.key, required this.groupId});

  @override
  State<GroupMediaPage> createState() => _GroupMediaPageState();
}

class _GroupMediaPageState extends State<GroupMediaPage> {
  late GraphQLClient _gql;
  final List<String> _mediaUrls = [];
  bool _loading     = true;
  bool _isUploading = false;
  bool _isAdmin     = false;
  bool _inited      = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    _gql = GraphProvider.of(context);
    _loadMediaAndPermissions();
  }

  Future<void> _loadMediaAndPermissions() async {
    setState(() => _loading = true);

    final appState = context.read<AppState>();
    final userId   = appState.profile?.id;
    if (userId != null) {
      try {
        final role = await GroupService(_gql).getMyGroupRole(
            groupId: widget.groupId, userId: userId);
        _isAdmin = const {'admin', 'leader', 'supervisor', 'owner'}.contains(role) ||
            appState.userRole.name == 'owner';
      } catch (e) {
        _logger.e('Failed to fetch role: $e');
      }
    }

    const q = r'''
      query GroupMedia($gid: uuid!) {
        group_messages(
          where: {
            group_id: {_eq: $gid},
            deleted: {_eq: false},
            file_url: {_is_null: false}
          }
          order_by: { created_at: desc }
        ) { file_url }
      }
    ''';

    try {
      final res = await _gql.query(QueryOptions(
        document: gql(q),
        fetchPolicy: FetchPolicy.noCache,
        variables: {'gid': widget.groupId},
      ));
      if (res.hasException) throw res.exception!;

      final urls = ((res.data?['group_messages'] as List?) ?? [])
          .map((e) => (e as Map<String, dynamic>)['file_url'] as String?)
          .whereType<String>()
          .where((u) => u.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _mediaUrls..clear()..addAll(urls);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load media: $e')));
    }
  }

  Future<void> _uploadMedia(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      // ✅ XFile.readAsBytes() works on all platforms
      final bytes       = await picked.readAsBytes();
      final storageService = ChatStorageService(_gql);
      final fileUrl     = await storageService.uploadFile(bytes, picked.name, widget.groupId);

      if(!mounted) return;
      final userId    = context.read<AppState>().profile?.id;
      final chatService = GroupChatService(_gql, getCurrentUserId: () => userId);
      await chatService.sendMessage(widget.groupId, '[Uploaded Media]', fileUrl: fileUrl);

      await _loadMediaAndPermissions();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Upload successful!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Upload Media",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: Text("key_108".tr()),
            onTap: () { Navigator.pop(context); _uploadMedia(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text("key_109".tr()),
            onTap: () { Navigator.pop(context); _uploadMedia(ImageSource.gallery); },
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // --- Type helpers ---
  bool _isImage(String url) {
    final ext = url.split('?').first.split('.').last.toLowerCase();
    return ['png', 'jpg', 'jpeg', 'webp', 'gif', 'heic'].contains(ext);
  }
  bool _isVideo(String url) {
    final ext = url.split('?').first.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'webm'].contains(ext);
  }
  bool _isPdf(String url) =>
      url.split('?').first.split('.').last.toLowerCase() == 'pdf';
  bool _isDoc(String url) {
    final ext = url.split('?').first.split('.').last.toLowerCase();
    return ['doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'].contains(ext);
  }

  /// Fetches bytes from [url] and saves to device gallery (mobile only).
  Future<void> _downloadFromUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Download not supported on web yet.')));
      return;
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final bytes    = response.bodyBytes;
      final fileName = url.split('?').first.split('/').last;

      if (_isImage(url)) {
        await ImageGallerySaverPlus.saveImage(
          Uint8List.fromList(bytes),
          quality: 100,
          name: fileName,
          isReturnImagePathOfIOS: true,
        );
        messenger.showSnackBar(SnackBar(content: Text("key_118".tr())));
      } else {
        // For non-images, save as file
        await ImageGallerySaverPlus.saveFile(url, isReturnPathOfIOS: true);
        messenger.showSnackBar(SnackBar(content: Text("key_119".tr())));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  Future<void> _shareFromUrl(String url) async {
    if (kIsWeb) return;
    try {
      final response = await http.get(Uri.parse(url));
      final fileName = url.split('?').first.split('/').last;
      final xfile    = XFile.fromData(
        response.bodyBytes,
        name: fileName,
        mimeType: _mimeFromUrl(url),
      );
      await SharePlus.instance.share(ShareParams(files: [xfile], text: fileName));
    } catch (e) {
      _logger.e('Share failed: $e');
    }
  }

  String _mimeFromUrl(String url) {
    final ext = url.split('?').first.split('.').last.toLowerCase();
    const map = {
      'png': 'image/png', 'gif': 'image/gif', 'webp': 'image/webp',
      'pdf': 'application/pdf', 'mp4': 'video/mp4', 'mov': 'video/quicktime',
    };
    return map[ext] ?? 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_121".tr())),
      floatingActionButton: (_isAdmin && !_loading && !_isUploading)
          ? FloatingActionButton.extended(
              onPressed: _showUploadOptions,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text("Upload"),
            )
          : null,
      body: Stack(children: [
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _mediaUrls.isEmpty
                ? Center(child: Text("key_122".tr()))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _mediaUrls.length,
                    itemBuilder: (_, i) {
                      final url     = _mediaUrls[i];
                      final isImage = _isImage(url);
                      final isVideo = _isVideo(url);
                      final isPdf   = _isPdf(url);
                      final isDoc   = _isDoc(url);

                      Widget mainContent;
                      if (isImage) {
                        mainContent = CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (_, _, _) =>
                              const Icon(Icons.error_outline),
                        );
                      } else if (isVideo) {
                        mainContent = Container(
                          color: Colors.black87,
                          child: const Center(
                              child: Icon(Icons.play_circle_fill,
                                  size: 40, color: Colors.white)),
                        );
                      } else if (isPdf) {
                        mainContent = Container(
                          color: Colors.red.shade50,
                          child: const Center(
                              child: Icon(Icons.picture_as_pdf,
                                  size: 40, color: Colors.red)),
                        );
                      } else if (isDoc) {
                        mainContent = Container(
                          color: Colors.blue.shade50,
                          child: const Center(
                              child: Icon(Icons.description,
                                  size: 40, color: Colors.blue)),
                        );
                      } else {
                        mainContent = Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Center(
                              child: Icon(Icons.insert_drive_file, size: 40)),
                        );
                      }

                      return GestureDetector(
                        onTap: () => _showMediaDetailsDialog(context, url),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: mainContent),
                            ),
                            if (!kIsWeb && (isImage || isVideo || isPdf || isDoc))
                              IconButton(
                                icon: const Icon(Icons.download,
                                    size: 20, color: Colors.white),
                                onPressed: () => _downloadFromUrl(url),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black45,
                                  padding: const EdgeInsets.all(4),
                                  shape: const CircleBorder(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
        if (_isUploading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text("Uploading...",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  void _showMediaDetailsDialog(BuildContext context, String url) {
    final fileName = url.split('?').first.split('/').last;
    final isImage  = _isImage(url);
    final isVideo  = _isVideo(url);
    final isPdf    = _isPdf(url);
    final isDoc    = _isDoc(url);

    Widget viewerContent;

    if (isVideo) {
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
    } else if (isPdf) {
      // ✅ Always use network viewer — no local File needed
      viewerContent = Material(child: SfPdfViewer.network(url));
    } else if (isDoc) {
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
    } else if (isImage) {
      viewerContent = InteractiveViewer(
        panEnabled: true,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, _) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, _, _) =>
                  const Icon(Icons.error_outline, size: 60, color: Colors.white),
            ),
          ),
        ),
      );
    } else {
      viewerContent = Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file, size: 60, color: Colors.white),
            const SizedBox(height: 12),
            Text(fileName,
                style: const TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (_) => Stack(children: [
        Container(
          color: Colors.black,
          padding: isPdf || isDoc
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
              onPressed: () => context.pop(),
            ),
          ),
        ),
        if (isImage)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!kIsWeb)
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _downloadFromUrl(url);
                    },
                    icon: const Icon(Icons.download),
                    label: Text("key_123".tr()),
                  ),
                if (!kIsWeb)
                  ElevatedButton.icon(
                    onPressed: () => _shareFromUrl(url),
                    icon: const Icon(Icons.share),
                    label: Text("key_124".tr()),
                  ),
              ],
            ),
          ),
      ]),
    );
  }
}