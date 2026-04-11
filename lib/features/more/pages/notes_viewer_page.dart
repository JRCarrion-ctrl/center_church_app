import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:logger/logger.dart';
import 'package:easy_localization/easy_localization.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class NotesViewerPage extends StatefulWidget {
  final String url;

  const NotesViewerPage({super.key, required this.url});

  @override
  State<NotesViewerPage> createState() => _NotesViewerPageState();
}

class _NotesViewerPageState extends State<NotesViewerPage> {
  File? _localFile;
  bool _loading = true;
  String? _error;
  late final WebViewController _webViewController;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    
    // FIX 2: Use encodeComponent to safely pass query parameters to Google Docs
    final gviewUrl = 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.url)}';
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(gviewUrl));

    if (kIsWeb) {
      setState(() => _loading = false);
    } else {
      _downloadFile();
    }
  }

  Future<void> _downloadFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      
      // FIX 1: Safely parse the filename ignoring query parameters
      final uri = Uri.parse(widget.url);
      final filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'document';
      final filePath = '${dir.path}/$filename';
      final file = File(filePath);

      // FIX 3: Ensure the cached file actually has data to prevent gray screens from corrupt caches
      if (await file.exists() && await file.length() > 0) {
        _logger.i('Using cached file: ${file.path} (size: ${await file.length()} bytes)');
        if (mounted) setState(() { _localFile = file; _loading = false; });
        return;
      }

      final response = await Dio().get<List<int>>(
        widget.url,
        options: Options(
          responseType: ResponseType.bytes,
          // Ensure we only process successful downloads
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );

      final savedFile = await file.writeAsBytes(response.data!, flush: true);
      _logger.i('Downloaded: ${savedFile.path} (size: ${await savedFile.length()} bytes)');
      
      if (mounted) setState(() { _localFile = savedFile; _loading = false; });
    } catch (e) {
      _logger.e('File download failed: $e');
      if (mounted) setState(() { _loading = false; _error = 'Failed to load file'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX 1: Safely parse the filename for UI logic
    final uri = Uri.parse(widget.url);
    final filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.toLowerCase() : '';
    final isPdf  = filename.endsWith('.pdf');
    final isDocx = filename.endsWith('.docx');

    return Scaffold(
      appBar: AppBar(title: Text("key_291".tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : isPdf
                  ? (_localFile != null
                      ? SfPdfViewer.file(
                          _localFile!,
                          // Helpful to catch future rendering issues
                          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                            _logger.e('PDF Load Failed: ${details.error}');
                          },
                        )
                      : SfPdfViewer.network(widget.url))
                  : isDocx
                      ? WebViewWidget(controller: _webViewController)
                      : Center(child: Text("key_292".tr(args: [filename]))),
    );
  }
}