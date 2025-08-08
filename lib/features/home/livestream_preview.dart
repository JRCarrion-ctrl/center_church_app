// File: lib/features/home/livestream_preview.dart
import 'package:flutter/material.dart';
import 'package:ccf_app/features/media/media_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

class LivestreamPreview extends StatefulWidget {
  const LivestreamPreview({super.key});

  @override
  State<LivestreamPreview> createState() => _LivestreamPreviewState();
}

class _LivestreamPreviewState extends State<LivestreamPreview> {
  late Future<String?> _videoIdFuture;
  YoutubePlayerController? _ytController;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _videoIdFuture = _loadVideoId();
  }

  Future<void> _loadUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _userRole = profile?['role'];
      });
    }
  }

  Future<String?> _loadVideoId() async {
    try {
      final data = await MediaService().getLatestLivestream();
      final url = data['url'];
      return YoutubePlayer.convertUrlToId(url ?? '');
    } catch (e) {
      debugPrint('Error loading livestream: $e');
      return null;
    }
  }

  Future<void> _refreshLivestream() async {
    final session = Supabase.instance.client.auth.currentSession;
    final accessToken = session?.accessToken;
    if (accessToken == null) return;

    final uri = Uri.parse(
      'https://vhzcbqgehlpemdkvmzvy.supabase.co/functions/v1/update-livestream-cache',
    );

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _ytController?.dispose();
          _ytController = null;
          _videoIdFuture = _loadVideoId();
        });
      } else {
        debugPrint('Refresh failed: ${response.statusCode}');
        _showSnackbar('Refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error refreshing livestream: $e');
      _showSnackbar('Error refreshing livestream');
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final videoId = snapshot.data;
        if (videoId == null || videoId.isEmpty) {
          return Center(child: Text("key_179".tr()));
        }

        _ytController ??= YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false),
        );

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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (_userRole == 'supervisor' || _userRole == 'owner')
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
