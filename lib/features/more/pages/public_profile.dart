// File: lib/features/more/pages/public_profile.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

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

    final name = profile!['display_name'] ?? '';
    final photoUrl = profile!['photo_url'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(name.isNotEmpty ? name : 'Profile')),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            // 💡 ADD THIS LINE to make the children stretch across the screen
            crossAxisAlignment: CrossAxisAlignment.stretch, 
            children: [
              // The CircleAvatar needs centering, so we wrap it
              Center(
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
                      : const Icon(Icons.person, size: 50),
                ),
              ),
              // ... rest of the children (SizedBox, Text, ListTiles)
            ],
          ),
        ),
      ),
    );
  }
}
