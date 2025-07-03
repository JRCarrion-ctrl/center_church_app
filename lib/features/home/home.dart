// File: lib/features/home/home.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../media/services/youtube_services.dart';
import 'announcement_service.dart';
import 'models/group_announcement.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _timer;
  late final DateTime _nextService;
  Duration _timeUntilService = Duration.zero;

  String? _latestVideoId;
  String? _latestThumbnail;
  List<GroupAnnouncement> groupAnnouncements = [];

  @override
  void initState() {
    super.initState();
    _fetchLivestream();
    _fetchGroupAnnouncements();
    _nextService = _calculateNextService();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  Future<void> _fetchGroupAnnouncements() async {
    final results = await AnnouncementService().fetchGroupAnnouncements();
    final now = DateTime.now().toUtc();

    final visible = results
        .where((a) => a.publishedAt.isBefore(now))
        .toList();
    
    visible.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    setState(() {
      groupAnnouncements = visible;
    });
  }

  Future<void> _fetchLivestream() async {
    final latest = await YouTubeService.fetchLatestLivestream();
    if (latest != null) {
      setState(() {
        _latestVideoId = latest['videoId'];
        _latestThumbnail = latest['thumbnailUrl'];
      });
    }
  }

  DateTime _calculateNextService() {
    final now = DateTime.now();
    final daysUntilSunday = (DateTime.sunday - now.weekday + 7) % 7;
    final nextSunday = now.add(Duration(days: daysUntilSunday));
    return DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 11, 30);
  }

  void _updateCountdown() {
    final now = DateTime.now();
    var diff = _nextService.difference(now);
    if (diff.isNegative) {
      final nextWeek = _nextService.add(const Duration(days: 7));
      diff = nextWeek.difference(now);
    }
    setState(() {
      _timeUntilService = diff;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _launchVideo() async {
    if (_latestVideoId == null) return;
    final url = Uri.parse('https://www.youtube.com/watch?v=$_latestVideoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open video')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _timeUntilService.inDays;
    final hours = _timeUntilService.inHours % 24;
    final minutes = _timeUntilService.inMinutes % 60;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text("WELCOME",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Time Until Next Service: ${days}d ${hours}h ${minutes}m",
                style: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 24),
            if (groupAnnouncements.isNotEmpty) ...[
              const Center(
                child: Text(
                  "Group Announcements",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: groupAnnouncements.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final a = groupAnnouncements[index];
                    return SizedBox(
                      width: 280,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 6),
                              if (a.body != null)
                                Expanded(
                                  child: Text(
                                    a.body!,
                                    overflow: TextOverflow.fade,
                                  ),
                                ),
                              if (a.imageUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(a.imageUrl!,
                                      height: 60,
                                      width: double.infinity,
                                      fit: BoxFit.cover),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Center(
              child: Text(
                "Livestream",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            if (_latestVideoId != null && _latestThumbnail != null)
              GestureDetector(
                onTap: _launchVideo,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(_latestThumbnail!, fit: BoxFit.cover),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.play_arrow,
                          size: 48, color: Colors.white),
                    ),
                  ],
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _launchVideo,
              child: const Text("More Livestreams"),
            ),

            const SizedBox(height: 24),
            const Center(
              child: Text(
                "About Our Church",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final url = Uri.parse("https://www.centrocristianofrederick.com/");
                    final messenger = ScaffoldMessenger.of(context);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Could not open website')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text(
                    "Learn More",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Center(
              child: Text(
                "Connect with Us",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final url = Uri.parse("https://tccf.givingfire.com/");
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.favorite_border),
                label: const Text("Give"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  backgroundColor: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.video_library),
                  tooltip: "YouTube",
                  onPressed: () async {
                    final url = Uri.parse("https://www.youtube.com/@centerchurch8898/streams");
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: "Instagram",
                  onPressed: () async {
                    final url = Uri.parse("https://www.instagram.com/centrocristiano_frederick/");
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.facebook),
                  tooltip: "Facebook",
                  onPressed: () async {
                    final url = Uri.parse("https://www.facebook.com/profile.php?id=100089863186477");
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
