// File: lib/features/home/livestream_preview.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:ccf_app/features/media/media_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

class LivestreamPreview extends StatefulWidget {
  const LivestreamPreview({super.key});

  @override
  State<LivestreamPreview> createState() => _LivestreamPreviewState();
}

class _LivestreamPreviewState extends State<LivestreamPreview> {
  // Made nullable so we can check for initial load in didChangeDependencies
  Future<String?>? _videoIdFuture; 
  YoutubePlayerController? _ytController;

  GraphQLClient? _gql;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    _gql ??= GraphQLProvider.of(context).value;

    _videoIdFuture ??= _loadVideoId();
  }

  // --- _loadUserRole() is DELETED as the role is read from AppState ---

  Future<String?> _loadVideoId() async {
    // Accessing context in an async function called after didChangeDependencies is safe
    try {
      final client = GraphQLProvider.of(context).value;
      final data = await MediaService(client).getLatestLivestream();
      final url = data['url'];
      return YoutubePlayer.convertUrlToId(url ?? '');
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
    // Fallback if _videoIdFuture somehow isn't initialized (shouldn't happen with the fix)
    if (_videoIdFuture == null) {
        return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
        );
    }

    return FutureBuilder<String?>(
      future: _videoIdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }

        final videoId = snapshot.data;
        if (videoId == null || videoId.isEmpty) {
          return Center(child: Text("key_179".tr()));
        }

        return YoutubePlayerBuilder(
          player: YoutubePlayer(
            controller: YoutubePlayerController(
              initialVideoId: videoId,
              flags: const YoutubePlayerFlags(autoPlay: false),
            ),
            showVideoProgressIndicator: true,
            width: double.infinity,
          ),
          builder: (context, player) {
            // The rest of your layout goes here, using the 'player' widget
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Your Row with Title and Refresh Button
                    Row(
                      children: [
                        Text(
                          "key_179a".tr(),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // --- Embed the player widget created above ---
                    player, 
                    const SizedBox(height: 8),
                    // Your "Watch on Youtube" TextButton
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final url = Uri.parse('https://www.youtube.com/@centerchurch8898/streams');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: Text("key_180".tr()),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}