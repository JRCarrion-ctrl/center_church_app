// File: lib/features/more/pages/public_profile.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PublicProfile extends StatefulWidget {
  final String userId;

  const PublicProfile({super.key, required this.userId});

  @override
  State<PublicProfile> createState() => _PublicProfileState();
}

class _PublicProfileState extends State<PublicProfile> {
  final _logger = Logger();
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? errorMessage;
  String formatUSPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return input;
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }


  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await supabase
          .from('public_profiles')
          .select('display_name, bio, email, phone, photo_url') // get photo_url
          .eq('id', widget.userId)
          .maybeSingle();
      setState(() {
        profile = data;
        isLoading = false;
      });
    } catch (e) {
      _logger.e('Supabase error loading public profile', error: e, stackTrace: StackTrace.current);
      setState(() {
        errorMessage = 'Failed to load profile.';
        isLoading = false;
      });
    }
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
      return const Scaffold(body: Center(child: Text('Profile not found')));
    }

    final name = profile!['display_name'] ?? '';
    final bio = profile!['bio'] ?? '';
    final email = profile!['email'];
    final phone = profile!['phone'];
    final photoUrl = profile!['photo_url'];

    return Scaffold(
      appBar: AppBar(title: Text(name.isNotEmpty ? name : 'Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile photo with cache
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              child: photoUrl != null && photoUrl.toString().isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(strokeWidth: 2),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.person, size: 50),
                      ),
                    )
                  : const Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: 12),
            if (bio.isNotEmpty)
              Text(
                bio,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            if (email != null && email.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.email),
                title: GestureDetector(
                  onTap: () => launchUrl(Uri.parse('mailto:$email')),
                  child: Text(
                    email,
                    style: const TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
            if (phone != null && phone.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.phone),
                title: GestureDetector(
                  onTap: () => launchUrl(Uri.parse('tel:$phone')),
                  child: Text(
                    formatUSPhone(phone),
                    style: const TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
