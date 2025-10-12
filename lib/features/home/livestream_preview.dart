// File: lib/features/home/livestream_preview.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:ccf_app/app_state.dart';

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
  String? _userRole;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    _gql ??= GraphQLProvider.of(context).value;

    _userRole = context.read<AppState>().role;

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

  Future<void> _refreshLivestream() async {
    if (_gql == null) return;

    // TODO: Hasura action for Refresh
    const m = r'''
      mutation RefreshLivestream {
        refresh_livestream_cache {
          ok
          message
        }
      }
    ''';

    try {
      final res = await _gql!.mutate(MutationOptions(document: gql(m)));
      if (res.hasException) {
        _showSnackbar('Refresh failed');
        return;
      }

      // Reset the player and re-fetch the video id
      setState(() {
        _ytController?.dispose();
        _ytController = null;
        // The old _videoIdFuture is replaced with a new one
        _videoIdFuture = _loadVideoId(); 
      });
      _showSnackbar('Livestream refresh initiated');
    } catch (e) {
      debugPrint('Error refreshing livestream: $e');
      _showSnackbar('Error refreshing livestream');
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      future: _videoIdFuture, // Guaranteed to be initialized by didChangeDependencies
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final videoId = snapshot.data;
        if (videoId == null || videoId.isEmpty) {
          return Center(child: Text("key_179".tr()));
        }

        // Initialize controller only once after videoId is available
        _ytController ??= YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false),
        );

        final canRefresh = _userRole == 'supervisor' || _userRole == 'owner';

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "key_179a".tr(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (canRefresh)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh Livestream',
                        onPressed: _refreshLivestream,
                      ),
                  ],
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
  }
}