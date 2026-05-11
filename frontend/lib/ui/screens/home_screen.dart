import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doc_scanner/providers/auth_provider.dart';
import 'package:doc_scanner/ui/screens/camera_screen.dart';
import 'package:doc_scanner/ui/screens/document_detail_screen.dart';
import 'package:doc_scanner/services/document_service.dart';
import 'package:doc_scanner/core/theme.dart';
import 'package:doc_scanner/core/constants.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _documentService = DocumentService();
  List<dynamic> _documents = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _documentService.getDocuments();
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDocument(int id) async {
    try {
      await _documentService.deleteDocument(id);
      _fetchDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document deleted")),
        );
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _exportBatchPdf() async {
    if (_selectedIds.isEmpty) return;

    // Ask user if they want to keep or delete originals
    final bool? deleteSource = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Export PDF', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Do you want to delete the original source documents after generating the PDF?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Keep originals
              child: const Text('Keep Originals', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Delete originals
              child: const Text('Delete Originals', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (deleteSource == null) return; // User cancelled

    if (!mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final documentIds = _documents
          .where((doc) => _selectedIds.contains(doc['id']))
          .map<int>((doc) => doc['id'])
          .toList();

      final result = await _documentService.generateBatchPdf(
        documentIds,
        deleteSource: deleteSource,
      );
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF Generated: ${result['filename']}"),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
        _fetchDocuments(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _isPdfDoc(dynamic doc) {
    final mimeType = (doc['mime_type'] ?? '').toString();
    final filename = (doc['filename'] ?? '').toString();
    return mimeType.contains('pdf') || filename.endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text("${_selectedIds.length} Selected")
            : const Text("My Documents"),
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => auth.logout(),
            ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportBatchPdf,
              tooltip: "Export as PDF",
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDocuments,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
            ? _buildEmptyState(auth)
            : _buildDocumentGrid(),
      ),
      floatingActionButton: _isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: _exportBatchPdf,
              label: const Text("Export PDF"),
              icon: const Icon(Icons.picture_as_pdf),
              backgroundColor: AppTheme.primaryColor,
            )
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                );
                _fetchDocuments(); // Refresh when coming back
              },
              label: const Text("Scan"),
              icon: const Icon(Icons.camera_alt),
            ),
    );
  }

  Widget _buildEmptyState(AuthProvider auth) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.document_scanner_rounded, size: 64, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 32),
          Text(
            "Welcome, ${auth.user?.name?.split(' ')[0] ?? 'User'}!",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            "You haven't scanned any documents yet.\nTap the camera to get started.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentGrid() {
    return AnimationLimiter(
      child: MasonryGridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          final doc = _documents[index];
          final date = DateTime.parse(doc['created_at']);
          final formattedDate = DateFormat.yMMMd().format(date);
          final imageUrl = '${AppConstants.baseUrl.replaceAll("/api/v1", "")}${doc['url']}';

          final isSelected = _selectedIds.contains(doc['id']);

          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: GestureDetector(
          onLongPress: () {
            setState(() {
              _isSelectionMode = true;
              _selectedIds.add(doc['id']);
            });
          },
          onTap: () async {
            if (_isSelectionMode) {
              _toggleSelection(doc['id']);
            } else {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentDetailScreen(
                    document: doc,
                    imageUrl: imageUrl,
                  ),
                ),
              );
              if (result == true) _fetchDocuments();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.3) : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.white10,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: _isPdfDoc(doc)
                            ? Container(
                                color: AppTheme.surfaceColor,
                                child: const Center(
                                  child: Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 48),
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, color: Colors.white24),
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc['filename'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_isSelectionMode)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppTheme.surfaceColor,
                            title: const Text("Delete?", style: TextStyle(color: Colors.white)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteDocument(doc['id']);
                                }, 
                                child: const Text("Yes", style: TextStyle(color: Colors.red))
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (_isSelectionMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? AppTheme.primaryColor : Colors.white54,
                    ),
                  ),
              ],
            ),
          ),
        ),
              ),
            ),
          );
        },
      ),
    );
  }
}
