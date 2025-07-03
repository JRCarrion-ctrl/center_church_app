// File: lib/features/groups/widgets/group_media_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import '../models/group_message.dart';
import '../media_cache_service.dart';

class GroupMediaTab extends StatelessWidget {
  final String groupId;

  const GroupMediaTab({super.key, required this.groupId});

  Future<List<GroupMessage>> _fetchMediaMessages() async {
    final response = await Supabase.instance.client
        .from('group_messages')
        .select()
        .eq('group_id', groupId)
        .not('file_url', 'is', null)
        .order('created_at', ascending: false);

    return (response as List)
        .map((m) => GroupMessage.fromMap(m as Map<String, dynamic>))
        .where((msg) => !msg.deleted)
        .toList();
  }

  bool _isImage(String url) {
    final ext = url.toLowerCase();
    return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.gif');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GroupMessage>>(
      future: _fetchMediaMessages(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final media = snapshot.data!;
        if (media.isEmpty) return const Center(child: Text("No media found."));

        final images = media.where((m) => _isImage(m.fileUrl!)).toList();
        final files = media.where((m) => !_isImage(m.fileUrl!)).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty) ...[
                const Text('Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    final img = images[index];
                    return FutureBuilder<File>(
                      future: MediaCacheService().getMediaFile(img.fileUrl!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Icon(Icons.broken_image);
                        }
                        return GestureDetector(
                          onTap: () async {
                            final file = snapshot.data!;
                            await launchUrl(Uri.file(file.path));
                          },
                          child: Image.file(snapshot.data!, fit: BoxFit.cover),
                        );
                      },
                    );
                  },
                ),
              ],
              if (files.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...files.map((file) => ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(file.fileUrl!.split('/').last),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final localFile = await MediaCacheService().getMediaFile(file.fileUrl!);
                          await launchUrl(Uri.file(localFile.path));
                        } catch (_) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Could not open file')),
                          );
                        }
                      },
                    )),
              ]
            ],
          ),
        );
      },
    );
  }
}
