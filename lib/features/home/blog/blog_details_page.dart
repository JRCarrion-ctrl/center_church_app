import 'package:material_ui/material_ui.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/shared/user_roles.dart';

const String qGetBlogDetails = r'''
  query GetBlogDetails($postId: uuid!, $userId: String!) {
    blog_posts_by_pk(id: $postId) {
      title
      pdf_url
    }
    blog_comments(where: {blog_post_id: {_eq: $postId}}, order_by: {created_at: asc}) {
      id
      parent_id
      content
      created_at
      edited_at
      user { display_name }
    }
    blog_likes(where: {blog_post_id: {_eq: $postId}, user_id: {_eq: $userId}}) {
      id
    }
  }
''';

const String mAddComment = r'''
  mutation AddComment($postId: uuid!, $content: String!) {
    insert_blog_comments_one(object: {blog_post_id: $postId, content: $content}) { id }
  }
''';

/// Fallback when the server has no `user_id` preset for blog comments.
const String mAddCommentWithUser = r'''
  mutation AddCommentWithUser($postId: uuid!, $content: String!, $userId: String!) {
    insert_blog_comments_one(object: {blog_post_id: $postId, content: $content, user_id: $userId}) { id }
  }
''';

/// Owner-only (Hasura lets only the owner role set parent_id, and a database
/// trigger rejects replies from anyone else).
const String mReplyComment = r'''
  mutation ReplyComment($postId: uuid!, $content: String!, $parentId: uuid!) {
    insert_blog_comments_one(object: {blog_post_id: $postId, content: $content, parent_id: $parentId}) { id }
  }
''';

const String mReplyCommentWithUser = r'''
  mutation ReplyCommentWithUser($postId: uuid!, $content: String!, $parentId: uuid!, $userId: String!) {
    insert_blog_comments_one(object: {blog_post_id: $postId, content: $content, parent_id: $parentId, user_id: $userId}) { id }
  }
''';

/// Owner-only: Hasura lets the owner role update/delete replies, and database
/// triggers reject anyone else.
const String mEditReply = r'''
  mutation EditReply($id: uuid!, $content: String!) {
    update_blog_comments_by_pk(pk_columns: {id: $id}, _set: {content: $content}) { id }
  }
''';

const String mDeleteReply = r'''
  mutation DeleteReply($id: uuid!) {
    delete_blog_comments_by_pk(id: $id) { id }
  }
''';

const String mLikePost = r'''
  mutation LikePost($postId: uuid!) {
    insert_blog_likes_one(object: {blog_post_id: $postId}) { id }
  }
''';

const String mUnlikePost = r'''
  mutation UnlikePost($postId: uuid!, $userId: String!) {
    delete_blog_likes(
      where: {
        blog_post_id: {_eq: $postId},
        user_id: {_eq: $userId}
      }
    ) {
      affected_rows
    }
  }
''';

class BlogDetailPage extends StatefulWidget {
  final String blogId;

  const BlogDetailPage({super.key, required this.blogId});

  @override
  State<BlogDetailPage> createState() => _BlogDetailPageState();
}

