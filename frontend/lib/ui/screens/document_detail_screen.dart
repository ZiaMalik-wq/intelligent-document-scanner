import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:doc_scanner/core/theme.dart';
import 'package:doc_scanner/services/document_service.dart';
import 'package:doc_scanner/services/scanner_service.dart';
import 'package:doc_scanner/ui/screens/edit_document_screen.dart';
import 'package:doc_scanner/ui/screens/ocr_result_screen.dart';

class DocumentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> document;
  final String imageUrl;

  const DocumentDetailScreen({
    super.key,
    required this.document,
    required this.imageUrl,
  });

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
          Navigator.pop(context, true); // Return true to indicate deletion
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
    // Show loading dialog
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
        Navigator.pop(context); // Close loading dialog
        
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
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to extract text: $e"),
            backgroundColor: Colors.red,
          ),
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
        title: Text(document['filename']),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields, color: Colors.white),
            tooltip: 'Extract Text',
            onPressed: () => _extractText(context),
          ),
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
              // If edited, pop to home screen to refresh
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
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white24, size: 100),
          ),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        ),
      ),
    );
  }
}
