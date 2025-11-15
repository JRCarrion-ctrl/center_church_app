// File: lib/features/home/livestream_preview.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:ccf_app/features/media/media_service.dart';
// REMOVED: import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:omni_video_player/omni_video_player.dart'; // NEW: Omni Player Import

import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

class LivestreamPreview extends StatefulWidget {
  const LivestreamPreview({super.key});

  @override
  State<LivestreamPreview> createState() => _LivestreamPreviewState();
}

class _LivestreamPreviewState extends State<LivestreamPreview> {
  // Now stores the full video URL
  Future<String?>? _videoUrlFuture; 
  // Changed to the playback controller type from the omni_video_player example
  OmniPlaybackController? _omniPlaybackController;
  // This state variable is no longer needed as the player updates via configuration changes
  // String? _currentVideoId; 

  GraphQLClient? _gql;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    _gql ??= GraphQLProvider.of(context).value;

    // Load the video URL, not just the ID
    _videoUrlFuture ??= _loadVideoUrl();
  }

  // Updated to return the full URL string from the API
  Future<String?> _loadVideoUrl() async {
    try {
      final client = GraphQLProvider.of(context).value;
      final data = await MediaService(client).getLatestLivestream();
      final url = data['url'];
      // Simply return the URL, no conversion to YouTube ID is needed
      return url;
    } catch (e) {
      debugPrint('Error loading livestream: $e');
      return null; // Return null on error
    }
  }

  // The previous _updateController method is no longer necessary. 
  // The OmniVideoPlayer updates its source when the 'options' configuration changes.

  @override
  void dispose() {
    // Dispose the captured playback controller
    _omniPlaybackController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoUrlFuture == null) {
        return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
        );
    }

    return FutureBuilder<String?>(
      future: _videoUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        // The result is the full video URL
        final videoUrl = snapshot.data;
        if (videoUrl == null || videoUrl.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                "key_181".tr(), // "Could not load livestream."
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // We use an AspectRatio to constrain the player to the standard 16:9 ratio
        // since the original YoutubePlayer was a child of YoutubePlayerBuilder.
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "key_179a".tr(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: OmniVideoPlayer(
                    callbacks: VideoPlayerCallbacks(
                      onControllerCreated: (controller) {
                        _omniPlaybackController = controller;
                      },
                      onFullScreenToggled: (isFullScreen) {},
                      onOverlayControlsVisibilityChanged: (areVisible) {},
                      onCenterControlsVisibilityChanged: (areVisible) {},
                      onMuteToggled: (isMute) {},
                      onSeekStart: (pos) {},
                      onSeekEnd: (pos) {},
                      onSeekRequest: (target) => true,
                      onFinished: () {},
                      onReplay: () {},
                    ),
                    configuration: VideoPlayerConfiguration(
                      videoSourceConfiguration: VideoSourceConfiguration.youtube(
                        videoUrl: Uri.parse(videoUrl),
                        preferredQualities: [
                          OmniVideoQuality.high720,
                          OmniVideoQuality.low144,
                        ],
                        availableQualities: [
                          OmniVideoQuality.high1080,
                          OmniVideoQuality.high720,
                          OmniVideoQuality.medium480,
                          OmniVideoQuality.medium360,
                          OmniVideoQuality.low144,
                        ],
                        enableYoutubeWebViewFallback: true,
                        forceYoutubeWebViewOnly: false,
                      ).copyWith(
                        autoPlay: false,
                        initialPosition: Duration.zero,
                        initialVolume: 1.0,
                        initialPlaybackSpeed: 1.0,
                        availablePlaybackSpeed: [0.5, 1.0, 1.25, 1.5, 2.0],
                        autoMuteOnStart: false,
                        allowSeeking: true,
                        synchronizeMuteAcrossPlayers: true,
                        timeoutDuration: const Duration(seconds: 30),
                      ),
                      playerTheme: OmniVideoPlayerThemeData().copyWith(
                        icons: VideoPlayerIconTheme().copyWith(
                          error: Icons.warning,
                          playbackSpeedButton: Icons.speed,
                        ),
                        overlays: VideoPlayerOverlayTheme().copyWith(
                          backgroundColor: Colors.white,
                          alpha: 25,
                        ),
                      ),
                      playerUIVisibilityOptions: PlayerUIVisibilityOptions().copyWith(
                        showSeekBar: true,
                        showCurrentTime: true,
                        showDurationTime: true,
                        showRemainingTime: true,
                        showLiveIndicator: true,
                        showLoadingWidget: true,
                        showErrorPlaceholder: true,
                        showReplayButton: true,
                        showThumbnailAtStart: true,
                        showVideoBottomControlsBar: true,
                        showBottomControlsBarOnEndedFullscreen: true,
                        showFullScreenButton: false,
                        showSwitchVideoQuality: true,
                        showSwitchWhenOnlyAuto: true,
                        showPlaybackSpeedButton: true,
                        showMuteUnMuteButton: true,
                        showPlayPauseReplayButton: true,
                        useSafeAreaForBottomControls: true,
                        showGradientBottomControl: true,
                        enableForwardGesture: true,
                        enableBackwardGesture: true,
                        enableExitFullscreenOnVerticalSwipe: true,
                        enableOrientationLock: true,
                        controlsPersistenceDuration: const Duration(seconds: 3),
                        customAspectRatioNormal: null,
                        customAspectRatioFullScreen: null,
                        fullscreenOrientation: null,
                        showBottomControlsBarOnPause: false,
                        alwaysShowBottomControlsBar: false,
                      ),
                    ),
                  ),
                ),
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
                    label: Text("key_180".tr()), // "Watch on Youtube"
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