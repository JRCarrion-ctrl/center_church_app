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

import '../../../core/graph_provider.dart';
import '../media_cache_service.dart';

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
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    _gql = GraphProvider.of(context);
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _loading = true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load media: $e')),
      );
    }
  }

  bool _isImage(String url) {
    final ext = url.toLowerCase();
    return ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.heic');
  }

  Future<void> _downloadFile(File file) async {
    final messenger = ScaffoldMessenger.of(context);
    final fileName = p.basenameWithoutExtension(file.path);
    final fileBytes = await file.readAsBytes();

    try {
      if (_isImage(file.path)) {
        final result = await ImageGallerySaverPlus.saveImage(
          Uint8List.fromList(fileBytes),
          quality: 100,
          name: fileName,
          isReturnImagePathOfIOS: true,
        );
        _logger.i('Image saved result: $result');
        messenger.showSnackBar(SnackBar(content: Text("key_118".tr())));
      } else {
        final result = await ImageGallerySaverPlus.saveFile(
          file.path,
          isReturnPathOfIOS: true,
        );
        _logger.i('File saved result: $result');
        messenger.showSnackBar(SnackBar(content: Text("key_119".tr())));
      }
    } catch (e) {
      _logger.e('Save failed: $e');
      messenger.showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_121".tr())),
      body: _loading
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

                    return FutureBuilder<File?>( // Use File? for clarity
                      future: MediaCacheService().getMediaFile(url),
                      builder: (context, snapshot) {
                        
                        // 1. Loading State: Show a simple placeholder while the future is running
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }

                        // Get the cached file (will be null if not ready or failed)
                        final file = snapshot.data;
                        
                        // 2. Main Content Widget: Displays the file (local or network)
                        Widget mainContent;

                        // Case A: Cached file is available (preferred)
                        if (file != null && file.existsSync()) {
                          mainContent = isImage
                              ? Image.file(file, fit: BoxFit.cover)
                              : const Icon(Icons.insert_drive_file, size: 32);
                        } 
                        // Case B: No cached file, fallback to display network image or file icon
                        else {
                          mainContent = isImage
                              ? CachedNetworkImage( // Use a robust Network image widget
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  errorWidget: (context, url, error) => const Icon(Icons.error_outline),
                                )
                              : const Icon(Icons.insert_drive_file, size: 32);
                        }
                        
                        // 3. File Icon Container (for non-images or when image load fails)
                        final contentContainer = isImage
                            ? mainContent
                            : Container(
                                color: Colors.white,
                                padding: const EdgeInsets.all(8),
                                child: Center(child: mainContent),
                              );

                        // 4. Wrap with gesture detector and download button stack
                        return GestureDetector(
                          onTap: () => _showMediaDetailsDialog(context, file, url, isImage),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: contentContainer,
                              ),
                              // Only show download if the file is locally available
                              if (file != null && file.existsSync() && isImage)
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
    );
  }

  // Extract the showDialog logic into a separate method for cleanliness
  void _showMediaDetailsDialog(BuildContext context, File? file, String url, bool isImage) {
    final fileName = p.basename(url);
    
    // Determine the viewer content based on file availability
    Widget viewerContent;
    
    if (file != null && file.existsSync()) {
      viewerContent = isImage
          ? Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(file, fit: BoxFit.contain),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file, size: 60, color: Colors.white),
                const SizedBox(height: 12),
                Text(fileName, style: const TextStyle(fontSize: 16, color: Colors.white)),
              ],
            );
    } else {
      // Fallback for viewing if file is not cached (Show a loading indicator or network image)
       viewerContent = isImage
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error_outline, size: 60, color: Colors.white),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file, size: 60, color: Colors.white),
                const SizedBox(height: 12),
                Text(fileName, style: const TextStyle(fontSize: 16, color: Colors.white)),
              ],
            );
    }

    showDialog(
      context: context,
      builder: (_) => Stack(
        children: [
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(12),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1,
              maxScale: 5,
              child: viewerContent,
            ),
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
                      Navigator.of(context).pop(); // Close dialog before starting download
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
