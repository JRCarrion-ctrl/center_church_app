// File: lib/features/groups/pages/group_media_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:typed_data';
import 'package:logger/logger.dart';

import '../media_cache_service.dart';

final Logger _logger = Logger();

class GroupMediaPage extends StatefulWidget {
  final String groupId;

  const GroupMediaPage({super.key, required this.groupId});

  @override
  State<GroupMediaPage> createState() => _GroupMediaPageState();
}

class _GroupMediaPageState extends State<GroupMediaPage> {
  final _client = Supabase.instance.client;
  final List<String> _mediaUrls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _loading = true);
    try {
      final data = await _client
          .from('group_messages')
          .select('file_url')
          .eq('group_id', widget.groupId)
          .not('file_url', 'is', null)
          .order('created_at', ascending: false);

      final urls = (data as List)
          .map((item) => item['file_url'] as String)
          .where((url) => url.isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _mediaUrls.clear();
          _mediaUrls.addAll(urls);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load media: $e')),
        );
      }
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
        messenger.showSnackBar(const SnackBar(content: Text('Image saved to gallery')));
      } else {
        final result = await ImageGallerySaverPlus.saveFile(
          file.path,
          isReturnPathOfIOS: true,
        );
        _logger.i('File saved result: $result');
        messenger.showSnackBar(const SnackBar(content: Text('File saved')));
      }
    } catch (e) {
      _logger.e('Save failed: $e');
      messenger.showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Media')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mediaUrls.isEmpty
              ? const Center(child: Text('No shared media found.'))
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
                        if (!snapshot.hasData) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }

                        final file = snapshot.data!;
                        final fileName = p.basename(url);
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isImage(url))
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.file(file, fit: BoxFit.contain),
                                        )
                                      else ...[
                                        const Icon(Icons.insert_drive_file, size: 60),
                                        const SizedBox(height: 12),
                                        Text(fileName, style: const TextStyle(fontSize: 16)),
                                      ],
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () async => await _downloadFile(file),
                                            icon: const Icon(Icons.download),
                                            label: const Text('Download'),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () async{
                                              await SharePlus.instance.share(
                                                ShareParams(
                                                files: [XFile(file.path)],
                                                text: fileName,
                                              ));
                                              },
                                            icon: const Icon(Icons.share),
                                            label: const Text('Share'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