class _BlogDetailPageState extends State<BlogDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final FocusNode _sheetFocus = FocusNode();

  /// The top-level comment the owner is replying to, if any.
  Map<String, dynamic>? _replyingTo;

  String? _title;
  String? _pdfUrl;

  List<Map<String, dynamic>> _comments = [];
  bool _isLiked = false;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadBlogDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _sheetFocus.dispose();
    super.dispose();
  }

  Future<void> _loadBlogDetails() async {
    final appState = context.read<AppState>();
    final userId = appState.profile?.id ?? '';

    final result = await appState.client.query(QueryOptions(
      document: gql(qGetBlogDetails),
      variables: {'postId': widget.blogId, 'userId': userId},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;

    if (result.hasException) {
      debugPrint('Blog: failed to load post ${widget.blogId}: ${result.exception}');
      setState(() {
        _isLoading = false;
        _loadFailed = _title == null; // keep showing what we have on a refresh failure
      });
      return;
    }

    final postData = result.data?['blog_posts_by_pk'];
    setState(() {
      _title = postData?['title'] as String?;
      _pdfUrl = postData?['pdf_url'] as String?;
      _comments = (result.data?['blog_comments'] as List? ?? const []).cast<Map<String, dynamic>>();
      _isLiked = (result.data?['blog_likes'] as List? ?? const []).isNotEmpty;
      _isLoading = false;
      _loadFailed = false;
    });
  }

  Future<void> _toggleLike() async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final userId = appState.profile?.id ?? '';
    final currentlyLiked = _isLiked;

    setState(() => _isLiked = !_isLiked); // Optimistic update

    final result = await appState.client.mutate(MutationOptions(
      document: gql(currentlyLiked ? mUnlikePost : mLikePost),
      variables: currentlyLiked ? {'postId': widget.blogId, 'userId': userId} : {'postId': widget.blogId},
    ));

    if (result.hasException && mounted) {
      setState(() => _isLiked = currentlyLiked);
      messenger.showSnackBar(SnackBar(content: Text('blog_like_failed'.tr())));
    }
  }

  /// Returns true once the comment is saved.
  Future<bool> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return false;

    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final userId = appState.profile?.id;
    if (userId == null || userId.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('key_please_log_in'.tr())));
      return false;
    }

    final String? parentId = appState.userRole == UserRole.owner ? (_replyingTo?['id'] as String?) : null;
    final base = <String, dynamic>{
      'postId': widget.blogId,
      'content': text,
      'parentId': ?parentId,
    };

    setState(() => _sending = true);
    try {
      var result = await appState.client.mutate(MutationOptions(
        document: gql(parentId != null ? mReplyComment : mAddComment),
        variables: base,
        fetchPolicy: FetchPolicy.noCache,
      ));

      // Without a server-side preset the row has no author and the insert is
      // rejected; send the signed-in user explicitly instead.
      if (result.hasException && result.exception.toString().contains('user_id')) {
        result = await appState.client.mutate(MutationOptions(
          document: gql(parentId != null ? mReplyCommentWithUser : mAddCommentWithUser),
          variables: {...base, 'userId': userId},
          fetchPolicy: FetchPolicy.noCache,
        ));
      }

      if (result.hasException) {
        debugPrint('Blog: comment failed: ${result.exception}');
        if (mounted) messenger.showSnackBar(SnackBar(content: Text('blog_comment_failed'.tr())));
        return false;
      }

      _commentController.clear();
      if (mounted) {
        // Show it right away; the reload below fills in the server copy.
        setState(() => _replyingTo = null);
        setState(() => _comments = [
              ..._comments,
              {
                'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
                'parent_id': parentId,
                'content': text,
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'user': {'display_name': appState.profile?.displayName},
              },
            ]);
      }
      await _loadBlogDetails();
      return true;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _editReply(BuildContext sheetContext, Map<String, dynamic> reply) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: reply['content'] as String? ?? '');

    final newText = await showDialog<String>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('blog_edit_reply_title'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: 'blog_reply_hint'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('blog_cancel'.tr()),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (_, _) => FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text('blog_save'.tr()),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newText == null || newText == (reply['content'] as String? ?? '').trim()) return;

    final result = await appState.client.mutate(MutationOptions(
      document: gql(mEditReply),
      variables: {'id': reply['id'], 'content': newText},
      fetchPolicy: FetchPolicy.noCache,
    ));
    if (result.hasException) {
      debugPrint('Blog: edit reply failed: ${result.exception}');
      messenger.showSnackBar(SnackBar(content: Text('blog_edit_reply_failed'.tr())));
      return;
    }
    await _loadBlogDetails();
  }

  Future<void> _deleteReply(BuildContext sheetContext, Map<String, dynamic> reply) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('blog_delete_reply_title'.tr()),
        content: Text('blog_delete_reply_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('blog_cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('blog_delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await appState.client.mutate(MutationOptions(
      document: gql(mDeleteReply),
      variables: {'id': reply['id']},
      fetchPolicy: FetchPolicy.noCache,
    ));
    if (result.hasException || result.data?['delete_blog_comments_by_pk'] == null) {
      debugPrint('Blog: delete reply failed: ${result.exception}');
      messenger.showSnackBar(SnackBar(content: Text('blog_delete_reply_failed'.tr())));
      return;
    }
    if (mounted) setState(() => _comments = _comments.where((c) => c['id'] != reply['id']).toList());
    await _loadBlogDetails();
  }

  void _openComments() {
    final isOwner = context.read<AppState>().userRole == UserRole.owner;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Text('blog_comments_header'.tr(), style: Theme.of(sheetContext).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      Text(
                        '${_comments.length}',
                        style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                              color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _CommentList(
                    comments: _comments,
                    onReply: isOwner
                        ? (comment) {
                            setSheetState(() => _replyingTo = comment);
                            _sheetFocus.requestFocus();
                          }
                        : null,
                    onEditReply: isOwner
                        ? (reply) async {
                            await _editReply(sheetContext, reply);
                            if (sheetContext.mounted) setSheetState(() {});
                          }
                        : null,
                    onDeleteReply: isOwner
                        ? (reply) async {
                            await _deleteReply(sheetContext, reply);
                            if (sheetContext.mounted) setSheetState(() {});
                          }
                        : null,
                  ),
                ),
                _CommentComposer(
                  controller: _commentController,
                  focusNode: _sheetFocus,
                  sending: _sending,
                  replyingTo: _replyingTo,
                  onCancelReply: () => setSheetState(() => _replyingTo = null),
                  onSend: () async {
                    setSheetState(() {});
                    await _submitComment();
                    if (sheetContext.mounted) setSheetState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // A reply only makes sense next to the comment it answers.
      if (mounted) setState(() => _replyingTo = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayTitle = _title ?? 'blog_detail_title'.tr();

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_loadFailed) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 44, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('blog_load_failed'.tr(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadBlogDetails();
                },
                child: Text('blog_retry'.tr()),
              ),
            ],
          ),
        ),
      );
    } else {
      body = Column(
        children: [
          Expanded(child: _pdfUrl != null ? SfPdfViewer.network(_pdfUrl!) : const SizedBox.shrink()),
          Material(
            color: colorScheme.surface,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _openComments,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 18, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _comments.isEmpty
                                  ? 'blog_no_comments'.tr()
                                  : 'blog_view_comments'.tr(namedArgs: {'count': '${_comments.length}'}),
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_up_rounded, color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  _CommentComposer(
                    controller: _commentController,
                    focusNode: _commentFocus,
                    sending: _sending,
                    onSend: _submitComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle),
        actions: [
          IconButton(
            icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
            color: _isLiked ? colorScheme.error : null,
            tooltip: 'blog_like'.tr(),
            onPressed: (_isLoading || _loadFailed) ? null : _toggleLike,
          ),
        ],
      ),
      body: body,
    );
  }
}

