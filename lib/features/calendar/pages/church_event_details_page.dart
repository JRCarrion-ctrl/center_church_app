// filename: lib/features/calendar/pages/church_event_details_page.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/shared/user_roles.dart';
import 'package:ccf_app/shared/widgets/generic_share_modal.dart';
import '../church_event_service.dart';
import '../church_event_attachment_upload_service.dart';
import '../models/church_event.dart';
import '../models/church_event_attachment.dart';

class ChurchEventDetailsPage extends StatefulWidget {
  final ChurchEvent event;
  const ChurchEventDetailsPage({super.key, required this.event});

  @override
  State<ChurchEventDetailsPage> createState() => _ChurchEventDetailsPageState();
}

class _ChurchEventDetailsPageState extends State<ChurchEventDetailsPage> with SingleTickerProviderStateMixin {
  late ChurchEventService _eventService;
  late ChurchEventAttachmentUploadService _attachmentUploadService;
  late TabController _tabController;
  bool _svcReady = false;

  int _attendingCount = 1;
  bool _saving = false;
  bool _canEdit = false;
  List<Map<String, dynamic>> _rsvps = [];
  
  List<ChurchEventSlot> _slots = [];
  bool _loadingSlots = true;
  Map<String, int> _mySlots = {};

  List<ChurchEventAttachment> _attachments = [];
  bool _loadingAttachments = true;
  bool _uploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_svcReady) {
      final client = GraphQLProvider.of(context).value;
      final userId = context.read<AppState>().profile?.id;
      _eventService = ChurchEventService(client, currentUserId: userId);
      _attachmentUploadService = ChurchEventAttachmentUploadService(client);
      _svcReady = true;

      _checkRole();
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkRole() async {
    final userRole = context.read<AppState>().userRole;
    // Global Admins can edit anything
    if (userRole == UserRole.owner || userRole == UserRole.supervisor) {
       if (mounted) setState(() => _canEdit = true);
       return;
    }
    
    // If it's a group event, check if they are a leader of that specific group
    final uid = context.read<AppState>().profile?.id;
    if (uid != null && widget.event.groupId != null) {
      try {
        final role = await _eventService.checkGroupMemberRole(groupId: widget.event.groupId!, userId: uid);
        if (mounted) {
          setState(() => _canEdit = const {'leader', 'supervisor', 'owner', 'admin'}.contains(role));
        }
      } catch (_) {
        if (mounted) setState(() => _canEdit = false);
      }
    }
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadRSVPs(),
      _loadSlots(),
      _loadAttachments(),
    ]);
  }

  Future<void> _loadSlots() async {
    try {
      final slotsData = await _eventService.fetchEventSlots(widget.event.id);
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

  Future<void> _loadRSVPs() async {
    if (!_svcReady) return;
    try {
      final data = await _eventService.fetchEventRSVPs(widget.event.id);
      if (mounted) {
        final currentUserId = context.read<AppState>().profile?.id;
        final existingRsvp = data.firstWhere(
          (r) => r['user_id'] == currentUserId,
          orElse: () => <String, dynamic>{},
        );

        setState(() {
          _rsvps = data;
          if (existingRsvp.isNotEmpty) {
            _attendingCount = existingRsvp['attending_count'] as int? ?? 1;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAttachments() async {
    try {
      final data = await _eventService.fetchEventAttachments(widget.event.id);
      if (mounted) setState(() => _attachments = data);
    } catch (e) {
      debugPrint("Error loading attachments: $e");
    } finally {
      if (mounted) setState(() => _loadingAttachments = false);
    }
  }

  // --- SLOT ACTIONS ---

  Future<void> _onClaimSlot(String slotId, {int qty = 1}) async {
    setState(() => _saving = true);
    try {
      await _eventService.claimSlot(slotId: slotId, quantity: qty);
      await _loadSlots(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Signed up!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error signing up")));
    } finally {
      if (mounted) setState(() => _saving = false);
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

  // --- RSVP ACTIONS ---

  Future<void> _submitRSVP() async {
    if (!_svcReady) return;
    setState(() => _saving = true);
    try {
      await _eventService.rsvpEvent(eventId: widget.event.id, count: _attendingCount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_027".tr())));
      _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_please_log_in".tr())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeRSVP() async {
    if (!_svcReady) return;
    setState(() => _saving = true);
    try {
      await _eventService.removeRSVP(widget.event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_029".tr())));
      _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_030".tr())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- ATTACHMENT ACTIONS ---

  static const Map<String, String> _extensionToContentType = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'heic': 'image/heic',
    'txt': 'text/plain',
    'csv': 'text/csv',
  };

  String _guessContentType(String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    return _extensionToContentType[ext] ?? 'application/octet-stream';
  }

  Future<void> _pickAndUploadAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't read that file, please try again")),
        );
      }
      return;
    }

    setState(() => _uploadingAttachment = true);
    try {
      final contentType = _guessContentType(picked.name);
      final finalUrl = await _attachmentUploadService.uploadEventAttachment(
        eventId: widget.event.id,
        bytes: bytes,
        originalFileName: picked.name,
        contentType: contentType,
      );

      await _eventService.addEventAttachment(
        eventId: widget.event.id,
        fileName: picked.name,
        fileUrl: finalUrl,
        contentType: contentType,
        fileSizeBytes: picked.size,
        groupId: widget.event.groupId,
      );

      await _loadAttachments();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File attached")));
    } catch (e) {
      debugPrint("Error uploading attachment: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload failed, please try again")));
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _confirmDeleteAttachment(ChurchEventAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove file?"),
        content: Text('Remove "${attachment.fileName}" from this event?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _eventService.deleteEventAttachment(attachment.id);
      await _loadAttachments();
    } catch (e) {
      debugPrint("Error deleting attachment: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't remove file")));
    }
  }

  Future<void> _openAttachment(ChurchEventAttachment attachment) async {
    final uri = Uri.tryParse(attachment.fileUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // --- UI HELPERS ---

  Future<void> _onEditEvent() async {
    if (widget.event.groupId != null) {
      await context.push('/groups/${widget.event.groupId}/info/events/edit?eventId=${widget.event.id}');
    } else {
      await context.push('/manage-app-event/edit?eventId=${widget.event.id}');
    }
    
    if (mounted) {
      _loadData();
      _checkRole();
    }
  }

  void addEventToCalendar(ChurchEvent event) {
    final calendarEvent = Event(
      title: event.title,
      description: event.description ?? '',
      startDate: event.eventDate,
      endDate: event.eventEnd ?? event.eventDate.add(const Duration(hours: 1)),
      location: event.location ?? '5115 Pegasus Ct. Frederick, MD 21704 United States',
    );
    Add2Calendar.addEvent2Cal(calendarEvent);
  }

  void _showShareModal() {
    // 1. Determine the correct path based on whether it's a group event or app event
    final isGroupEvent = widget.event.groupId != null;
    final basePath = isGroupEvent 
        ? '/group-event/${widget.event.id}' 
        : '/calendar/app-event/${widget.event.id}';
    
    // 2. Construct the full deep link
    final shareUrl = 'https://ccfapp.com$basePath';

    // 3. Trigger the modal
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: GenericShareModal(
            title: "key_share".tr(),
            description: "key_share_description".tr(),
            shareUrl: shareUrl,
          ),
        ),
      ),
    );
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
    final e = widget.event;
    final canPop = GoRouter.of(context).canPop();
    final currentUserId = context.select<AppState, String?>((s) => s.profile?.id);
    final hasRSVP = _rsvps.any((r) => r['user_id'] == currentUserId);

    return Scaffold(
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: Text(e.title),
              floating: true,
              pinned: true,
              leading: canPop
                  ? null
                  : IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/calendar')),
              actions: [
                // ✨ NEW: The Share Button
                IconButton(
                  icon: const Icon(Icons.ios_share), // or Icons.share depending on your preference
                  tooltip: "key_share".tr(),
                  onPressed: _showShareModal,
                ),
                // Existing Edit Button
                if (_canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: "key_038".tr(),
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
                    // ✨ NEW: Pending Approval Badge
                    if (e.isPending)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.pending_actions, color: Colors.orange.shade800),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Pending Approval",
                                style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (e.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: e.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox(
                            child: Center(child: CircularProgressIndicator())
                          ),
                          errorWidget: (context, url, error) => const SizedBox(
                            child: Center(child: Icon(Icons.broken_image, size: 100))
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(e.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    
                    // Show Group Name if applicable
                    if (e.groupName != null && e.groupId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                        child: ActionChip(
                          avatar: Icon(
                            Icons.groups_2_outlined, 
                            size: 18, 
                            color: Theme.of(context).colorScheme.primary
                          ),
                          label: Text(
                            e.groupName!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: Theme.of(context).colorScheme.primary
                            ),
                          ),
                          // Navigate directly to the group dashboard
                          onPressed: () => context.push('/groups/${e.groupId}'),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                      
                    const SizedBox(height: 6),
                    Text(
                      _formatEventTime(e.eventDate, e.eventEnd),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 6),
                    
                    if ((e.description ?? '').isNotEmpty) ...[
                      SelectableLinkify(
                        text: e.description!,
                        style: Theme.of(context).textTheme.bodyLarge,
                        onOpen: (link) async {
                          final Uri url = Uri.parse(link.url);
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        },
                      ),
                      const SizedBox(height: 6),
                      if (e.rrule != null && e.rrule!.contains('FREQ=DAILY')) ...[
                        Row(
                          children: [
                            Icon(Icons.event_repeat, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Repeats Daily',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if ((e.location ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: SelectableLinkify(
                                text: e.location!,
                                style: Theme.of(context).textTheme.bodyMedium,
                                onOpen: (link) => launchUrl(Uri.parse(link.url)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => addEventToCalendar(e),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text("key_031".tr()),
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
                    Tab(text: "key_031a".tr()), 
                    const Tab(text: "Sign-ups"),
                    const Tab(text: "Files"),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRsvpSection(hasRSVP, currentUserId),
            _buildSignUpSection(hasRSVP),
            _buildAttachmentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRsvpSection(bool hasRSVP, String? currentUserId) {
    int othersCount = 0;
    for (var rsvp in _rsvps) {
      if (rsvp['user_id'] != currentUserId) {
        othersCount += (rsvp['attending_count'] as int? ?? 0);
      }
    }

    final myRsvpEntry = currentUserId != null && _rsvps.isNotEmpty
        ? _rsvps.firstWhere((r) => r['user_id'] == currentUserId, orElse: () => <String, dynamic>{})
        : <String, dynamic>{};

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
                    Text("key_032".tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _attendingCount,
                      underline: Container(),
                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      onChanged: (val) => setState(() => _attendingCount = val!),
                      items: List.generate(10, (i) => i + 1).map((i) => DropdownMenuItem(value: i, child: Text("$i"))).toList(),
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
                        : Text(hasRSVP ? "key_033".tr() : "key_033".tr()),
                    ),
                  ],
                ),
                if (hasRSVP)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _saving ? null : _removeRSVP,
                      child: Text("key_033a".tr(), style: const TextStyle(color: Colors.red)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        if (_rsvps.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text("key_033b".tr(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (_canEdit) // If they can edit the event, they get to see everyone's RSVPs
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

  Widget _buildSignUpSection(bool hasRSVP) {
    if (!hasRSVP && widget.event.isGroupOnly) { 
      // Force RSVPs for group events before they can see slots
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
    if (_slots.isEmpty) return Center(child: Text("No items needed.", style: TextStyle(color: Colors.grey[600])));

    return ListView.builder(
      itemCount: _slots.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final slot = _slots[index];
        final filled = slot.currentCount;
        final isFull = (slot.maxSlots - filled) <= 0;
    
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
      }
    );
  }

  Widget _buildSlotAction(ChurchEventSlot slot, bool isFull, bool iSignedUp, int myQty, bool canMulti) {
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

  Future<void> _showSlotBottomSheet(dynamic slot, int myCurrentQty) async {
    final int othersCount = slot.currentCount - myCurrentQty;
    final int maxAvailableForMe = slot.maxSlots - othersCount;

    if (maxAvailableForMe <= 0 && myCurrentQty == 0) return;

    int selectedQty = myCurrentQty > 0 ? myCurrentQty : 1;

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
                    ),
                    Text(
                      slot.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text("How many are you bringing?", style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCircleBtn(Icons.remove, onPressed: selectedQty > 0 ? () => setSheetState(() => selectedQty--) : null),
                        Container(
                          width: 100,
                          alignment: Alignment.center,
                          child: Text("$selectedQty", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w600)),
                        ),
                        _buildCircleBtn(Icons.add, onPressed: selectedQty < maxAvailableForMe ? () => setSheetState(() => selectedQty++) : null),
                      ],
                    ),
                    const SizedBox(height: 32),
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
                        child: Text(selectedQty == 0 ? "Remove Sign-up" : "Confirm", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
      await _onClaimSlot(slot.id!, qty: result);
    }
  }

  Widget _buildCircleBtn(IconData icon, {VoidCallback? onPressed}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(shape: BoxShape.circle, color: onPressed == null ? Colors.grey[100] : Colors.grey[200]),
      child: IconButton(
        icon: Icon(icon, color: onPressed == null ? Colors.grey : Colors.black87, size: 28),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildRsvpTile(Map<String, dynamic> rsvp) {
    // Note: ensure this matches the `profile` object returned by your new V2 query
    final profile = rsvp['profile'] ?? {};
    final photoUrl = profile['photo_url'];
    final displayName = profile['display_name'] ?? 'Unknown';
    final email = profile['email'] ?? '';
    final count = rsvp['attending_count'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? CachedNetworkImageProvider(photoUrl) : null,
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

  // --- ATTACHMENTS TAB ---

  IconData _iconForAttachment(ChurchEventAttachment a) {
    if (a.isImage) return Icons.image_outlined;
    if (a.isPdf) return Icons.picture_as_pdf_outlined;
    switch (a.extension) {
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildAttachmentsSection() {
    return Stack(
      children: [
        if (_loadingAttachments)
          const Center(child: CircularProgressIndicator())
        else if (_attachments.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.attach_file, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("No files yet.", style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: _attachments.length,
            itemBuilder: (context, index) {
              final a = _attachments[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade200, width: 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  onTap: () => _openAttachment(a),
                  leading: Icon(_iconForAttachment(a), color: Theme.of(context).colorScheme.primary),
                  title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: a.fileSizeBytes != null ? Text(_formatFileSize(a.fileSizeBytes)) : null,
                  trailing: _canEdit
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDeleteAttachment(a),
                        )
                      : const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
                ),
              );
            },
          ),
        if (_canEdit)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _uploadingAttachment ? null : _pickAndUploadAttachment,
              icon: _uploadingAttachment
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add),
              label: Text(_uploadingAttachment ? "Uploading..." : "Add File"),
            ),
          ),
      ],
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

// ✨ UNIFIED DEEP LINK WRAPPER
class ChurchEventDeepLinkWrapper extends StatefulWidget {
  final String eventId;
  final ChurchEvent? preloadedEvent;
  
  const ChurchEventDeepLinkWrapper({
    super.key, 
    required this.eventId, 
    this.preloadedEvent
  });

  @override
  State<ChurchEventDeepLinkWrapper> createState() => _ChurchEventDeepLinkWrapperState();
}

class _ChurchEventDeepLinkWrapperState extends State<ChurchEventDeepLinkWrapper> {
  Future<ChurchEvent?>? _eventFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize the validation future only once
    _eventFuture ??= _loadAndValidateEvent();
  }

  Future<ChurchEvent?> _loadAndValidateEvent() async {
    final appState = context.read<AppState>();
    final userId = appState.profile?.id;

    // 1. Get the event (either from memory or from the network)
    ChurchEvent? targetEvent = widget.preloadedEvent;

    if (targetEvent == null) {
      final client = GraphQLProvider.of(context).value;
      final service = ChurchEventService(client, currentUserId: userId);
      targetEvent = await service.getEventById(widget.eventId);
    }

    if (targetEvent == null) return null;

    // 2. Security Check: If it's a group event, enforce membership
    if (targetEvent.groupId != null) {
      if (userId == null) {
         _triggerRedirect("You must be logged in to view this event.");
         return null;
      }
      
      // Check their role in the group using your existing GroupService
      final role = await appState.groupService.getMyGroupRole(
        groupId: targetEvent.groupId!, 
        userId: userId
      );
      
      if (role == 'none') {
         _triggerRedirect("You must be a member of this group to view its events.");
         return null; // Return null to prevent the UI from rendering the details page
      }
    }

    // 3. Validation passed! Return the event to be rendered.
    return targetEvent;
  }

  void _triggerRedirect(String message) {
    if (!mounted) return;
    
    // addPostFrameCallback ensures we don't trigger a navigation 
    // event while the widget tree is currently building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      context.go('/'); // Send them back to the home page
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChurchEvent?>(
      future: _eventFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return Scaffold(
             appBar: AppBar(
              leading: BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/calendar'); // Fallback to the Calendar tab
                  }
                },
              ),
             ), 
             body: const Center(child: CircularProgressIndicator())
           );
        }
        
        // If snapshot data is null, it means the event wasn't found OR 
        // the security check failed and they are currently being redirected.
        if (snapshot.hasError || snapshot.data == null) {
           return Scaffold(
             appBar: AppBar(
              leading: BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/calendar'); // Fallback to the Calendar tab
                  }
                },
              ),
              title: Text("key_012".tr())
             ), 
             body: Center(child: Text("key_001".tr()))
           );
        }
        
        return ChurchEventDetailsPage(event: snapshot.data!);
      },
    );
  }
}