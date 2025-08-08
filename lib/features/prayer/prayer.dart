import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/routes/router_observer.dart';
import 'package:easy_localization/easy_localization.dart';

class PrayerPage extends StatefulWidget {
  const PrayerPage({super.key});

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> with RouteAware {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _prayerRequests = [];
  String _userRole = 'user'; // default
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoleAndRequests();
  }

  Future<void> _loadRoleAndRequests() async {
    await _getUserRole();
    await _loadPrayerRequests();
  }

  Future<void> _getUserRole() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final result = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _userRole = (result != null && result['role'] != null)
            ? result['role'] as String
            : 'user';
      });
    }
  }

  Future<void> _loadPrayerRequests() async {
    try {
      final response = await _supabase
          .from('prayer_requests')
          .select('id, request, include_name, profiles(display_name)')
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
        title: Text("key_332".tr()),
        content: Text("key_333".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("key_334".tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("key_335".tr()),
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
          SnackBar(content: Text("key_330".tr())),
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
            SnackBar(content: Text("key_338".tr())),
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
              SnackBar(content: Text("key_339".tr())),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadPrayerRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _prayerRequests.isEmpty
              ? Center(child: Text("key_341".tr()))
              : RefreshIndicator(
                  onRefresh: _loadPrayerRequests,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                          subtitle: Text("key_342".tr(args: [name])),
                          trailing: (_userRole == 'supervisor' || _userRole == 'owner')
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: 'Mark as closed',
                                onPressed: () => _confirmAndClosePrayer(item['id']),
                              )
                            : null,
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPrayerRequestForm,
        tooltip: "key_342a".tr(),
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
            Text(
              "key_342a".tr(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: "key_342b".tr()),
              maxLines: 3,
              validator: (val) => val == null || val.isEmpty ? "key_047d".tr() : null,
              onChanged: (val) => _request = val,
            ),
            SwitchListTile(
              title: Text("key_343".tr()),
              value: _includeName,
              onChanged: (val) => setState(() => _includeName = val),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: Text("key_344".tr()),
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
