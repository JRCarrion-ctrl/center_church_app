// filename: lib/features/calendar/models/church_event_attachment.dart

class ChurchEventAttachment {
  final String id;
  final String eventId;
  final String fileName;
  final String fileUrl;
  final String contentType;
  final int? fileSizeBytes;
  final String? uploadedByUserId;
  final DateTime createdAt;

  ChurchEventAttachment({
    required this.id,
    required this.eventId,
    required this.fileName,
    required this.fileUrl,
    required this.contentType,
    this.fileSizeBytes,
    this.uploadedByUserId,
    required this.createdAt,
  });

  factory ChurchEventAttachment.fromJson(Map<String, dynamic> json) {
    return ChurchEventAttachment(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      fileName: json['file_name'] as String? ?? 'file',
      fileUrl: json['file_url'] as String,
      contentType: json['content_type'] as String? ?? 'application/octet-stream',
      fileSizeBytes: json['file_size_bytes'] as int?,
      uploadedByUserId: json['uploaded_by'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Best-effort file extension, lowercased, no leading dot. e.g. "pdf"
  String get extension {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf' || extension == 'pdf';
}