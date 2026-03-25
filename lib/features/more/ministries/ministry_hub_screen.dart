import 'package:flutter/material.dart';

// 1. Define how a Ministry Card should look and act
class MinistryConfig {
  final String displayName;
  final IconData icon;
  final Widget destinationScreen;

  MinistryConfig({
    required this.displayName,
    required this.icon,
    required this.destinationScreen,
  });
}

class MinistryHubScreen extends StatefulWidget {
  final String currentUserId; // Pass this in from your ZITADEL auth state

  const MinistryHubScreen({super.key, required this.currentUserId});

  @override
  State<MinistryHubScreen> createState() => _MinistryHubScreenState();
}

class _MinistryHubScreenState extends State<MinistryHubScreen> {
  
  // 2. Map your Hasura public.groups.id to your UI configurations
  // Replace these UUIDs with the actual IDs from your database
  final Map<String, MinistryConfig> _ministryDirectory = {
    '8d8d6567-2b24-45d9-8b5d-bece06cd79c1': MinistryConfig(
      displayName: 'Worship Team',
      icon: Icons.music_note,
      destinationScreen: const Scaffold(body: Center(child: Text('Worship Portal'))), // Replace with WorshipDashboard()
    ),
    '531da19e-5550-4e75-b31a-6c3ea9834b32': MinistryConfig(
      displayName: '4:12',
      icon: Icons.videocam,
      destinationScreen: const Scaffold(body: Center(child: Text('4:12 Portal'))),
    ),
  };

  // Replace this with your actual Hasura fetch logic
  Future<List<Map<String, dynamic>>> _fetchApprovedMemberships() async {
    // Simulate a network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Example response structure from the GraphQL query above
    return [
      {
        'group_id': '8d8d6567-2b24-45d9-8b5d-bece06cd79c1',
        'role': 'Leader'
      }
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ministries'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchApprovedMemberships(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading ministries: ${snapshot.error}'));
          }

          final memberships = snapshot.data ?? [];

          // 3. The Empty State (If they aren't approved for anything yet)
          if (memberships.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('You are not in any active ministries.', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to a "Join with Code" screen
                    },
                    child: const Text('Enter Join Code'),
                  )
                ],
              ),
            );
          }

          // 4. Build the Active Ministry Cards
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: memberships.length,
            itemBuilder: (context, index) {
              final membership = memberships[index];
              final groupId = membership['group_id'];
              final role = membership['role'];

              // Look up the UI config for this specific group ID
              final config = _ministryDirectory[groupId];

              // If the group exists in DB but not in your Flutter config yet, skip it safely
              if (config == null) return const SizedBox.shrink();

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: Icon(config.icon, color: Theme.of(context).primaryColor),
                  ),
                  title: Text(
                    config.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Text('Role: $role'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => config.destinationScreen),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}