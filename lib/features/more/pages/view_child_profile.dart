// File: lib/features/more/pages/view_child_profile.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ViewChildProfilePage extends StatefulWidget {
  final String childId;
  const ViewChildProfilePage({super.key, required this.childId});

  @override
  State<ViewChildProfilePage> createState() => _ViewChildProfilePageState();
}

class _ViewChildProfilePageState extends State<ViewChildProfilePage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  Map<String, dynamic>? _child;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChild();
  }

  Future<void> _loadChild() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _supabase
          .from('child_profiles')
          .select()
          .eq('id', widget.childId)
          .maybeSingle();
      setState(() => _child = response);
    } catch (e) {
      setState(() => _error = 'Failed to load child profile');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _child == null) {
      return Scaffold(body: Center(child: Text(_error ?? 'Child not found')));
    }

    final child = _child!;
    final name = child['name'] ?? 'Unnamed';
    final birthday = child['birthday'];
    final formattedBirthday = birthday != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(birthday))
        : null;
    final photoUrl = child['photo_url'];
    final allergies = child['allergies'] ?? 'None';
    final emergency = child['emergency_contact'] ?? 'None';
    final qrUrl = child['qr_code_url'];

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (photoUrl != null && photoUrl.isNotEmpty)
              CircleAvatar(
                radius: 50,
                backgroundImage: CachedNetworkImageProvider(photoUrl),
              ),
            const SizedBox(height: 16),
            Text(name, style: Theme.of(context).textTheme.headlineSmall),
            if (formattedBirthday != null)
              Text('Birthday: $formattedBirthday'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: const Text('Allergies'),
              subtitle: Text(allergies),
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone),
              title: const Text('Emergency Contact'),
              subtitle: Text(emergency),
            ),
            if (qrUrl != null && qrUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    const Text('Check-in QR Code:'),
                    const SizedBox(height: 8),
                    Image.network(qrUrl, height: 180),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }
}
