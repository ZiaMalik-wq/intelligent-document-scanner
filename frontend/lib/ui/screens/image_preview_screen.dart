import 'dart:io';
import 'package:flutter/material.dart';
import 'package:doc_scanner/core/theme.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:doc_scanner/services/document_service.dart';
import 'package:doc_scanner/services/scanner_service.dart';
import 'package:doc_scanner/core/constants.dart';

class ImagePreviewScreen extends StatefulWidget {
  final String imagePath;
  final bool enableAutoCrop;
  final bool returnCroppedPath;

  const ImagePreviewScreen({
    super.key,
    required this.imagePath,
    this.enableAutoCrop = false,
    this.returnCroppedPath = false,
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  String? _processedImagePath;
  String?
  _originalImagePath; // Track the original uncropped image (from camera or initial upload)
  bool _isProcessing = false;
  String _selectedFilter = 'original';
  String _selectedDocumentType = 'typed';
  bool _hasUnsavedChanges = false; // Track if filters/edits have been applied

  final _documentService = DocumentService();
  final _scannerService = ScannerService();
  int? _documentId;
  int? _parentDocumentId; // Track parent for cropped images
  String? _remoteUrl;
  bool _isRemote = false;

  @override
  void initState() {
    super.initState();
    _processedImagePath = widget.imagePath;
    _originalImagePath = widget.imagePath; // Store original for reference
  }



  void _applyFilter(String filter) async {
    if (filter == 'original') {
      setState(() {
        _selectedFilter = filter;
        _isRemote = false;
        _hasUnsavedChanges = false; // Reset when back to original
      });
      return;
    }

    setState(() {
      _selectedFilter = filter;
      _isProcessing = true;
    });

    try {
      // 1. Upload if not already uploaded
      if (_documentId == null) {
        final doc = await _documentService.uploadDocument(
          File(_processedImagePath!),
          parentDocumentId:
              _parentDocumentId, // Pass parent for lineage tracking
        );
        _documentId = doc['id'];
      }

      // 2. Enhance with document type
      final result = await _scannerService.enhanceImage(
        _documentId!,
        filter,
        documentType: _selectedDocumentType,
      );

      setState(() {
        _remoteUrl = result['url'];
        _isRemote = true;
        _isProcessing = false;
        _hasUnsavedChanges = true; // Mark that filter has been applied
      });
    } catch (e) {
      debugPrint("Enhancement error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Processing failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }



  Future<void> _cropImage() async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _processedImagePath!,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Document',
          toolbarColor: AppTheme.surfaceColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          activeControlsWidgetColor: AppTheme.primaryColor,
        ),
        IOSUiSettings(title: 'Crop Document'),
      ],
    );

    if (croppedFile != null) {
      // If in batch mode (returnCroppedPath), just pop with the cropped file path
      if (widget.returnCroppedPath) {
        if (mounted) {
          Navigator.pop(context, croppedFile.path);
        }
        return;
      }

      // In manual crop mode, we don't upload the original image to establish lineage anymore.
      // This prevents the "double image" problem where both original and cropped appear in gallery.
      // We just update the local path and only upload the final result when saving/filtering.
      setState(() {
        _processedImagePath = croppedFile.path;
        _documentId = null; // Reset ID because file changed
        _isRemote = false;
        _selectedFilter = 'original';
        _isProcessing = false;
        _hasUnsavedChanges = true; // Mark as changed so 'Save' button shows
      });
    }
  }

  Future<bool?> _showDiscardDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved filter changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndClose() async {
    setState(() => _isProcessing = true);

    try {
      // 1. If not yet uploaded (no filters applied, just raw photo or crop), upload now
      if (_documentId == null) {
        final doc = await _documentService.uploadDocument(
          File(_processedImagePath!),
        );
        _documentId = doc['id'];
      }

      // 2. Mark as completed (optional: could call a 'complete' endpoint if needed, 
      // but uploading and processing is enough for it to show up in gallery)
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _hasUnsavedChanges = false;
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: const Text('Document Saved!', style: TextStyle(color: Colors.white)),
              content: const Text(
                'Your document has been processed and saved successfully.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).popUntil((route) => route.isFirst); // Go to Home
                  },
                  child: const Text('Go Home', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to Camera
                  },
                  child: const Text('Scan Another', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      debugPrint("Save error: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await _showDiscardDialog();
        if (shouldDiscard == true && context.mounted) {
          // Cleanup: Delete any documents created during this session if discarding
          if (_documentId != null) {
            _documentService.deleteDocument(_documentId!).catchError((e) => debugPrint("Discard cleanup error: $e"));
          }
          if (_parentDocumentId != null && _parentDocumentId != _documentId) {
            _documentService.deleteDocument(_parentDocumentId!).catchError((e) => debugPrint("Parent discard cleanup error: $e"));
          }
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text("Preview"),
          actions: [
            IconButton(
              icon: const Icon(Icons.crop_rotate, color: Colors.white),
              onPressed: _cropImage,
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: 'Save Changes',
              onPressed: _isProcessing ? null : _saveAndClose,
            ),
          ],
        ),
        body: Column(
          children: [
            // 1. Image Display
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      _isRemote
                          ? Image.network(
                              '${AppConstants.baseUrl.replaceAll("/api/v1", "")}$_remoteUrl',
                              fit: BoxFit.contain,
                              width: double.infinity,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint("Network Image Error: $error");
                                return Image.file(
                                  File(_processedImagePath!),
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                );
                              },
                            )
                          : Image.file(
                              File(_processedImagePath!),
                              fit: BoxFit.contain,
                              width: double.infinity,
                            ),
                      if (_isProcessing)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Document Type Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Document Type',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildDocumentTypeItem(
                          'typed',
                          'Typed',
                          Icons.description,
                        ),
                        const SizedBox(width: 8),
                        _buildDocumentTypeItem(
                          'handwritten',
                          'Handwritten',
                          Icons.edit,
                        ),
                        const SizedBox(width: 8),
                        _buildDocumentTypeItem('other', 'Other', Icons.layers),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Filter Bar
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterItem(
                    'original',
                    'Original',
                    Icons.image_outlined,
                  ),
                  _buildFilterItem('magic', 'Magic', Icons.auto_fix_high),
                  _buildFilterItem('bw', 'B&W', Icons.contrast),
                  _buildFilterItem('grayscale', 'Grayscale', Icons.gradient),
                  _buildFilterItem('receipt', 'Receipt', Icons.receipt_long),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterItem(String id, String label, IconData icon) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () => _applyFilter(id),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white24 : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white70),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTypeItem(String id, String label, IconData icon) {
    final isSelected = _selectedDocumentType == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDocumentType = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white24 : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
