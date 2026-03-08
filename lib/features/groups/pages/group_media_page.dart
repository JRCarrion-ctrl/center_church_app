// File: lib/features/groups/pages/group_media_page.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:omni_video_player/omni_video_player.dart';

import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../media_cache_service.dart';
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
  bool _loading = true;
  bool _isUploading = false; 
  bool _isAdmin = false;     
  bool _inited = false;

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
    final userId = appState.profile?.id;
    if (userId != null) {
      try {
        final role = await GroupService(_gql).getMyGroupRole(groupId: widget.groupId, userId: userId);
        _isAdmin = const {'admin', 'leader', 'supervisor', 'owner'}.contains(role) || appState.userRole.name == 'owner';
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
        ) {
          file_url
        }
      }
    ''';

    try {
      final res = await _gql.query(
        QueryOptions(
          document: gql(q),
          fetchPolicy: FetchPolicy.noCache,
          variables: {'gid': widget.groupId},
        ),
      );
      if (res.hasException) throw res.exception!;

      final urls = ((res.data?['group_messages'] as List?) ?? [])
          .map((e) => (e as Map<String, dynamic>)['file_url'] as String?)
          .whereType<String>()
          .where((u) => u.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _mediaUrls
          ..clear()
          ..addAll(urls);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load media: $e')));
    }
  }

  Future<void> _uploadMedia(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(picked.path);
      final storageService = ChatStorageService(_gql);
      final fileUrl = await storageService.uploadFile(file, widget.groupId);

      // ignore: use_build_context_synchronously
      final userId = context.read<AppState>().profile?.id;
      final chatService = GroupChatService(_gql, getCurrentUserId: () => userId);
      
      await chatService.sendMessage(widget.groupId, '[Uploaded Media]', fileUrl: fileUrl);

      await _loadMediaAndPermissions();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload successful!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Upload Media", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text("key_108".tr()), 
              onTap: () {
                Navigator.pop(context);
                _uploadMedia(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text("key_109".tr()), 
              onTap: () {
                Navigator.pop(context);
                _uploadMedia(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- Type Checking Helpers ---
  bool _isImage(String url) {
    final ext = url.split('?').first.split('.').last.toLowerCase();
    return ['png', 'jpg', 'jpeg', 'webp', 'gif', 'heic'].contains(ext);
  }
  
  bool _isVideo(String url) {
    final ext = url.split('?').first.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'webm'].contains(ext);
  }

  bool _isPdf(String url) {
    final ext = url.split('?').first.split('.').last.toLowerCase();
    return ext == 'pdf';
  }

  bool _isDoc(String url) {
    final ext = url.split('?').first.split('.').last.toLowerCase();
    return ['doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'].contains(ext);
  }

  Future<void> _downloadFile(File file) async {
    final messenger = ScaffoldMessenger.of(context);
    final fileName = p.basenameWithoutExtension(file.path);
    final fileBytes = await file.readAsBytes();

    try {
      if (_isImage(file.path)) {
        await ImageGallerySaverPlus.saveImage(
          Uint8List.fromList(fileBytes),
          quality: 100,
          name: fileName,
          isReturnImagePathOfIOS: true,
        );
        messenger.showSnackBar(SnackBar(content: Text("key_118".tr())));
      } else {
        await ImageGallerySaverPlus.saveFile(file.path, isReturnPathOfIOS: true);
        messenger.showSnackBar(SnackBar(content: Text("key_119".tr())));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
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
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _mediaUrls.isEmpty
                  ? Center(child: Text("key_122".tr()))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _mediaUrls.length,
                      itemBuilder: (_, i) {
                        final url = _mediaUrls[i];
                        final isImage = _isImage(url);
                        final isVideo = _isVideo(url);
                        final isPdf = _isPdf(url);
                        final isDoc = _isDoc(url);

                        return FutureBuilder<File?>(
                          future: MediaCacheService().getMediaFile(url),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }

                            final file = snapshot.data;
                            Widget mainContent;

                            // Generates unique UI containers for each file type
                            if (isImage) {
                              mainContent = file != null && file.existsSync()
                                  ? Image.file(file, fit: BoxFit.cover)
                                  : CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      errorWidget: (context, url, error) => const Icon(Icons.error_outline),
                                    );
                            } else if (isVideo) {
                              mainContent = Container(
                                color: Colors.black87,
                                child: const Center(child: Icon(Icons.play_circle_fill, size: 40, color: Colors.white)),
                              );
                            } else if (isPdf) {
                              mainContent = Container(
                                color: Colors.red.shade50,
                                child: const Center(child: Icon(Icons.picture_as_pdf, size: 40, color: Colors.red)),
                              );
                            } else if (isDoc) {
                              mainContent = Container(
                                color: Colors.blue.shade50,
                                child: const Center(child: Icon(Icons.description, size: 40, color: Colors.blue)),
                              );
                            } else {
                              mainContent = Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Center(child: Icon(Icons.insert_drive_file, size: 40)),
                              );
                            }

                            return GestureDetector(
                              onTap: () => _showMediaDetailsDialog(context, file, url),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(width: double.infinity, height: double.infinity, child: mainContent),
                                  ),
                                  // Offer the standard download button on grid items
                                  if (file != null && file.existsSync() && (isImage || isVideo || isPdf || isDoc))
                                    IconButton(
                                      icon: const Icon(Icons.download, size: 20, color: Colors.white),
                                      onPressed: () async => await _downloadFile(file),
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
                    Text("Uploading...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMediaDetailsDialog(BuildContext context, File? file, String url) {
    final fileName = p.basename(url);
    Widget viewerContent;
    
    final isImage = _isImage(url);
    final isVideo = _isVideo(url);
    final isPdf = _isPdf(url);
    final isDoc = _isDoc(url);

    if (isVideo) {
      viewerContent = Center(
        child: Material(
          color: Colors.transparent,
          child: OmniVideoPlayer(
            configuration: VideoPlayerConfiguration(
              videoSourceConfiguration: VideoSourceConfiguration.network(videoUrl: Uri.parse(url)),
            ),
            callbacks: VideoPlayerCallbacks(),
          ),
        ),
      );
    } else if (isPdf) {
      viewerContent = Material(
        child: file != null && file.existsSync()
            ? SfPdfViewer.file(file)
            : SfPdfViewer.network(url),
      );
    } else if (isDoc) {
      final gviewUrl = 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(url)}';
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
            child: file != null && file.existsSync()
                ? Image.file(file, fit: BoxFit.contain)
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.error_outline, size: 60, color: Colors.white),
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
            Text(fileName, style: const TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (_) => Stack(
        children: [
          Container(
            color: Colors.black,
            padding: isPdf || isDoc ? const EdgeInsets.only(top: 80) : EdgeInsets.zero,
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
          // We offer explicit Share/Save buttons for standard Images
          if (file != null && file.existsSync() && isImage)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _downloadFile(file);
                    },
                    icon: const Icon(Icons.download),
                    label: Text("key_123".tr()),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(file.path)],
                          text: fileName,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: Text("key_124".tr()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}