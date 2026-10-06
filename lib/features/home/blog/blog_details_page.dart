import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ccf_app/app_state.dart';

const String qGetBlogDetails = r'''
  query GetBlogDetails($postId: uuid!, $userId: String!) {
    blog_posts_by_pk(id: $postId) {
      title
      pdf_url
    }
    blog_comments(where: {blog_post_id: {_eq: $postId}}, order_by: {created_at: asc}) {
      id
      content
      created_at
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
  final String blogId; // Now the ONLY required parameter

  const BlogDetailPage({super.key, required this.blogId});

  @override
  State<BlogDetailPage> createState() => _BlogDetailPageState();
}

class _BlogDetailPageState extends State<BlogDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  
  // State variables for the post data
  String? _title;
  String? _pdfUrl;
  
  List<dynamic> _comments = [];
  bool _isLiked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlogDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
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

    if (!result.hasException && mounted) {
      final postData = result.data?['blog_posts_by_pk'];
      
      setState(() {
        _title = postData?['title'];
        _pdfUrl = postData?['pdf_url'];
        _comments = result.data?['blog_comments'] ?? [];
        _isLiked = (result.data?['blog_likes'] as List).isNotEmpty;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final appState = context.read<AppState>();
    final client = appState.client;
    final userId = appState.profile?.id ?? '';
    
    final currentlyLiked = _isLiked;
    
    setState(() => _isLiked = !_isLiked); // Optimistic update

    final mutation = currentlyLiked ? mUnlikePost : mLikePost;
    
    // Pass the userId only for the unlike mutation
    final variables = currentlyLiked 
        ? {'postId': widget.blogId, 'userId': userId}
        : {'postId': widget.blogId};

    final result = await client.mutate(MutationOptions(
      document: gql(mutation),
      variables: variables,
    ));

    if (result.hasException && mounted) {
      setState(() => _isLiked = currentlyLiked); // Revert on failure
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update like status')),
      );
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    final client = context.read<AppState>().client;

    final result = await client.mutate(MutationOptions(
      document: gql(mAddComment),
      variables: {'postId': widget.blogId, 'content': text},
    ));

    if (!result.hasException) {
      _commentController.clear();
      _loadBlogDetails(); // Refresh comments list
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a blank or generic AppBar until the title loads
    final displayTitle = _title ?? "blog_detail_title".tr();

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle),
        actions: [
          IconButton(
            icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
            color: _isLiked ? Colors.red : null,
            onPressed: _isLoading ? null : _toggleLike,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              // PDF only renders once _pdfUrl is fetched
              if (_pdfUrl != null)
                SfPdfViewer.network(_pdfUrl!),
              
              DraggableScrollableSheet(
                initialChildSize: 0.1,
                minChildSize: 0.1,
                maxChildSize: 0.8,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          height: 4,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "blog_comments_header".tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              final authorName = comment['user']['display_name'] ?? 'User';
                              
                              return ListTile(
                                leading: CircleAvatar(child: Text(authorName[0].toUpperCase())),
                                title: Text(authorName),
                                subtitle: Text(comment['content']),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: 8.0, 
                            right: 8.0, 
                            top: 8.0, 
                            bottom: MediaQuery.of(context).viewInsets.bottom + 16.0
                          ),
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: "blog_add_comment_hint".tr(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _submitComment,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
    );
  }
}