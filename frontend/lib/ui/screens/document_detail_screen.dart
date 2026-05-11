import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:doc_scanner/core/theme.dart';
import 'package:doc_scanner/services/document_service.dart';
import 'package:doc_scanner/services/scanner_service.dart';
import 'package:doc_scanner/ui/screens/edit_document_screen.dart';
import 'package:doc_scanner/ui/screens/ocr_result_screen.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DocumentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> document;
  final String imageUrl;

  const DocumentDetailScreen({
    super.key,
    required this.document,
    required this.imageUrl,
  });

  bool get _isPdf =>
      (document['mime_type'] ?? '').toString().contains('pdf') ||
      (document['filename'] ?? '').toString().endsWith('.pdf');

  Future<void> _deleteDocument(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text("Delete Document", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this document?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DocumentService().deleteDocument(document['id']);
        if (context.mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Document deleted")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _extractText(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final result = await ScannerService().extractText(document['id']);
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OcrResultScreen(
              text: result['text'] ?? '',
              filename: document['filename'] ?? 'Document',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to extract text: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openPdf(BuildContext context) async {
    // Download the PDF to a temp file and open with system viewer
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final filename = document['filename'] ?? 'batch.pdf';
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);
        
        if (context.mounted) Navigator.pop(context); // close loading
        
        await OpenFilex.open(file.path);
      } else {
        throw Exception('Failed to download PDF');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to open PDF: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(document['filename'] ?? 'Document'),
        actions: [
          if (!_isPdf)
            IconButton(
              icon: const Icon(Icons.text_fields, color: Colors.white),
              tooltip: 'Extract Text',
              onPressed: () => _extractText(context),
            ),
          if (!_isPdf)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit Image',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditDocumentScreen(
                      document: document,
                      initialImageUrl: imageUrl,
                    ),
                  ),
                );
                if (result == true) {
                  if (context.mounted) Navigator.pop(context, true);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _deleteDocument(context),
          ),
        ],
      ),
      body: _isPdf ? _buildPdfView(context) : _buildImageView(),
    );
  }

  Widget _buildImageView() {
    return Center(
      child: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white24, size: 100),
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }

  Widget _buildPdfView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 100),
          const SizedBox(height: 24),
          Text(
            document['filename'] ?? 'PDF Document',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "PDF Document",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _openPdf(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text("Open PDF"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
