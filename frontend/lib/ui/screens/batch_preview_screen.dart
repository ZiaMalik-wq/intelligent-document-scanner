import 'dart:io';
import 'package:flutter/material.dart';
import 'package:doc_scanner/core/theme.dart';
import 'package:doc_scanner/services/document_service.dart';
import 'package:doc_scanner/core/constants.dart';
import 'package:doc_scanner/services/scanner_service.dart';
import 'package:doc_scanner/ui/screens/image_preview_screen.dart';

class BatchPreviewScreen extends StatefulWidget {
  final List<String> imagePaths;

  const BatchPreviewScreen({
    super.key,
    required this.imagePaths,
  });

  @override
  State<BatchPreviewScreen> createState() => _BatchPreviewScreenState();
}

class _BatchPreviewScreenState extends State<BatchPreviewScreen> {
  String _selectedFilter = 'original';
  bool _isProcessing = false;
  String _progressText = '';
  int _currentPage = 0;
  late List<String> _pages;
  late PageController _pageController;
  final _scannerService = ScannerService();
  final _documentService = DocumentService();

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.imagePaths);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _removePage(int index) {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot remove the last page"), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() {
      _pages.removeAt(index);
      if (_currentPage >= _pages.length) {
        _currentPage = _pages.length - 1;
      }
    });
  }

  /// Opens the ImagePreviewScreen for the given page so the user can crop it.
  /// The cropped image path replaces the original path in the list.
  Future<void> _cropPage(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(
          imagePath: _pages[index],
          enableAutoCrop: true,
          returnCroppedPath: true, // We'll add this flag
        ),
      ),
    );
    // If ImagePreviewScreen returns a path, use it
    if (result != null && result is String) {
      setState(() {
        _pages[index] = result;
      });
    }
  }

  Future<void> _processBatch() async {
    setState(() {
      _isProcessing = true;
      _progressText = 'Starting batch process...';
    });

    try {
      List<int> documentIds = [];

      for (int i = 0; i < _pages.length; i++) {
        // Upload
        setState(() {
          _progressText = 'Uploading page ${i + 1} of ${_pages.length}...';
        });

        final doc = await _documentService.uploadDocument(File(_pages[i]));
        final docId = doc['id'];

        // Apply filter if not original
        if (_selectedFilter != 'original') {
          setState(() {
            _progressText = 'Applying ${_getFilterLabel(_selectedFilter)} to page ${i + 1}...';
          });
          await _scannerService.enhanceImage(docId, _selectedFilter, documentType: "typed");
        }

        documentIds.add(docId);
      }

      // Generate PDF
      setState(() {
        _progressText = 'Generating multi-page PDF...';
      });

      final pdfResult = await _documentService.generateBatchPdf(documentIds);

      if (mounted) {
        setState(() => _isProcessing = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF saved: ${pdfResult['filename']}"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Batch error: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getFilterLabel(String id) {
    switch (id) {
      case 'magic': return 'Magic Color';
      case 'bw': return 'B&W';
      case 'grayscale': return 'Grayscale';
      default: return 'Original';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text("${_pages.length} Pages"),
        actions: [
          if (!_isProcessing)
            TextButton.icon(
              onPressed: _processBatch,
              icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
              label: const Text("Save PDF", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isProcessing ? _buildProgressOverlay() : _buildContent(),
    );
  }

  Widget _buildProgressOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            _progressText,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Page counter
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "Page ${_currentPage + 1} of ${_pages.length}",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),

        // Page viewer
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_pages[index]),
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    // Top-right: Delete page button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black87,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                          padding: EdgeInsets.zero,
                          onPressed: () => _removePage(index),
                        ),
                      ),
                    ),
                    // Top-left: Crop page button
                    Positioned(
                      top: 8,
                      left: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black87,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(Icons.crop, size: 18, color: Colors.white),
                          padding: EdgeInsets.zero,
                          onPressed: () => _cropPage(index),
                        ),
                      ),
                    ),
                    // Page number badge
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Page ${index + 1}",
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Page dots indicator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => Container(
                width: _currentPage == index ? 10 : 6,
                height: _currentPage == index ? 10 : 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index ? AppTheme.primaryColor : Colors.white30,
                ),
              ),
            ),
          ),
        ),

        // Filter bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Filter: ",
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _getFilterLabel(_selectedFilter),
                    style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "  (applied on export)",
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('original', 'Original', Icons.image_outlined),
                    _buildFilterChip('magic', 'Magic Color', Icons.auto_fix_high),
                    _buildFilterChip('bw', 'B&W', Icons.contrast),
                    _buildFilterChip('grayscale', 'Grayscale', Icons.gradient),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String id, String label, IconData icon) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = id),
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white24 : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
