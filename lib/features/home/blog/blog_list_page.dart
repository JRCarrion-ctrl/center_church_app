import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:ccf_app/app_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ccf_app/features/home/blog/blog_upload_service.dart';

const String qGetBlogs = r'''
  query GetBlogs {
    blog_posts(order_by: {created_at: desc}) {
      id
      title
      pdf_url
      created_at
      author {
        display_name
      }
      comments_aggregate {
        aggregate { count }
      }
      likes_aggregate {
        aggregate { count }
      }
    }
  }
''';

const String mInsertBlog = r'''
  mutation InsertBlog($title: String!, $pdfUrl: String!) {
    insert_blog_posts_one(object: {title: $title, pdf_url: $pdfUrl}) {
      id
    }
  }
''';

class BlogListPage extends StatefulWidget {
  const BlogListPage({super.key});

  @override
  State<BlogListPage> createState() => _BlogListPageState();
}

class _BlogListPageState extends State<BlogListPage> {
  late Future<List<dynamic>> _blogsFuture;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _blogsFuture = _fetchBlogs();
  }

  Future<void> _handleUpload() async {
    // 1. Pick the PDF file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // Required to get the bytes
    );

    if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
      return; // User canceled the picker
    }

    final file = result.files.first;
    
    // Prompt the user for a title
    final titleController = TextEditingController(text: file.name.replaceAll('.pdf', ''));
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blog Title'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: 'Enter the title for this post'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, titleController.text),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      final appState = context.read<AppState>();
      
      // 2. Upload to S3 using your service
      final uploadService = BlogUploadService(appState.client);
      final uniqueFilename = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final finalUrl = await uploadService.uploadBlogPdf(
        file.bytes!, 
        uniqueFilename, 
        'application/pdf'
      );

      // 3. Save to Hasura database
      final mutationResult = await appState.client.mutate(MutationOptions(
        document: gql(mInsertBlog),
        variables: {
          'title': title,
          'pdfUrl': finalUrl,
        },
      ));

      if (mutationResult.hasException) {
        throw mutationResult.exception!;
      }

      // 4. Refresh the feed
      setState(() {
        _blogsFuture = _fetchBlogs();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blog uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<List<dynamic>> _fetchBlogs() async {
    final client = context.read<AppState>().client;
    final result = await client.query(QueryOptions(
      document: gql(qGetBlogs),
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (result.hasException) throw result.exception!;
    return result.data?['blog_posts'] as List<dynamic>? ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isOwner = appState.role == 'owner';

    return Scaffold(
      appBar: AppBar(title: Text("blog_list_title".tr())),
      floatingActionButton: isOwner
          ? FloatingActionButton(
              onPressed: _isUploading ? null : _handleUpload,
              child: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.upload_file),
            )
          : null,
      body: FutureBuilder<List<dynamic>>(
        future: _blogsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading blogs: ${snapshot.error}'));
          }

          final blogs = snapshot.data!;
          if (blogs.isEmpty) {
            return const Center(child: Text('No blog posts available.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: blogs.length,
            itemBuilder: (context, index) {
              final blog = blogs[index];
              
              // Extract the name, falling back to a default if missing
              final String authorName = blog['author']?['display_name'] ?? 'Pastor';
              
              final date = DateFormat.yMMMMd().format(DateTime.parse(blog['created_at']));
              final comments = blog['comments_aggregate']['aggregate']['count'].toString();
              final likes = blog['likes_aggregate']['aggregate']['count'].toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  title: Text(blog['title']),
                  subtitle: Text(
                    "blog_metrics_subtitle".tr(namedArgs: {
                      'name': authorName, // Pass the new name variable
                      'date': date,
                      'comments': comments,
                      'likes': likes,
                    }),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    context.pushNamed(
                      'blog_detail',
                      pathParameters: {'id': blog['id']},
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}