String _authorName(Map<String, dynamic> comment) {
  final rawName = (comment['user']?['display_name'] as String?)?.trim() ?? '';
  return rawName.isEmpty ? 'blog_comment_someone'.tr() : rawName;
}

/// Top-level comments, each followed by the pastor's replies (indented).
/// [onReply] is only set for owners; everyone else sees no Reply button.
class _CommentList extends StatelessWidget {
  const _CommentList({required this.comments, this.onReply, this.onEditReply, this.onDeleteReply});

  final List<Map<String, dynamic>> comments;
  final void Function(Map<String, dynamic> comment)? onReply;
  final Future<void> Function(Map<String, dynamic> reply)? onEditReply;
  final Future<void> Function(Map<String, dynamic> reply)? onDeleteReply;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final topLevel = comments.where((c) => c['parent_id'] == null).toList();
    final repliesByParent = <String, List<Map<String, dynamic>>>{};
    for (final c in comments) {
      final parent = c['parent_id'] as String?;
      if (parent != null) repliesByParent.putIfAbsent(parent, () => []).add(c);
    }

    if (topLevel.isEmpty) {
      return Center(
        child: Text('blog_no_comments'.tr(), style: TextStyle(color: colorScheme.onSurfaceVariant)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: topLevel.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final comment = topLevel[index];
        final replies = repliesByParent[comment['id']] ?? const [];
        final canReply = onReply != null && !(comment['id'] as String).startsWith('local-');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentTile(comment: comment),
            if (canReply)
              Padding(
                padding: const EdgeInsets.only(left: 64),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => onReply!(comment),
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: Text('blog_reply'.tr()),
                ),
              ),
            for (final reply in replies)
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: _CommentTile(
                  comment: reply,
                  isPastorReply: true,
                  // Optimistic local copies have no server id yet.
                  onEdit: (reply['id'] as String).startsWith('local-') || onEditReply == null
                      ? null
                      : () => onEditReply!(reply),
                  onDelete: (reply['id'] as String).startsWith('local-') || onDeleteReply == null
                      ? null
                      : () => onDeleteReply!(reply),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, this.isPastorReply = false, this.onEdit, this.onDelete});

  final Map<String, dynamic> comment;
  final bool isPastorReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toLanguageTag();
    final authorName = _authorName(comment);
    final created = DateTime.tryParse(comment['created_at'] as String? ?? '')?.toLocal();
    final edited = comment['edited_at'] != null;
    final hasMenu = onEdit != null || onDelete != null;

    return ListTile(
      trailing: hasMenu
          ? PopupMenuButton<String>(
              tooltip: 'blog_reply_options'.tr(),
              icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurfaceVariant),
              onSelected: (value) => value == 'edit' ? onEdit?.call() : onDelete?.call(),
              itemBuilder: (_) => [
                if (onEdit != null)
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_outlined),
                      title: Text('blog_edit'.tr()),
                    ),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline, color: colorScheme.error),
                      title: Text('blog_delete'.tr(), style: TextStyle(color: colorScheme.error)),
                    ),
                  ),
              ],
            )
          : null,
      leading: CircleAvatar(
        radius: isPastorReply ? 16 : 20,
        backgroundColor: isPastorReply ? colorScheme.secondaryContainer : colorScheme.primaryContainer,
        foregroundColor: isPastorReply ? colorScheme.onSecondaryContainer : colorScheme.onPrimaryContainer,
        child: Text(authorName.characters.first.toUpperCase()),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              authorName,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (isPastorReply) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'blog_pastor_badge'.tr(),
                style: textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer),
              ),
            ),
          ],
          if (created != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                DateFormat.MMMd(locale).add_jm().format(created) + (edited ? ' · ${'blog_edited'.tr()}' : ''),
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          comment['content'] as String? ?? '',
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface, height: 1.35),
        ),
      ),
    );
  }
}

/// Text box + send button. Enter sends; the send button is disabled while
/// the box is empty or a comment is on its way. When [replyingTo] is set a
/// "Replying to ..." bar with a cancel button sits above the box.
class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    this.focusNode,
    this.replyingTo,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool sending;
  final Future<void> Function() onSend;
  final Map<String, dynamic>? replyingTo;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: controller, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canSend = !sending && controller.text.trim().isNotEmpty;
    final replying = replyingTo != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replying)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.reply_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'blog_replying_to'.tr(namedArgs: {'name': _authorName(replyingTo!)}),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'blog_cancel_reply'.tr(),
                    onPressed: onCancelReply,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => canSend ? onSend() : null,
                  decoration: InputDecoration(
                    hintText: (replying ? 'blog_reply_hint' : 'blog_add_comment_hint').tr(),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: (replying ? 'blog_send_reply' : 'blog_send_comment').tr(),
                onPressed: canSend ? onSend : null,
                icon: sending
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
