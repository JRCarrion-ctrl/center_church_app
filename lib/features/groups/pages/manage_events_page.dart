// filename: lib/features/groups/pages/manage_events_page.dart
import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ccf_app/routes/router_observer.dart';
import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../../calendar/event_service.dart';
import '../../calendar/models/group_event.dart';

class GroupEventDetailsPage extends StatefulWidget {
  final GroupEvent event;
  const GroupEventDetailsPage({super.key, required this.event});

  @override
  State<GroupEventDetailsPage> createState() => _GroupEventDetailsPageState();
}

class _GroupEventDetailsPageState extends State<GroupEventDetailsPage> with RouteAware, SingleTickerProviderStateMixin {
  late EventService _eventService;
  late TabController _tabController;
  
  int _attendingCount = 1;
  bool _saving = false;
  bool _isSupervisor = false;
  List<Map<String, dynamic>> _rsvps = [];
  bool _inited = false;

  // --- Slot State ---
  List<GroupEventSlot> _slots = [];
  bool _loadingSlots = true;
  Map<String, int> _mySlots = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    routeObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
    
    if (!_inited) {
      _inited = true;
      
      final client = GraphProvider.of(context);
      final userId = context.read<AppState>().profile?.id;
      _eventService = EventService(client, currentUserId: userId);

      _checkRole();
      _loadData();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
    _checkRole();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadRSVPs(),
      _loadSlots(),
    ]);
  }

  Future<void> _loadSlots() async {
    try {
      final slotsData = await _eventService.fetchGroupEventSlots(widget.event.id);
      final slotIds = slotsData.map((s) => s.id).whereType<String>().toList();
      final myAssignments = await _eventService.fetchUserAssignments(slotIds);

      if (mounted) {
        setState(() {
          _slots = slotsData;
          _mySlots = myAssignments;
        });
      }
    } catch (e) {
      debugPrint("Error loading slots: $e");
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _onUnclaimSlot(String slotId) async {
    setState(() => _saving = true);
    try {
      await _eventService.unclaimSlot(slotId: slotId);
      await _loadSlots(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Removed sign-up")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error removing sign-up")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- REFACTORED: Sleek iOS Bottom Sheet ---
  Future<void> _showSlotBottomSheet(dynamic slot, int myCurrentQty) async {
    final int othersCount = slot.currentCount - myCurrentQty;
    final int maxAvailableForMe = slot.maxSlots - othersCount;

    if (maxAvailableForMe <= 0 && myCurrentQty == 0) return;

    int selectedQty = myCurrentQty > 0 ? myCurrentQty : 1;

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Required for custom rounded corners
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // iOS Drag Handle
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    
                    Text(
                      slot.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "How many are you bringing?",
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Modern Quantity Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCircleBtn(Icons.remove, onPressed: selectedQty > 0 
                            ? () => setSheetState(() => selectedQty--) 
                            : null),
                        Container(
                          width: 100, 
                          alignment: Alignment.center,
                          child: Text(
                            "$selectedQty",
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
                          ),
                        ),
                        _buildCircleBtn(Icons.add, onPressed: selectedQty < maxAvailableForMe 
                            ? () => setSheetState(() => selectedQty++) 
                            : null),
                      ],
                    ),
                    
                    const SizedBox(height: 32),

                    // Big Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, selectedQty),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedQty == 0 ? Colors.red[50] : Theme.of(context).primaryColor,
                          foregroundColor: selectedQty == 0 ? Colors.red : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          selectedQty == 0 ? "Remove Sign-up" : "Confirm",
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || result == myCurrentQty) return;
    if (result == 0) {
      await _onUnclaimSlot(slot.id!);
    } else {
      await _onUpdateSlotQty(slot.id!, result);
    }
  }

  Widget _buildCircleBtn(IconData icon, {VoidCallback? onPressed}) {
    return Container(
      width: 56, // Larger touch target
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onPressed == null ? Colors.grey[100] : Colors.grey[200],
      ),
      child: IconButton(
        icon: Icon(icon, color: onPressed == null ? Colors.grey : Colors.black87, size: 28),
        onPressed: onPressed,
      ),
    );
  }

  Future<void> _onUpdateSlotQty(String slotId, int qty) async {
    setState(() => _saving = true);
    try {
      await _eventService.claimSlot(slotId: slotId, quantity: qty);
      await _loadSlots(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error updating")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkRole() async {
    final uid = context.read<AppState>().profile?.id;
    final userRole = context.read<AppState>().userRole;
    if (userRole.name == 'owner') {
       if (mounted) setState(() => _isSupervisor = true);
       return;
    }
    if (uid == null || uid.isEmpty) return;
    try {
      final role = await _eventService.checkGroupMemberRole(groupId: widget.event.groupId, userId: uid);
      if (!mounted) return;
      setState(() {
        _isSupervisor = const {'leader', 'supervisor', 'owner', 'admin'}.contains(role);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSupervisor = false);
    }
  }

  Future<void> _loadRSVPs() async {
    try {
      final data = await _eventService.fetchGroupEventRSVPs(widget.event.id);
      if (!mounted) return;
      final currentUserId = context.read<AppState>().profile?.id;
      int currentAttendingCount = 1; 
      if (currentUserId != null) {
        try {
          final existingRsvp = data.firstWhere((r) => r['user_id'] == currentUserId);
          currentAttendingCount = existingRsvp['attending_count'] as int? ?? 1;
        } catch (_) {}
      }
      setState(() {
        _rsvps = data;
        _attendingCount = currentAttendingCount;
      });
    // ignore: empty_catches
    } catch (e) {}
  }

  Future<void> _submitRSVP() async {
    final uid = context.read<AppState>().profile?.id;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _eventService.rsvpGroupEvent(eventId: widget.event.id, count: _attendingCount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_138".tr())));
      _loadData(); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeRSVP() async {
    final uid = context.read<AppState>().profile?.id;
    if (uid == null || uid.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _eventService.removeGroupEventRSVP(widget.event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_136".tr())));
      _loadData(); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); 
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onClaimSlot(String slotId) async {
    setState(() => _saving = true);
    try {
      await _eventService.claimSlot(slotId: slotId);
      await _loadSlots(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Signed up!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error signing up")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onEditEvent() async {
    await context.push('/groups/${widget.event.groupId}/info/events/edit', extra: widget.event);
    if (mounted) _loadData(); 
  }

  void addEventToCalendar(GroupEvent event) {
    final calendarEvent = Event(
      title: event.title,
      description: event.description,
      startDate: event.eventDate,
      endDate: event.eventEnd ?? event.eventDate.add(const Duration(hours: 1)),
      location: event.location ?? '5115 Pegasus Ct. Frederick, MD 21704 United States',
    );
    Add2Calendar.addEvent2Cal(calendarEvent);
  }

  String _formatEventTime(DateTime startUtc, DateTime? endUtc) {
    final start = startUtc.toLocal();
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(start);
    final startStr = DateFormat('h:mm a').format(start);
    if (endUtc != null) {
      final end = endUtc.toLocal();
      if (DateUtils.isSameDay(start, end)) {
        final endStr = DateFormat('h:mm a').format(end);
        return '$dateStr • $startStr - $endStr';
      } else {
         final endDateStr = DateFormat('MMM d, h:mm a').format(end);
         return '$dateStr • $startStr - $endDateStr';
      }
    }
    return '$dateStr • $startStr';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AppState>().profile?.id; 
    final myRsvpEntry = currentUserId != null && _rsvps.isNotEmpty
        ? _rsvps.firstWhere((r) => r['user_id'] == currentUserId, orElse: () => {})
        : <String, dynamic>{};
    final hasRSVP = myRsvpEntry.isNotEmpty;
    final e = widget.event;
    final canPop = GoRouter.of(context).canPop();

    return Scaffold(
      body: NestedScrollView(
        // ✅ FIX: Bouncing Physics prevents "Build scheduled during frame" crash
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: Text(e.title),
              floating: true,
              pinned: true,
              leading: canPop
                  ? null
                  : IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/')),
              actions: [
                if (_isSupervisor)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: "key_076".tr(),
                    onPressed: _onEditEvent,
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16), // Rounded corners
                        child: CachedNetworkImage(
                          imageUrl: e.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox(
                            height: 200, 
                            child: Center(child: CircularProgressIndicator())
                          ),
                          errorWidget: (context, url, error) => const SizedBox(
                            height: 200, 
                            child: Center(child: Icon(Icons.broken_image, size: 50))
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(e.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      _formatEventTime(e.eventDate, e.eventEnd),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    ),
                    if (e.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      SelectableLinkify(
                        text: e.description!,
                        style: Theme.of(context).textTheme.bodyLarge,
                        onOpen: (link) => launchUrl(Uri.parse(link.url)),
                      ),
                    ],
                    if (e.location?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(child: Text(e.location!, style: Theme.of(context).textTheme.bodyMedium)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => addEventToCalendar(e),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text("key_140".tr()),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: "key_140a".tr()), 
                    const Tab(text: "Sign-ups"),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRsvpSection(hasRSVP, currentUserId, myRsvpEntry),
            _buildSignUpSection(hasRSVP),
          ],
        ),
      ),
    );
  }

  Widget _buildRsvpSection(bool hasRSVP, String? currentUserId, Map<String, dynamic> myRsvpEntry) {
    int othersCount = 0;
    for (var rsvp in _rsvps) {
      if (rsvp['user_id'] != currentUserId) {
        othersCount += (rsvp['attending_count'] as int? ?? 0);
      }
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text("key_141".tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _attendingCount,
                      underline: Container(), // Remove ugly underline
                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      onChanged: (val) => setState(() => _attendingCount = val!),
                      items: List.generate(10, (i) => i + 1)
                          .map((i) => DropdownMenuItem(value: i, child: Text(i.toString())))
                          .toList(),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _saving ? null : _submitRSVP,
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _saving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : Text("key_142".tr()),
                    ),
                  ],
                ),
                if (hasRSVP)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _saving ? null : _removeRSVP,
                      child: Text("key_143".tr(), style: const TextStyle(color: Colors.red)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        if (_rsvps.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text("key_143a".tr(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (_isSupervisor)
            ..._rsvps.map((rsvp) => _buildRsvpTile(rsvp))
          else ...[
            if (hasRSVP) _buildRsvpTile(myRsvpEntry),
            if (othersCount > 0)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text("+ $othersCount others are attending", style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
              ),
          ]
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  // --- REFACTORED: Sleek Cards & Progress Bars ---
  Widget _buildSignUpSection(bool hasRSVP) {
    if (!hasRSVP) { 
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("Please RSVP to view sign-ups", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      )); 
    }
    if (_loadingSlots) return const Center(child: CircularProgressIndicator());
    if (_slots.isEmpty) return Center(child: Text("No items needed for this event.", style: TextStyle(color: Colors.grey[600])));

    return ListView.builder(
      itemCount: _slots.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final slot = _slots[index];
        final filled = slot.currentCount;
        final remaining = slot.maxSlots - filled;
        final isFull = remaining <= 0;
        
        final myQty = _mySlots[slot.id] ?? 0;
        final bool iSignedUp = myQty > 0;
        final bool canMulti = slot.maxSlots > 1;

        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade200, width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16), 
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: slot.maxSlots > 0 ? filled / slot.maxSlots : 0,
                          backgroundColor: Colors.grey[100],
                          color: isFull ? Colors.orangeAccent : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text("$filled / ${slot.maxSlots}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          if (iSignedUp) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                              child: Text("You: $myQty", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                            )
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildSlotAction(slot, isFull, iSignedUp, myQty, canMulti),
              ],
            ),
          )
        );
      },
    );
  }

  Widget _buildSlotAction(GroupEventSlot slot, bool isFull, bool iSignedUp, int myQty, bool canMulti) {
    if (canMulti) {
       return SizedBox(
         height: 36,
         child: OutlinedButton(
           onPressed: (_saving || (isFull && !iSignedUp)) 
               ? null 
               : () => _showSlotBottomSheet(slot, myQty),
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
           child: Text(iSignedUp ? "Edit" : "Sign Up"),
         ),
       );
    }

    if (iSignedUp) {
      return SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: !_saving ? () => _onUnclaimSlot(slot.id!) : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: BorderSide(color: Colors.red.shade200),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text("Leave"),
        ),
      );
    } else {
      return SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: (!isFull && !_saving) ? () => _onClaimSlot(slot.id!) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: !isFull ? Theme.of(context).colorScheme.primary : Colors.grey[300],
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Text(isFull ? "Full" : "Sign Up"),
        ),
      );
    }
  }

  Widget _buildRsvpTile(Map<String, dynamic> rsvp) {
    final profile = rsvp['profiles'] ?? {}; 
    final photoUrl = profile['photo_url'];
    final displayName = profile['display_name'] ?? 'Unknown';
    final email = profile['email'] ?? '';
    final count = rsvp['attending_count'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
            ? CachedNetworkImageProvider(photoUrl)
            : null,
        child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 20) : null,
      ),
      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(email, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('+$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class GroupEventDeepLinkWrapper extends StatefulWidget {
  final String eventId;
  final GroupEvent? preloadedEvent;
  const GroupEventDeepLinkWrapper({super.key, required this.eventId, this.preloadedEvent});

  @override
  State<GroupEventDeepLinkWrapper> createState() => _GroupEventDeepLinkWrapperState();
}

class _GroupEventDeepLinkWrapperState extends State<GroupEventDeepLinkWrapper> {
  Future<GroupEvent?>? _eventFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_eventFuture == null && widget.preloadedEvent == null) {
      _eventFuture = _fetchEventById(widget.eventId);
    }
  }

  Future<GroupEvent?> _fetchEventById(String id) async {
    try {
      final client = GraphProvider.of(context); 
      const String query = r'''
        query GetGroupEvent($id: uuid!) {
          group_events_by_pk(id: $id) {
            id, group_id, title, description, event_date, event_end, location, image_url
          }
        }
      ''';
      final result = await client.query(QueryOptions(
        document: gql(query), variables: {'id': id}, fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (result.hasException) return null;
      final data = result.data?['group_events_by_pk'];
      if (data == null) return null;
      return GroupEvent(
        id: data['id'], groupId: data['group_id'], title: data['title'], description: data['description'],
        eventDate: DateTime.parse(data['event_date']),
        eventEnd: data['event_end'] != null ? DateTime.parse(data['event_end']) : null,
        location: data['location'], imageUrl: data['image_url'],
      );
    } catch (e) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.preloadedEvent != null) {
      return GroupEventDetailsPage(event: widget.preloadedEvent!);
    }
    return FutureBuilder<GroupEvent?>(
      future: _eventFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(appBar: AppBar(title: Text("key_error".tr())), body: Center(child: Text("key_event_not_found".tr())));
        }
        return GroupEventDetailsPage(event: snapshot.data!);
      },
    );
  }
}