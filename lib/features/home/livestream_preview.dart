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
  late Future<Map<String, String>> _latestLivestreamFuture;
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    _latestLivestreamFuture = MediaService().getLatestLivestream();
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _latestLivestreamFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null || snapshot.data!['url']!.isEmpty) {
          return const Text('Could not load livestream.');
        }

        final videoUrl = snapshot.data!['url']!;
        final videoId = YoutubePlayer.convertUrlToId(videoUrl);

        if (videoId == null) {
          return const Text('Invalid video URL.');
        }

        _ytController ??= YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
          ),
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
                  const churchYouTubeUrl = 'https://www.youtube.com/@centerchurch8898/streams';
                  final uri = Uri.parse(churchYouTubeUrl);
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