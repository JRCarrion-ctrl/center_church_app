import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrayerPage extends StatefulWidget {
  const PrayerPage({super.key});

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _prayerRequests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrayerRequests();
  }

  Future<void> _loadPrayerRequests() async {
    try {
      final response = await _supabase
          .from('prayer_requests')
          .select('request, include_name, profiles(display_name)')
          .eq('status', 'open')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _prayerRequests = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load prayer requests: $e')),
        );
      }
    }
  }

  Future<void> _confirmAndClosePrayer(String prayerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Prayer Request'),
        content: const Text('Are you sure you want to close this prayer request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _supabase
          .from('prayer_requests')
          .update({'status': 'closed'})
          .eq('id', prayerId);

      if (!mounted) return;
      await _loadPrayerRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prayer request closed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error closing request: $e')),
        );
      }
    }
  }


  void _showPrayerRequestForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PrayerRequestForm(onSubmit: (request, includeName) async {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not logged in')),
          );
          return;
        }

        final navigator = Navigator.of(context);
        try {
          await Supabase.instance.client.from('prayer_requests').insert({
            'user_id': userId,
            'request': request,
            'include_name': includeName,
          });
          if (mounted) {
            navigator.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Prayer request submitted')),
            );
            _loadPrayerRequests();
          }
        } catch (e) {
          if (mounted) {
            navigator.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _prayerRequests.isEmpty
              ? const Center(child: Text('No prayer requests yet.'))
              : ListView.builder(
                  itemCount: _prayerRequests.length,
                  itemBuilder: (context, index) {
                    final item = _prayerRequests[index];
                    final isAnonymous = item['include_name'] == false;
                    final name = isAnonymous
                        ? 'Anonymous'
                        : (item['profiles']?['display_name'] ?? 'Someone');

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(item['request'] ?? ''),
                        subtitle: Text('From: $name'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Mark as closed',
                          onPressed: () {
                            _confirmAndClosePrayer(item['id']);
                          },
                        ),
                      ),
                    );

                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPrayerRequestForm,
        tooltip: 'Submit Prayer Request',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PrayerRequestForm extends StatefulWidget {
  final Future<void> Function(String request, bool includeName) onSubmit;

  const PrayerRequestForm({super.key, required this.onSubmit});

  @override
  State<PrayerRequestForm> createState() => _PrayerRequestFormState();
}

class _PrayerRequestFormState extends State<PrayerRequestForm> {
  final _formKey = GlobalKey<FormState>();
  String _request = '';
  bool _includeName = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Submit Prayer Request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Your request'),
              maxLines: 3,
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              onChanged: (val) => _request = val,
            ),
            SwitchListTile(
              title: const Text('Include my name'),
              value: _includeName,
              onChanged: (val) => setState(() => _includeName = val),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Submit'),
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  widget.onSubmit(_request, _includeName);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
