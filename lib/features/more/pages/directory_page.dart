// File: lib/features/more/pages/directory_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key});

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchDirectoryUsers() async {
    final data = await supabase
        .from('profiles')
        .select('id, display_name, photo_url') // <-- Add photo_url here
        .eq('visible_in_directory', true)
        .order('display_name', ascending: true);

    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Directory'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchDirectoryUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(child: Text('No users in the directory.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final user = users[index];
              final photoUrl = user['photo_url'];

              return ListTile(
                leading: photoUrl != null && photoUrl.toString().isNotEmpty
                    ? CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: null,
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: photoUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                        ),
                      )
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user['display_name'] ?? 'Unnamed User'),
                onTap: () {
                  context.push('/profile/${user['id']}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
