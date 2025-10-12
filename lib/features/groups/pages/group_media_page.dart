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

import '../../../core/graph_provider.dart';          // <-- Hasura client
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
                    return FutureBuilder<File>(
                      future: MediaCacheService().getMediaFile(url),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }

                        final file = snapshot.data;
                        if (file == null) {
                          return _isImage(url)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(url, fit: BoxFit.cover),
                                )
                              : Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.insert_drive_file, size: 32),
                                );
                        }

                        final fileName = p.basename(url);
                        return GestureDetector(
                          onTap: () {
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
                                      child: _isImage(url)
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
                                  if (_isImage(url))
                                    Positioned(
                                      bottom: 16,
                                      left: 16,
                                      right: 16,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () async => await _downloadFile(file),
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
                          },
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _isImage(url)
                                    ? Image.file(file, fit: BoxFit.cover)
                                    : Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.all(8),
                                        child: const Icon(Icons.insert_drive_file, size: 32),
                                      ),
                              ),
                              if (_isImage(url))
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
}
