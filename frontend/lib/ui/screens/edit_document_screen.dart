import 'package:flutter/material.dart';
import 'package:doc_scanner/core/theme.dart';
import 'package:doc_scanner/services/scanner_service.dart';
import 'package:doc_scanner/core/constants.dart';

class EditDocumentScreen extends StatefulWidget {
  final Map<String, dynamic> document;
  final String initialImageUrl;

  const EditDocumentScreen({
    super.key,
    required this.document,
    required this.initialImageUrl,
  });

  @override
  State<EditDocumentScreen> createState() => _EditDocumentScreenState();
}

class _EditDocumentScreenState extends State<EditDocumentScreen> {
  bool _isProcessing = false;
  String _selectedFilter = 'original';
  String _selectedDocumentType = 'typed';
  String? _currentImageUrl;
  bool _hasUnsavedChanges = false;
  final _scannerService = ScannerService();

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.initialImageUrl;
    _selectedDocumentType = widget.document['document_type'] ?? 'typed';
  }

  void _applyFilter(String filter) async {
    if (filter == _selectedFilter) return;

    setState(() {
      _selectedFilter = filter;
      _isProcessing = true;
    });

    // If user picks "original", just restore the initial image — no network call needed
    if (filter == 'original') {
      setState(() {
        _currentImageUrl = widget.initialImageUrl;
        _isProcessing = false;
        _hasUnsavedChanges = false;
      });
      return;
    }

    try {
      final result = await _scannerService.enhanceImage(
        widget.document['id'],
        filter,
        documentType: _selectedDocumentType,
      );

      // Append a cache-busting timestamp so Flutter doesn't serve the old cached image
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _currentImageUrl = '${AppConstants.baseUrl.replaceAll("/api/v1", "")}${result['url']}?t=$timestamp';
        _isProcessing = false;
        _hasUnsavedChanges = true;
      });
    } catch (e) {
      debugPrint("Enhancement error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Processing failed: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Discard Changes?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You have applied filters. Do you want to save them before leaving?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Yes, discard (just leave)
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              _saveAndClose();
            },
            child: const Text('Save & Exit', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  void _saveAndClose() {
    // The backend already saved the filtered image in the DB during enhanceImage.
    // We just need to pop and return true so the previous screen refreshes.
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Changes saved successfully"), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text("Edit Document"),
          actions: [
            if (_hasUnsavedChanges)
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                tooltip: 'Save Changes',
                onPressed: _saveAndClose,
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
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Image.network(
                        _currentImageUrl!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.red, size: 50),
                        ),
                      ),
                      if (_isProcessing)
                        Container(
                          color: Colors.black45,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Document Type Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Optimize for:',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDocumentTypeItem('typed', 'Document', Icons.description),
                      const SizedBox(width: 8),
                      _buildDocumentTypeItem('receipt', 'Receipt', Icons.receipt), // Using receipt mapping
                      const SizedBox(width: 8),
                      _buildDocumentTypeItem('handwritten', 'Notes', Icons.edit),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Filter Bar
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterItem('original', 'Original', Icons.image_outlined),
                  _buildFilterItem('magic', 'Magic Color', Icons.auto_fix_high),
                  _buildFilterItem('bw', 'B&W (CamScanner)', Icons.contrast),
                  _buildFilterItem('grayscale', 'Grayscale', Icons.gradient),
                  _buildFilterItem('receipt', 'Thermal Receipt', Icons.receipt_long),
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
        width: 85,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.white24 : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
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
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDocumentType = id;
          });
          // Re-apply filter if a filter is selected
          if (_selectedFilter != 'original') {
            _applyFilter(_selectedFilter);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.white10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? AppTheme.primaryColor : Colors.white70),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? AppTheme.primaryColor : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
