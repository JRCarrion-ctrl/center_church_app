// File: lib/features/more/pages/view_child_profile.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:ccf_app/core/graph_provider.dart';

class ViewChildProfilePage extends StatefulWidget {
  final String childId;
  const ViewChildProfilePage({super.key, required this.childId});

  @override
  State<ViewChildProfilePage> createState() => _ViewChildProfilePageState();
}

class _ViewChildProfilePageState extends State<ViewChildProfilePage> {
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

    const q = r'''
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

    try {
      final client = GraphProvider.of(context);
      final res = await client.query(
        QueryOptions(
          document: gql(q),
          variables: {'id': widget.childId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (res.hasException) {
        setState(() => _error = 'Failed to load child profile');
      } else {
        final data = res.data?['child_profiles_by_pk'] as Map<String, dynamic>?;
        setState(() => _child = data);
      }
    } catch (_) {
      setState(() => _error = 'Failed to load child profile');
    } finally {
      if (mounted) setState(() => _loading = false);
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
              context.pushNamed('edit_child_profile', extra: child);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (photoUrl != null && photoUrl.isNotEmpty)
              CircleAvatar(
                radius: 60,
                backgroundImage: CachedNetworkImageProvider(photoUrl),
              ),
            const SizedBox(height: 20),
            Text(name, style: Theme.of(context).textTheme.headlineSmall),
            if (formattedBirthday != null)
              Text("key_320".tr(args: [formattedBirthday])),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: Text("key_321".tr()),
              subtitle: Text(allergies),
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: Text("key_322".tr()),
              subtitle: Text(notes),
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone),
              title: Text("key_323".tr()),
              subtitle: Text(emergency),
            ),
            if (qrUrl != null && qrUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "key_323a".tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Image.network(qrUrl, height: 180),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _formatBirthday(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  String _nonEmptyOr(String? value, String fallback) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? fallback : v;
    }
}
