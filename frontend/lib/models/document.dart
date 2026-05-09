class DocumentModel {
  final int id;
  final String filename;
  final String? mimeType;
  final String originalPath;
  final String? processedPath;
  final String? ocrText;
  final String status;
  final DateTime createdAt;

  DocumentModel({
    required this.id,
    required this.filename,
    this.mimeType,
    required this.originalPath,
    this.processedPath,
    this.ocrText,
    required this.status,
    required this.createdAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      filename: json['filename'],
      mimeType: json['mime_type'],
      originalPath: json['original_path'],
      processedPath: json['processed_path'],
      ocrText: json['ocr_text'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
