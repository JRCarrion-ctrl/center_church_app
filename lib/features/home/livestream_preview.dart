// File: lib/features/home/livestream_preview.dart
import 'package:flutter/material.dart';
import 'package:ccf_app/features/media/media_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LivestreamPreview extends StatefulWidget {
  const LivestreamPreview({super.key});

  @override
  State<LivestreamPreview> createState() => _LivestreamPreviewState();
}

class _LivestreamPreviewState extends State<LivestreamPreview> {
  late Future<String?> _videoIdFuture;
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    _videoIdFuture = _loadVideoId();
  }

  Future<String?> _loadVideoId() async {
    try {
      final data = await MediaService().getLatestLivestream();
      final url = data['url'];
      if (url == null || url.isEmpty) return null;
      return YoutubePlayer.convertUrlToId(url);
    } catch (e) {
      debugPrint('Error loading livestream: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _videoIdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final videoId = snapshot.data;

        if (videoId == null || videoId.isEmpty) {
          return const Text('No livestream available.');
        }

        _ytController ??= YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Livestream',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            YoutubePlayer(
              controller: _ytController!,
              showVideoProgressIndicator: true,
              width: double.infinity,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  const url = 'https://www.youtube.com/@centerchurch8898/streams';
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('More Livestreams'),
              ),
            ),
          ],
        );
      },
    );
  }
}
