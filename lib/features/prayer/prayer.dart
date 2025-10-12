// File: lib/features/prayer/prayer_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/routes/router_observer.dart';
import 'package:ccf_app/app_state.dart';

class PrayerPage extends StatefulWidget {
  const PrayerPage({super.key});

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> with RouteAware {
  List<Map<String, dynamic>> _prayerRequests = [];
  String _userRole = 'anonymous';
  bool _loading = true;
  bool _bootstrapped = false;
  
  // Store a reference to the AppState object
  AppState? _appState;
  VoidCallback? _authSub;

  GraphQLClient _client(BuildContext ctx) => GraphQLProvider.of(ctx).value;
  String? _userId(BuildContext ctx) => ctx.read<AppState>().profile?.id;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    if (!_bootstrapped) {
      _bootstrapped = true;
      _loadRoleAndRequests();
      // react to login/logout

      // Safely read the provider here and save it to the field.
      // The listen: false is important here.
      _appState = context.read<AppState>(); 
      
      _authSub = () {
        // when auth flips, reload everything
        _loadRoleAndRequests();
      };
      _appState!.authChangeNotifier.addListener(_authSub!);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    // Use the saved reference to remove the listener
    if (_authSub != null && _appState != null) {
      _appState!.authChangeNotifier.removeListener(_authSub!);
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadPrayerRequests();
  }

  Future<void> _loadRoleAndRequests() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _getUserRole();
    await _loadPrayerRequests();
  }

  Future<void> _getUserRole() async {
    final client = _client(context);
    final userId = _userId(context);
    if (userId == null) {
      if (mounted) setState(() => _userRole = 'anonymous');
      return;
    }

    const q = r'''
      query GetMyRole($id: String!) {
        profiles_by_pk(id: $id) { role }
      }
    ''';

    try {
      final res = await client.query(QueryOptions(
        document: gql(q),
        variables: {'id': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (!mounted) return;
      final role = res.data?['profiles_by_pk']?['role'] as String?;
      setState(() => _userRole = role ?? 'anonymous');
    } catch (_) {
      if (mounted) setState(() => _userRole = 'anonymous');
    }
  }

  Future<void> _loadPrayerRequests() async {
    final client = _client(context);

    const q = r'''
      query DebugPrayer {
        prayer_requests(where: { status: { _eq: "open" } }, order_by: { created_at: desc }, limit: 20) {
          id
          status
          user_id
          request
          include_name
          created_at
          profiles {
            display_name
          }
        }
      }
    ''';

    try {
      final res = await client.query(QueryOptions(
        document: gql(q),
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (!mounted) return;

      if (res.hasException) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load prayer requests')),
        );
        return;
      }

      final rows = (res.data?['prayer_requests'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _prayerRequests = rows;
        _loading = false;
      });
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text("key_334".tr())),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text("key_335".tr())),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final client = _client(context);
    const m = r'''
      mutation ClosePrayer($id: uuid!) {
        update_prayer_requests_by_pk(pk_columns: {id: $id}, _set: { status: "closed" }) { id }
      }
    ''';

    try {
      final res = await client.mutate(
        MutationOptions(document: gql(m), variables: {'id': prayerId}),
      );
      if (res.hasException) throw res.exception!;
      await _loadPrayerRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_330".tr())));
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
        final client = _client(context);
        final userId = _userId(context);
        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_338".tr())));
          return;
        }
        final navigator = Navigator.of(context);

        const m = r'''
          mutation InsertPrayer($user_id: String!, $request: String!, $include_name: Boolean!) {
            insert_prayer_requests_one(object: {
              user_id: $user_id,
              request: $request,
              include_name: $include_name,
              status: "open"
            }) { id }
          }
        ''';

        try {
          final res = await client.mutate(
            MutationOptions(
              document: gql(m),
              variables: {'user_id': userId, 'request': request, 'include_name': includeName},
            ),
          );
          if (res.hasException) throw res.exception!;
          if (mounted) {
            navigator.pop();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_339".tr())));
            _loadPrayerRequests();
          }
        } catch (e) {
          if (mounted) {
            navigator.pop();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _userId(context);
    final isSupervisorOrOwner = _userRole == 'supervisor' || _userRole == 'owner';

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
                          : ((item['profiles']?['display_name'] ?? 'Someone') as String);

                      final prayerUserId = item['user_id'] as String?;
                      final isPrayerOwner = prayerUserId != null && prayerUserId == currentUserId;
                      final canClose = isSupervisorOrOwner || isPrayerOwner;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text((item['request'] ?? '') as String),
                          subtitle: Text("key_342".tr(args: [name])),
                          trailing: canClose
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Mark as closed',
                                  onPressed: () => _confirmAndClosePrayer(item['id'] as String),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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