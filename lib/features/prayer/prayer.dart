// File: lib/features/prayer/prayer_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

      _appState = context.read<AppState>(); 
      
      _authSub = () {
        _loadRoleAndRequests();
      };
      _appState!.authChangeNotifier.addListener(_authSub!);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
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
          checked
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
          SnackBar(content: Text("key_331".tr(args: [e.toString()]))),
        );
      }
    }
  }

  Future<void> _markPrayerAsChecked(String prayerId) async {
    final client = _client(context);
    const m = r'''
      mutation MarkChecked($id: uuid!) {
        update_prayer_requests_by_pk(
          pk_columns: { id: $id }, 
          _set: { checked: true }
        ) { 
          id 
          checked 
        }
      }
    ''';

    try {
      final res = await client.mutate(
        MutationOptions(document: gql(m), variables: {'id': prayerId}),
      );
    
      if (res.hasException) throw res.exception!;
    
      // Refresh the list to show the checkmark has disappeared
      await _loadPrayerRequests();
    
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // You might want to create a specific translation key for this later
          SnackBar(content: Text("Marked as checked".tr())), 
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")), // Replace with localized error if available
        );
      }
    }
  }

  Future<void> _confirmAndClosePrayer(String prayerId) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "key_332".tr(), 
          style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
        ),
        content: Text("key_333".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("key_334".tr()), 
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("key_335".tr()),
          ),
        ],
        actionsPadding: const EdgeInsets.all(16),
        actionsAlignment: MainAxisAlignment.end,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_336".tr()))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_337".tr(args: [e.toString()]))),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("key_340".tr(args: [e.toString()]))));
          }
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _userId(context);
    final isSupervisorOrOwner = _userRole == 'supervisor' || _userRole == 'owner';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // --- START: Added check for logged out user ---
    if (currentUserId == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 48, color: colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  "key_338".tr(), // Use a localization key for this message
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
                ),
                const SizedBox(height: 8),
                Text(
                  "key_338a".tr(), // Hardcoded fallback or another key
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    context.push('/auth');
                  }, 
                  icon: const Icon(Icons.login), 
                  label: Text("key_017".tr()),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _prayerRequests.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.thumb_up_alt_outlined, size: 48, color: colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          "key_341".tr(),
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(color: Colors.black),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "key_429".tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        )
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPrayerRequests,
                  color: colorScheme.primary,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _prayerRequests.length,
                    itemBuilder: (context, index) {
                      final item = _prayerRequests[index];
                      
                      final prayerUserId = item['user_id'] as String?;
                      final isPrayerOwner = prayerUserId != null && prayerUserId == currentUserId;
                      final canClose = isSupervisorOrOwner || isPrayerOwner;
                      final isChecked = item['checked'] == true;
                      final showCheckAction = isSupervisorOrOwner && !isChecked;
                      final createdAtDateTime = item['created_at'] != null 
                          ? DateTime.parse(item['created_at']).toLocal()
                          : null;
                      final createdAt = createdAtDateTime != null 
                          ? DateFormat('dd/MM/yy h:mm a').format(createdAtDateTime)
                          : '';

                      final includeName = item['include_name'] == true;
                      
                      final shouldShowName = includeName || canClose;

                      final displayName = item['profiles']?['display_name'] as String? ?? 'A user';

                      String subtitleText;
                      if (!shouldShowName) {
                        subtitleText = "key_posted_on".tr(args: [createdAt]); 
                      } else if (!includeName && canClose) {
                        subtitleText = "key_posted_on".tr(args: [createdAt]);
                      } else {
                        subtitleText = "key_posted_by_on".tr(args: [displayName, createdAt]);
                      }

                      Widget? trailingWidget;

                      if (showCheckAction || canClose) {
                        trailingWidget = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showCheckAction)
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline),
                                color: Colors.green, // Visual distinction
                                tooltip: "Mark as checked",
                                onPressed: () => _markPrayerAsChecked(item['id'] as String),
                              ),
                            if (canClose)
                              IconButton(
                                icon: Icon(Icons.close, color: colorScheme.error),
                                tooltip: "key_332".tr(),
                                onPressed: () => _confirmAndClosePrayer(item['id'] as String),
                              ),
                          ],
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Card.filled( 
                          elevation: 0,
                          color: colorScheme.surfaceContainerHigh,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Icon(
                              Icons.menu_book_outlined,
                              color: colorScheme.primary,
                              size: 32,
                            ),
                            title: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                (item['request'] ?? '') as String,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                            ),
                            trailing: trailingWidget,
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        onPressed: _showPrayerRequestForm,
        tooltip: "key_342a".tr(),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text("key_424".tr()),
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
  final TextEditingController _requestController = TextEditingController();
  
  String _request = '';
  bool _includeName = true;

  @override
  void initState() {
    super.initState();
    _requestController.addListener(_updateRequest);
    _request = _requestController.text;
  }

  @override
  void dispose() {
    _requestController.removeListener(_updateRequest);
    _requestController.dispose();
    super.dispose();
  }

  void _updateRequest() {
    _request = _requestController.text;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = colorScheme.primary;
    
    final buttonStyle = ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        shape: const StadiumBorder(),
        foregroundColor: colorScheme.onPrimary, 
    );

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
          left: 20,
          right: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "key_428".tr(),
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: Colors.black, 
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _requestController,
                maxLines: 5,
                style: textTheme.bodyLarge,
                decoration: InputDecoration(
                    labelText: "key_427".tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withAlpha(77),
                    alignLabelWithHint: true,
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "key_047d".tr() : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text("key_425".tr(), style: textTheme.bodyLarge),
                subtitle: Text("key_426".tr(), style: textTheme.bodySmall),
                value: _includeName,
                onChanged: (val) => setState(() => _includeName = val),
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.green,
                inactiveThumbColor: primaryColor,
                inactiveTrackColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Theme.of(context).colorScheme.primary,
                  shape: const StadiumBorder(),
                  elevation: 8,
                  shadowColor: primaryColor.withAlpha(200),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.local_library_outlined),
                    label: Text("key_242".tr()), 
                    style: buttonStyle.copyWith(
                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                      overlayColor: WidgetStateProperty.all(colorScheme.onPrimary.withAlpha(30)),
                      elevation: WidgetStateProperty.all(0),
                    ),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        widget.onSubmit(_request, _includeName);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}