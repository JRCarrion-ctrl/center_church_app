import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:logger/logger.dart';
import 'package:easy_localization/easy_localization.dart';

// Mobile-only imports, guarded at call sites
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
  File? _localFile;    // always null on web
  bool _loading = true;
  String? _error;
  late final WebViewController _webViewController;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(
          'https://docs.google.com/gview?embedded=true&url=${Uri.encodeFull(widget.url)}'));

    if (kIsWeb) {
      // No file system on web — network viewers handle everything
      setState(() => _loading = false);
    } else {
      _downloadFile();
    }
  }

  Future<void> _downloadFile() async {
    try {
      final dir      = await getApplicationDocumentsDirectory();
      final filename = widget.url.split('/').last;
      final filePath = '${dir.path}/$filename';
      final file     = File(filePath);

      if (await file.exists()) {
        _logger.i('Using cached file: ${file.path} (size: ${await file.length()} bytes)');
        setState(() { _localFile = file; _loading = false; });
        return;
      }

      final response = await Dio().get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );

      final savedFile = await file.writeAsBytes(response.data!, flush: true);
      _logger.i('Downloaded: ${savedFile.path} (size: ${await savedFile.length()} bytes)');
      setState(() { _localFile = savedFile; _loading = false; });
    } catch (e) {
      _logger.e('File download failed: $e');
      setState(() { _loading = false; _error = 'Failed to load file'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = widget.url.split('/').last.toLowerCase();
    final isPdf  = filename.endsWith('.pdf');
    final isDocx = filename.endsWith('.docx');

    return Scaffold(
      appBar: AppBar(title: Text("key_291".tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : isPdf
                  // Mobile: prefer local file; web/uncached: network
                  ? (_localFile != null
                      ? SfPdfViewer.file(_localFile!)
                      : SfPdfViewer.network(widget.url))
                  : isDocx
                      ? WebViewWidget(controller: _webViewController)
                      : Center(child: Text("key_292".tr(args: [filename]))),
    );
  }
}