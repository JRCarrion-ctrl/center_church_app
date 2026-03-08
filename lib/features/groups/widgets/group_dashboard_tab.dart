// File: lib/features/groups/widgets/group_dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ccf_app/core/time_service.dart';

import '../group_service.dart'; // Make sure this points to where GroupInfoData is

class GroupDashboardTab extends StatelessWidget {
  final GroupInfoData pageData;
  final bool isAdmin;
  final bool isOwner;
  final Future<void> Function() onRefresh;

  const GroupDashboardTab({
    super.key,
    required this.pageData,
    required this.isAdmin,
    required this.isOwner,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 1. HEADER (Group Description & Quick Actions)
          _buildHeader(context),
          
          const SizedBox(height: 24),

          // 2. ANNOUNCEMENTS (Horizontal Scroll)
          _buildSectionHeader(
            context, 
            title: "key_112c".tr(), // Announcements
            onSeeAll: () => context.push('/groups/${pageData.group.id}/info/announcements'),
          ),
          _buildAnnouncementsRow(context, pageData.announcements),

          const SizedBox(height: 24),

          // 3. EVENTS (Horizontal Scroll)
          _buildSectionHeader(
            context, 
            title: "key_112b".tr(), // Events
            onSeeAll: () => context.push('/groups/${pageData.group.id}/info/events'),
          ),
          _buildEventsRow(context, pageData.events),

          const SizedBox(height: 24),

          // 4. MEDIA RESOURCES (Horizontal Image Row)
          _buildSectionHeader(
            context, 
            title: "key_112d".tr(), // Media
            onSeeAll: () => context.push('/groups/${pageData.group.id}/info/media'),
          ),
          _buildMediaRow(context, pageData.media),
        ],
      ),
    );
  }

  // --- SECTION HEADER HELPER ---
  Widget _buildSectionHeader(BuildContext context, {required String title, required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: onSeeAll,
            child: Text("See All".tr()),
          ),
        ],
      ),
    );
  }

  // --- HEADER & QUICK ACTIONS ---
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pageData.group.description?.isNotEmpty == true) ...[
            Text(
              pageData.group.description!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push(
                    '/groups/${pageData.group.id}/info/members',
                    extra: {'isAdmin': isAdmin},
                  ),
                  icon: const Icon(Icons.people_outline),
                  label: Text("key_112e".tr()), // Members
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final refresh = await context.push<bool>(
                        '/groups/${pageData.group.id}/info/settings',
                        extra: {'group': pageData.group},
                      );
                      if (refresh == true) onRefresh();
                    },
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text("Settings"),
                  ),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  // --- ANNOUNCEMENTS HORIZONTAL SCROLL ---
  Widget _buildAnnouncementsRow(BuildContext context, List<Map<String, dynamic>> announcements) {
    if (announcements.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text("key_100".tr(), style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final a = announcements[index];
          return Container(
            width: 280,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.campaign, color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        a['body'] ?? '',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- EVENTS HORIZONTAL SCROLL ---
  Widget _buildEventsRow(BuildContext context, List<Map<String, dynamic>> events) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    
    // Filter to future events only using your existing logic
    final upcomingEvents = events.where((e) {
      final dateStr = e['event_date'];
      if (dateStr == null) return false;
      try {
        return DateTime.parse(dateStr).isAfter(today);
      } catch (_) {
        return false;
      }
    }).toList();

    if (upcomingEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text("key_097".tr(), style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: upcomingEvents.length,
        itemBuilder: (context, index) {
          final event = upcomingEvents[index];
          DateTime? eventDate;
          try {
            eventDate = DateTime.parse(event['event_date']);
          } catch (_) {}

          return Container(
            width: 150,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/groups/${pageData.group.id}/info/events'),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event, color: Theme.of(context).colorScheme.onSecondaryContainer),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (eventDate != null)
                        Text(
                          TimeService.formatUtcToLocal(eventDate, pattern: 'MMM d, h:mm a'),
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- MEDIA HORIZONTAL SCROLL ---
  Widget _buildMediaRow(BuildContext context, List<Map<String, dynamic>> media) {
    // Filter out non-images just like your old info page did
    final imageMedia = media.where((msg) {
      final fileUrl = msg['file_url'] as String?;
      if (fileUrl == null) return false;
      final ext = fileUrl.split('?').first.split('.').last.toLowerCase();
      return const {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext);
    }).toList();

    if (imageMedia.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text("key_103".tr(), style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: imageMedia.length > 6 ? 6 : imageMedia.length, // Limit to 6 recent photos
        itemBuilder: (context, index) {
          final fileUrl = imageMedia[index]['file_url'] as String;
          return GestureDetector(
            onTap: () => context.push('/groups/${pageData.group.id}/info/media'),
            child: Container(
              width: 120,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: fileUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[300], child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}