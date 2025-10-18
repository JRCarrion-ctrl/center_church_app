// File: lib/features/more/pages/public_profile.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ccf_app/core/graph_provider.dart';

class PublicProfile extends StatefulWidget {
  final String userId;

  const PublicProfile({super.key, required this.userId});

  @override
  State<PublicProfile> createState() => _PublicProfileState();
}

class _PublicProfileState extends State<PublicProfile> {
  final _logger = Logger();
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? errorMessage;
  bool _isDataInitialized = false; 

  String formatUSPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return input;
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if the data has been initialized yet.
    // This method can be called multiple times if dependencies change.
    if (!_isDataInitialized) {
      _loadProfile();
      _isDataInitialized = true;
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // The Query has been correctly changed to use a filter (where)
    const q = r'''
      query PublicProfile($id: String!) {
        public_profiles(where: {id: {_eq: $id}}) {
          display_name
          bio
          email
          phone
          photo_url
        }
      }
    ''';

    try {
      final client = GraphProvider.of(context);
      final res = await client.query(
        QueryOptions(
          document: gql(q),
          variables: {'id': widget.userId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (res.hasException) {
        throw res.exception!;
      }

      // 🛑 FIX: Parse the result as a list and get the first element.
      final List<dynamic>? profilesList = res.data?['public_profiles'] as List<dynamic>?;
      final Map<String, dynamic>? singleProfile = 
          profilesList != null && profilesList.isNotEmpty 
          ? profilesList.first as Map<String, dynamic> 
          : null;

      setState(() {
        // Assign the single extracted object
        profile = singleProfile;
        isLoading = false;
      });
      // 🛑 END FIX
      
    } catch (e, st) {
      _logger.e('Hasura error loading public profile', error: e, stackTrace: st);
      setState(() {
        errorMessage = 'Failed to load profile.';
        isLoading = false;
      });
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchCall(String phone) async {
    // Clean phone number to digits only for reliable calling
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri(scheme: 'tel', path: digitsOnly);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showFullScreenPhoto(BuildContext context, String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black, // Dark background for the image
          insetPadding: EdgeInsets.zero, // Use full screen space
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              // Image centered within the dialog
              Center(
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.contain, // Ensure the whole image is visible
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.error,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              // Close button
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(
    BuildContext context, 
      String title, 
      IconData icon, 
      String? content,
      {bool isPhone = false, VoidCallback? onTap}) 
  {
    // Only display the tile if the content is present (not null or empty)
    if (content == null || content.isEmpty) {
      return const SizedBox.shrink();
    }
  
    // Format phone number if requested
    final displayContent = isPhone ? formatUSPhone(content) : content;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(displayContent),
      // Use the title as the subtitle for context (e.g., "Phone Number", "Bio")
      subtitle: Text(title),
      dense: true,
      // Add vertical padding for better spacing
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), 
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (errorMessage != null) {
      return Scaffold(body: Center(child: Text(errorMessage!)));
    }
    if (profile == null) {
      return Scaffold(body: Center(child: Text("key_312".tr()))); // "No profile found"
    }

    final name = profile!['display_name'] as String? ?? 'Profile';
    final bio = profile!['bio'] as String?;
    final email = profile!['email'] as String?;
    final phone = profile!['phone'] as String?;
    final photoUrl = profile!['photo_url'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(name.isNotEmpty ? name : 'Profile')),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Card( // 💡 Wrap the whole profile in a Card
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0), // Padding only for the bottom
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header (Avatar and Name)
                  Container(
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.05), // Light background for header
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: () => _showFullScreenPhoto(context, photoUrl),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              child: (photoUrl != null && photoUrl.isNotEmpty)
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: photoUrl,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.person, size: 50),
                                      ),
                                    )
                                  : const Icon(Icons.person, size: 50, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                
                  const Divider(height: 1, thickness: 1), // Separator

                  // 2. Contact Information
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        // Email
                        _buildInfoTile(
                          context,
                          "key_305d".tr(), // "Email Address"
                          Icons.email,
                          email,
                          onTap: email != null ? () => _launchEmail(email) : null,
                        ),
                        // Phone
                        _buildInfoTile(
                          context,
                          "key_305c".tr(), // "Phone Number"
                          Icons.phone,
                          phone,
                          isPhone: true,
                          onTap: phone != null ? () => _launchCall(phone) : null,
                        ),
                      ],
                    ),
                  ),
                
                  // 3. Bio (separate section for longer text)
                  if (bio != null && bio.isNotEmpty) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                      title: Text("key_305b".tr(), style: Theme.of(context).textTheme.titleSmall), // "Bio"
                      subtitle: Text(bio),
                      isThreeLine: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
