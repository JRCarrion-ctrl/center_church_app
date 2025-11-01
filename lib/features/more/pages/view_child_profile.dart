// File: lib/features/more/pages/view_child_profile.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class ViewChildProfilePage extends StatelessWidget {
  final String childId;
  const ViewChildProfilePage({super.key, required this.childId});

  static const String _childQuery = r'''
    query Child($id: uuid!) {
      child_profiles_by_pk(id: $id) {
        id
        display_name
        birthday
        photo_url
        allergies
        notes
        emergency_contact
        qr_code_url
      }
    }
  ''';

  String? _formatBirthday(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      // Use the same formatting logic as the original file
      return DateFormat('MMM d, yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  String _nonEmptyOr(String? value, String fallback) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? fallback : v;
  }

  // --- NEW WIDGET FOR EXPANDED QR CODE ---
  void _showExpandedQrCode(BuildContext context, String qrUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(20),
          title: Text("key_323a".tr(), textAlign: TextAlign.center), // Use the title key
          content: CachedNetworkImage(
            imageUrl: qrUrl,
            // Max width/height to fill the dialog space, ensuring maximum scannability
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.8,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error, size: 80),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // Builder function that receives the child data and builds the UI
  Widget _buildChildProfile(BuildContext context, Map<String, dynamic> child) {
    final name = (child['display_name'] ?? 'Unnamed') as String;
    final birthday = child['birthday'] as String?;
    final formattedBirthday = _formatBirthday(birthday);
    final photoUrl = child['photo_url'] as String?;
    final allergies = _nonEmptyOr(child['allergies'] as String?, 'None');
    final notes = _nonEmptyOr(child['notes'] as String?, 'None');
    final emergency = _nonEmptyOr(child['emergency_contact'] as String?, 'None');
    final qrUrl = child['qr_code_url'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Pass the entire child map for editing
              context.pushNamed('edit_child_profile', extra: child);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Photo
            CircleAvatar(
              radius: 60,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 20),
            
            // Name and Birthday
            Text(name, style: Theme.of(context).textTheme.headlineSmall),
            if (formattedBirthday != null)
              Text(
                "key_320".tr(args: [formattedBirthday]), // e.g., Born: date
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 24),
            
            // Allergies
            ListTile(
              leading: const Icon(Icons.medication),
              title: Text("key_321".tr()),
              subtitle: Text(allergies),
            ),
            // Notes (changed leading icon from local_hospital to sticky_note)
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text("key_322".tr()),
              subtitle: Text(notes),
            ),
            // Emergency Contact
            ListTile(
              leading: const Icon(Icons.contact_phone),
              title: Text("key_323".tr()),
              subtitle: Text(emergency),
            ),
            
            // QR Code - WRAPPED IN A GESTURE DETECTOR
            if (qrUrl != null && qrUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "key_323a".tr(), // e.g., "Scan for check-in"
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showExpandedQrCode(context, qrUrl), // <--- TAP HANDLER
                      child: Tooltip(
                        message: "Tap to enlarge QR code",
                        child: CachedNetworkImage(
                          imageUrl: qrUrl,
                          height: 180,
                          placeholder: (context, url) => const CircularProgressIndicator(),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Tap to enlarge".tr(), // Suggest adding a translation key for this hint
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(_childQuery),
        variables: {'id': childId},
        fetchPolicy: FetchPolicy.cacheAndNetwork, // Use cache if available, but check network
      ),
      builder: (QueryResult result, {VoidCallback? refetch, FetchMore? fetchMore}) {
        if (result.hasException) {
          // Display error message
          final errorText = 'Failed to load child profile: ${result.exception.toString()}';
          return Scaffold(body: Center(child: Text(errorText)));
        }

        if (result.isLoading && result.data == null) {
          // Display a loading indicator on first load
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // Extract data
        final childData = result.data?['child_profiles_by_pk'] as Map<String, dynamic>?;

        if (childData == null) {
          // Child not found or data is null
          return Scaffold(body: Center(child: Text('Child not found')));
        }

        // Build the profile UI
        return _buildChildProfile(context, childData);
      },
    );
  }
}